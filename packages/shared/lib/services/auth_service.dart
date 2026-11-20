import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/json.dart';
import '../models/user.dart';
import 'api_client.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// Backend-backed auth service.
///
/// Covers the whole Authentication section of the API (13 routes):
/// password login, OTP login, registration, forgot/reset/change password,
/// `/auth/me`, society switching, society search and society registration.
///
/// The session is a single object: [identity] is the source of truth for the
/// current user, their memberships and the active society. Everything else
/// (session cache, membership switching, flat pickers) reads from here.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final ApiClient _api = ApiClient.instance;

  final ValueNotifier<AuthStatus> status = ValueNotifier<AuthStatus>(
    AuthStatus.unknown,
  );

  AuthIdentity? _identity;
  AuthIdentity? get identity => _identity;

  /// Set when [restoreSession] found stored tokens but could not validate
  /// them because the backend was unreachable (network error). The app still
  /// falls back to the login screen (never a black screen), and the stored
  /// tokens are kept so a later launch can retry the validation.
  String? startupConnectivityError;

  // ------------------------------------------------------------- lifecycle

  /// Called once at app start: restore stored tokens and validate the
  /// session against `/auth/me`.
  Future<void> restoreSession() async {
    final hasTokens = await _api.restoreTokens();
    if (!hasTokens) {
      status.value = AuthStatus.unauthenticated;
      return;
    }
    try {
      _identity = await me();
      // If the resident has been approved to a society AFTER they last logged
      // in, their token was issued without a society context (sid). The
      // backend's requireSociety middleware then rejects every society-scoped
      // route with "No active society context". Fix: switch to the first
      // ACTIVE society so a new token with sid is issued.
      await _ensureSocietyContext();
      status.value = AuthStatus.authenticated;
    } on ApiException {
      // Server responded: the session is invalid (expired/revoked).
      await _api.clearTokens();
      _identity = null;
      startupConnectivityError = null;
      status.value = AuthStatus.unauthenticated;
    } catch (e) {
      // SocketException/ClientException/timeout: the server is unreachable.
      // Never crash the app at startup (that produced the black screen).
      debugPrint('Session restore failed (network): $e');
      final base = Uri.parse(kApiBaseUrl);
      startupConnectivityError =
          'Cannot reach the server at ${base.host}:${base.port}.'
          '\nIs the backend running? Then run: adb reverse tcp:4000 tcp:4000';
      _identity = null;
      status.value = AuthStatus.unauthenticated;
    }
  }

  /// Re-fetch the identity without changing the session (pull to refresh).
  Future<AuthIdentity> refreshIdentity() async {
    final identity = await me();
    _identity = identity;
    await _ensureSocietyContext();
    return identity;
  }

  /// If the current token has no society context but the resident has an
  /// ACTIVE society, call switch-society to get a token with the society
  /// context (sid). This runs after restoreSession and refreshIdentity so
  /// residents approved after login can access society-scoped routes.
  Future<void> _ensureSocietyContext() async {
    final identity = _identity;
    if (identity == null) return;
    if (identity.activeSocietyId != null) {
      debugPrint('Auto-switch: already has society ${identity.activeSocietyId}');
      return;
    }
    final active = identity.societies
        .where((s) => s.status == 'ACTIVE')
        .toList();
    if (active.isEmpty) {
      debugPrint('Auto-switch: no ACTIVE society for resident');
      return;
    }
    debugPrint('Auto-switch: switching to ${active.first.societyId} (${active.first.societyName})');
    try {
      await switchSociety(active.first.societyId);
      debugPrint('Auto-switch: success, new token has society context');
    } catch (e) {
      debugPrint('Auto-switch failed: $e');
    }
  }

  // ------------------------------------------------------------------ login

  /// Login with mobile/email + password.
  /// `societyId` is only needed when the account belongs to multiple societies.
  Future<void> loginWithPassword(
    String identifier,
    String password, {
    String? societyId,
  }) async {
    final data = await _api.post(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
        if (societyId != null && societyId.isNotEmpty) 'societyId': societyId,
      },
      auth: false,
    );
    await _applyLoginResponse(data);
  }

  /// Step 1 of OTP login. The backend echoes `devOtp` outside production.
  Future<OtpRequestResult> requestOtp(
    String mobile, {
    OtpPurpose purpose = OtpPurpose.login,
  }) async {
    final data = await _api.post(
      '/auth/otp/request',
      body: {'mobile': mobile, 'purpose': purpose.wire},
      auth: false,
    );
    final map = asMap(data);
    return OtpRequestResult(
      message: asString(map['message'], fallback: 'OTP sent.'),
      expiresInSeconds: asInt(map['expiresInSeconds']),
      devOtp: asStringOrNull(map['devOtp']),
    );
  }

  /// Step 2 of OTP login.
  Future<void> loginWithOtp(
    String mobile,
    String otp, {
    String? societyId,
  }) async {
    final data = await _api.post(
      '/auth/login/otp',
      body: {
        'mobile': mobile,
        'otp': otp,
        if (societyId != null && societyId.isNotEmpty) 'societyId': societyId,
      },
      auth: false,
    );
    await _applyLoginResponse(data);
  }

  /// Register a new user account with an OTP that was requested for REGISTER.
  Future<void> register({
    required String name,
    required String mobile,
    required String password,
    required String otp,
    String? email,
  }) async {
    final data = await _api.post(
      '/auth/register',
      body: {
        'name': name,
        'mobile': mobile,
        'password': password,
        'otp': otp,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      auth: false,
    );
    await _applyLoginResponse(data);
  }

  // -------------------------------------------------------------- passwords

  /// Request a password-reset OTP for a mobile number.
  Future<OtpRequestResult> requestPasswordReset(String mobile) =>
      requestOtp(mobile, purpose: OtpPurpose.resetPassword);

  /// Complete a password reset with the OTP and a new password.
  Future<void> resetPassword({
    required String mobile,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/password/reset',
      body: {'mobile': mobile, 'otp': otp, 'newPassword': newPassword},
      auth: false,
    );
  }

  /// Change the password for the signed-in account.
  ///
  /// The backend revokes every session when the password changes, so the caller
  /// must re-login afterwards.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/password/change',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  // ------------------------------------------------------------------ me

  /// Fetch the current identity (user + society memberships + permissions).
  Future<AuthIdentity> me() async {
    final data = await _api.get('/auth/me');
    return AuthIdentity.fromJson(reqMap(data, field: 'data'));
  }

  /// Switch the active society; the backend issues fresh tokens scoped to it.
  Future<void> switchSociety(String societyId) async {
    final data = await _api.post(
      '/auth/switch-society',
      body: {'societyId': societyId},
    );
    await _applyLoginResponse(data);
  }

  /// Logout the current session (best-effort) and clear local state.
  Future<void> logout() async {
    try {
      await _api.post(
        '/auth/logout',
        body: {'refreshToken': _api.refreshToken},
      );
    } on ApiException catch (e) {
      debugPrint('Logout call failed (continuing): $e');
    }
    await _api.clearTokens();
    _identity = null;
    status.value = AuthStatus.unauthenticated;
  }

  // ------------------------------------------------------------- societies

  /// Search active societies by name or code, for the join flow.
  ///
  /// The backend expects the query parameter `q` (schema `societySearchQuery`),
  /// not `search` — sending the wrong key returned a 422 that the UI showed as
  /// "Request validation failed".
  Future<List<SocietySearchResult>> searchSocieties(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final data = await _api.get(
      '/auth/societies/search',
      query: {'q': trimmed},
    );
    return asMapList(
      data,
    ).map(SocietySearchResult.fromJson).toList(growable: false);
  }

  // -------------------------------------------------------------- private

  Future<void> _applyLoginResponse(dynamic data) async {
    final map = reqMap(data, field: 'data');
    final tokens = AuthTokens.fromJson(map);
    await _api.saveTokens(tokens);
    // Prefer /auth/me for a canonical identity (includes activeSocietyId).
    try {
      _identity = await me();
    } on ApiException {
      _identity = AuthIdentity.fromJson(map);
    }
    startupConnectivityError = null;
    status.value = AuthStatus.authenticated;
  }
}

/// The purpose of an OTP request, matching the backend `OtpPurpose` enum.
enum OtpPurpose {
  register,
  login,
  resetPassword;

  String get wire => switch (this) {
    OtpPurpose.register => 'REGISTER',
    OtpPurpose.login => 'LOGIN',
    OtpPurpose.resetPassword => 'RESET_PASSWORD',
  };
}

/// The result of requesting an OTP.
class OtpRequestResult {
  const OtpRequestResult({
    required this.message,
    required this.expiresInSeconds,
    this.devOtp,
  });

  final String message;
  final int expiresInSeconds;

  /// Only present outside production (EXPOSE_DEV_OTP). Use to pre-fill the
  /// OTP field during development.
  final String? devOtp;

  bool get hasDevOtp => devOtp != null && devOtp!.isNotEmpty;
}

/// A society returned by the public search or registration endpoint.
class SocietySearchResult {
  const SocietySearchResult({
    required this.id,
    required this.name,
    this.code,
    this.city,
    this.state,
    this.type,
    this.status,
  });

  factory SocietySearchResult.fromJson(Map<String, dynamic> json) {
    final address = asMapOrNull(json['address']);
    return SocietySearchResult(
      id: asString(json['id']),
      name: asString(json['name'], fallback: 'Society'),
      code: asStringOrNull(json['code']),
      city: asStringOrNull(at(address, 'city') ?? json['city']),
      state: asStringOrNull(at(address, 'state') ?? json['state']),
      type: asStringOrNull(json['type']) == null
          ? null
          : humanize(asString(json['type'])),
      status: asStringOrNull(json['status']) == null
          ? null
          : humanize(asString(json['status'])),
    );
  }

  final String id;
  final String name;
  final String? code;
  final String? city;
  final String? state;
  final String? type;
  final String? status;

  /// "Patna, Bihar" when the city is known.
  String? get location {
    final parts = [
      city,
      state,
    ].whereType<String>().where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(', ');
  }
}
