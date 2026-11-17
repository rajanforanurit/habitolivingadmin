import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'api/admin_api.dart';
import 'api/files_api.dart';
import 'media_service.dart';
import 'api/guard_api.dart';
import 'api/resident_api.dart';
import 'api/super_admin_api.dart';
import 'auth_service.dart';
import 'session.dart';
import 'socket_service.dart';

/// Application-wide services.
///
/// One instance per app run, created in `main()` before the widget tree. Screens
/// read from here instead of constructing their own clients, so there is exactly
/// one socket, one session and one set of API clients.
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final ApiClient api = ApiClient.instance;
  final AuthService auth = AuthService.instance;
  final Session session = Session();
  final SocketService socket = SocketService.instance;

  late final ResidentApi resident = ResidentApi(api);
  late final GuardApi guard = GuardApi(api);
  late final AdminApi admin = AdminApi(api);
  late final SuperAdminApi superAdmin = SuperAdminApi(api);
  late final FilesApi files = FilesApi(api);
  late final MediaService media = MediaService(files);
  late final NotificationsApi notifications = NotificationsApi(api);
  late final PushTokenApi pushTokens = PushTokenApi(api);

  /// Initialises the services that need to run before the first frame.
  ///
  /// Kept separate from the constructor so `AppServices.instance` is safe to
  /// reference from a `late final` field initialiser.
  Future<void> init() async {
    await auth.restoreSession();
    if (auth.status.value == AuthStatus.authenticated) {
      attachSession();
    }
  }

  /// Wires the session to the socket after a sign-in or society switch.
  ///
  /// The socket must re-handshake whenever the access token changes, because
  /// the backend authenticates at handshake only. A stale socket looks like
  /// "notifications stopped arriving", which is hard to diagnose later.
  void attachSession() {
    session.update(auth.identity);
    socket.connect(api.accessToken);
  }

  /// Drops the session and closes the socket. Used on logout.
  void detachSession() {
    session.clear();
    socket.disconnect();
  }

  /// The current identity, or null when signed out.
  AuthIdentity? get identity => auth.identity;

  /// Runs [body] and reports failures without throwing, for background work
  /// where a failure should not surface as an unhandled async error.
  Future<void> guard_(Future<void> Function() body, String label) async {
    try {
      await body();
    } catch (e) {
      debugPrint('$label failed: $e');
    }
  }
}
