import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/user.dart';

/// Thrown with a server-provided (or fallback) message when an API call fails.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.details});
  final String message;
  final int? statusCode;
  final String? code;

  /// Raw error payload from the server (e.g. the Zod `details` array of a 422).
  final Object? details;

  @override
  String toString() => message;
}

/// Thin HTTP client for the MyGate backend:
/// - prefixes every path with the API base URL,
/// - attaches the Bearer access token,
/// - transparently refreshes the token once on a 401 and retries,
/// - unwraps the `{ success, data }` envelope and surfaces `error.message`.
class ApiClient {
  ApiClient._() : _storage = const FlutterSecureStorage();
  static final ApiClient instance = ApiClient._();

  static const _kAccessToken = 'accessToken';
  static const _kRefreshToken = 'refreshToken';

  final FlutterSecureStorage _storage;
  final http.Client _http = http.Client();

  String? _accessToken;
  String? _refreshToken;

  // Single-flight refresh: parallel 401s trigger only one refresh call.
  Future<bool>? _refreshing;

  String? get accessToken => _accessToken;

  String? get refreshToken => _refreshToken;

  // ---------------------------------------------------------------- tokens

  Future<void> saveTokens(AuthTokens tokens) async {
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    await _storage.write(key: _kAccessToken, value: tokens.accessToken);
    await _storage.write(key: _kRefreshToken, value: tokens.refreshToken);
  }

  /// Restores tokens from secure storage. Returns true if an access token
  /// exists (session may still be valid — verify with `/auth/me`).
  Future<bool> restoreTokens() async {
    if (_accessToken != null) return true;
    _accessToken = await _storage.read(key: _kAccessToken);
    _refreshToken = await _storage.read(key: _kRefreshToken);
    return _accessToken != null;
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }

  // ----------------------------------------------------------------- core

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) async {
    final uri = Uri.parse(
      '$kApiBaseUrl$path',
    ).replace(queryParameters: (query == null || query.isEmpty) ? null : query);
    return _send('GET', uri, auth: auth);
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    return _send(
      'POST',
      Uri.parse('$kApiBaseUrl$path'),
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> patch(String path, {Object? body, bool auth = true}) async {
    return _send(
      'PATCH',
      Uri.parse('$kApiBaseUrl$path'),
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> put(String path, {Object? body, bool auth = true}) async {
    return _send('PUT', Uri.parse('$kApiBaseUrl$path'), body: body, auth: auth);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    return _send('DELETE', Uri.parse('$kApiBaseUrl$path'), auth: auth);
  }

  /// Generic verb, for the handful of routes that use something other than the
  /// four above.
  Future<dynamic> request(
    String method,
    String path, {
    Object? body,
    bool auth = true,
  }) async {
    return _send(
      method,
      Uri.parse('$kApiBaseUrl$path'),
      body: body,
      auth: auth,
    );
  }

  /// Uploads a file as multipart form data.
  ///
  /// `bytes` is the file content (the caller has already read it), `fieldName`
  /// is what the backend expects (usually `file`), and `extra` carries any other
  /// form fields the route needs.
  Future<dynamic> upload(
    String path, {
    required List<int> bytes,
    required String fileName,
    String fieldName = 'file',
    String mimeType = 'application/octet-stream',
    Map<String, String> extra = const {},
    bool auth = true,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    if (auth && _accessToken != null) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }
    request.headers['Accept'] = 'application/json';
    request.headers['X-File-Type'] = mimeType;
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
    );
    request.fields.addAll(extra);

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (!refreshed) return _handle(response, uri);
      final retry = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_accessToken'
        ..headers['Accept'] = 'application/json';
      retry.headers['X-File-Type'] = mimeType;
      retry.files.add(
        http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
      );
      retry.fields.addAll(extra);
      final retried = await retry.send();
      return _handle(await http.Response.fromStream(retried), uri);
    }
    return _handle(response, uri);
  }

  /// The `meta` block of the most recent paginated response.
  ///
  /// Paginated endpoints return `{ success, data: [...], meta: {...} }`; the
  /// envelope unwrap keeps only `data`, so the meta is stashed here for the
  /// caller to read immediately after the call.
  Map<String, dynamic>? get lastMeta => _lastMeta;
  Map<String, dynamic>? _lastMeta;

  /// Fetches a binary resource (an image or file) with the bearer token
  /// attached, for rendering protected files.
  Future<List<int>> fetchBytes(String path, {bool auth = true}) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final response = await _request('GET', uri, null, auth);
    if (response.statusCode == 401 && auth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retried = await _request('GET', uri, null, auth);
        if (retried.statusCode >= 200 && retried.statusCode < 300) {
          return retried.bodyBytes;
        }
        throw _apiException(retried, _decode(retried), uri);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw _apiException(response, _decode(response), uri);
  }

  Future<dynamic> _send(
    String method,
    Uri uri, {
    Object? body,
    required bool auth,
  }) async {
    final response = await _request(method, uri, body, auth);
    if (response.statusCode == 401 && auth) {
      // Try one refresh + retry before giving up.
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final retried = await _request(method, uri, body, auth);
        return _handle(retried, uri);
      }
    }
    return _handle(response, uri);
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Object? body,
    bool auth,
  ) {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    return _http
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 15));
  }

  dynamic _handle(http.Response response, Uri uri) {
    final decoded = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) {
        final meta = decoded['meta'];
        if (meta is Map) {
          _lastMeta = meta.map((k, v) => MapEntry(k.toString(), v));
        }
        if (decoded.containsKey('data')) return decoded['data'];
      }
      return decoded;
    }
    throw _apiException(response, decoded, uri);
  }

  ApiException _apiException(http.Response response, dynamic decoded, Uri uri) {
    String message;
    String? code;
    Object? details;
    if (decoded is Map<String, dynamic>) {
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        message = error['message'] as String? ?? 'Request failed.';
        code = error['code'] as String?;
        details = error['details'];
      } else {
        message = decoded['message'] as String? ?? 'Request failed.';
      }
    } else {
      message = 'Request failed (HTTP ${response.statusCode}).';
    }
    // A 422 from the backend carries per-field messages in `details` (e.g.
    // "Must contain an uppercase letter"). The generic top-level message is
    // just "Request validation failed", which tells the user nothing — surface
    // the field messages instead.
    final detailMessage = _validationMessage(details);
    if (detailMessage != null) message = detailMessage;
    if (response.statusCode == 0 || response.statusCode >= 500) {
      debugPrint('API error ${response.statusCode} $uri: $message');
    }
    return ApiException(
      message,
      statusCode: response.statusCode,
      code: code,
      details: details,
    );
  }

  /// Flattens a Zod `details` array into a single readable string, prefixed with
  /// the field path when present (e.g. `password: Must contain a digit`).
  String? _validationMessage(Object? details) {
    if (details is! List || details.isEmpty) return null;
    final parts = <String>[];
    for (final d in details) {
      if (d is Map) {
        final path = d['path']?.toString().trim();
        final msg = d['message']?.toString().trim();
        if (msg == null || msg.isEmpty) continue;
        parts.add(path == null || path.isEmpty ? msg : '$path: $msg');
      }
    }
    return parts.isEmpty ? null : parts.join('; ');
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------------- refresh

  /// Returns true if the token pair was rotated successfully.
  Future<bool> _tryRefresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return false;
    try {
      final response = await post(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
        auth: false,
      );
      if (response is Map<String, dynamic> &&
          response['accessToken'] is String) {
        await saveTokens(AuthTokens.fromJson(response));
        return true;
      }
      return false;
    } on ApiException catch (e) {
      // Refresh token reuse/expiry → force a clean logout.
      if (e.statusCode == 401) await clearTokens();
      return false;
    }
  }
}
