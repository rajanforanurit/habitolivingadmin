import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_services.dart';
import 'auth_service.dart';

/// What to do when a notification is tapped.
///
/// The push payload carries a `route` (set by the backend) and/or an `id` plus a
/// `kind`. The app resolves that to a screen after the user is signed in.
typedef PushRouter = void Function(Map<String, dynamic> data);

/// Top-level handler for messages that arrive while the app is terminated or in
/// the background.
///
/// It must be a top-level (or static) function: the FCM plugin isolates it.
/// It does minimal work, because it runs in a background isolate where the app's
/// services do not exist.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Nothing to do here: the OS shows the notification from the `notification`
  // block. This handler exists so data-only messages in the background are not
  // dropped, and so the app can be woken to sync the inbox.
  debugPrint('Push received in background: ${message.messageId}');
}

/// Push notification client.
///
/// Covers the full lifecycle the app needs:
/// - ask for permission with context-appropriate copy,
/// - fetch the FCM token and hand it to the backend,
/// - keep the backend copy in sync when the token rotates,
/// - show a local notification for foreground messages (FCM does not do this
///   on Android when the app is open),
/// - route a tap to the right screen.
///
/// The Firebase config is a placeholder in this repo. Drop the real
/// `google-services.json` into `android/app/` (see docs/PUSH_NOTIFICATIONS.md)
/// and push starts working; without it the app still runs, with push disabled.
class PushService extends ChangeNotifier {
  PushService._();
  static final PushService instance = PushService._();

  bool _available = false;
  bool _initialised = false;
  String? _token;
  PushRouter? _router;

  /// True when the Firebase plugin is initialised and a token is available.
  bool get isAvailable => _available;

  /// The current device token, or null when push is unavailable.
  String? get token => _token;

  /// Android notification channels.
  ///
  /// Android 8+ requires a channel per kind of alert, and the channel controls
  /// sound and importance. Emergencies get their own high-importance channel so
  /// they can break through.
  static const AndroidNotificationChannel _generalChannel =
      AndroidNotificationChannel(
        'habito_general',
        'General alerts',
        description: 'Visitors, deliveries, approvals and society notices.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _emergencyChannel =
      AndroidNotificationChannel(
        'habito_emergency',
        'Emergency alerts',
        description:
            'Panic alerts and security incidents. These bypass quiet hours.',
        importance: Importance.max,
      );

  static const AndroidNotificationChannel _paymentChannel =
      AndroidNotificationChannel(
        'habito_payments',
        'Payments and billing',
        description: 'Invoice reminders, receipts and payment status.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _chatChannel =
      AndroidNotificationChannel(
        'habito_chat',
        'Messages',
        description: 'Chat messages from staff and admins.',
        importance: Importance.high,
      );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Initialises Firebase and the local notification plugin.
  ///
  /// Safe to call when the config is absent: it logs and leaves push disabled,
  /// so a checkout without credentials still builds and runs.
  Future<void> init({PushRouter? onMessage}) async {
    if (_initialised) return;
    _initialised = true;
    _router = onMessage;

    try {
      await Firebase.initializeApp();
      _available = true;
    } catch (e) {
      debugPrint('Firebase init failed (push disabled): $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    // Foreground presentation: iOS needs permission to show heads-up banners.
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _initLocalNotifications();
    await _registerListeners(messaging);
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        _handleTap(_decode(payload));
      },
    );

    final android = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(_generalChannel);
    await android?.createNotificationChannel(_emergencyChannel);
    await android?.createNotificationChannel(_paymentChannel);
    await android?.createNotificationChannel(_chatChannel);
  }

  Future<void> _registerListeners(FirebaseMessaging messaging) async {
    // A message arrived while the app is open: show it ourselves.
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // The user tapped a background/terminated notification.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message.data);
    });

    // The app was launched from a terminated state by a tap.
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      // Wait a frame so the navigator is ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleTap(initial.data);
      });
    }

    // Token rotation: push the new token to the backend.
    messaging.onTokenRefresh.listen((token) {
      _token = token;
      unawaited(_syncToken(token));
    });
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final title =
        message.notification?.title ??
        (data['title'] as String?) ??
        'Habito Living';
    final body = message.notification?.body ?? (data['body'] as String?) ?? '';
    await _showLocal(
      title: title,
      body: body,
      data: data,
      channel: _channelFor(data['kind'] as String?),
    );
  }

  /// Requests permission and returns the token.
  ///
  /// Call this after sign-in, when the user has a reason to want alerts. On iOS
  /// the system prompt is only shown once, so the caller should gate this behind
  /// an explanation screen on first launch.
  Future<String?> enable({bool requestPermission = true}) async {
    if (!_available) return null;
    final messaging = FirebaseMessaging.instance;

    if (requestPermission) {
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return null;
    }

    // iOS shows a provisional prompt first; this asks for the real one.
    if (Platform.isIOS) {
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    final token = await messaging.getToken();
    _token = token;
    if (token != null) await _syncToken(token);
    notifyListeners();
    return token;
  }

  /// Registers the current token with the backend, if Firebase is available.
  Future<void> registerCurrentToken() async {
    if (!_available) return;
    final messaging = FirebaseMessaging.instance;
    final token = _token ?? await messaging.getToken();
    if (token == null) return;
    _token = token;
    await _syncToken(token);
  }

  Future<void> _syncToken(String token) async {
    if (AppServices.instance.auth.status.value != AuthStatus.authenticated) {
      return;
    }
    try {
      await AppServices.instance.pushTokens.register(
        token: token,
        platform: Platform.isIOS ? 'IOS' : 'ANDROID',
        deviceName: Platform.localHostname,
      );
      debugPrint('Push token registered');
    } catch (e) {
      debugPrint('Push token registration failed: $e');
    }
  }

  /// Removes the token on logout so the device stops receiving alerts.
  Future<void> disable() async {
    notifyListeners();
    if (!_available || _token == null) return;
    try {
      await AppServices.instance.pushTokens.remove(_token!);
    } catch (e) {
      debugPrint('Push token removal failed: $e');
    }
    _token = null;
  }

  Future<void> _showLocal({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    AndroidNotificationChannel? channel,
  }) async {
    final selected = channel ?? _channelFor(data['kind'] as String?);
    final androidDetails = AndroidNotificationDetails(
      selected.id,
      selected.name,
      channelDescription: selected.description,
      importance: _importance(selected.importance),
      priority: _priority(selected.importance),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _local.show(
      data.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: darwinDetails),
      payload: _encode(data),
    );
  }

  static Importance _importance(Importance importance) => importance;

  static Priority _priority(Importance importance) => switch (importance) {
    Importance.max => Priority.max,
    Importance.high => Priority.high,
    _ => Priority.defaultPriority,
  };

  static AndroidNotificationChannel _channelFor(String? kind) {
    return switch ((kind ?? '').toUpperCase()) {
      'EMERGENCY' || 'PANIC' => _emergencyChannel,
      'PAYMENT' => _paymentChannel,
      'CHAT' => _chatChannel,
      _ => _generalChannel,
    };
  }

  void _handleTap(Map<String, dynamic> data) {
    final router = _router;
    if (router == null) return;
    router(data);
  }

  static String _encode(Map<String, dynamic> data) {
    // Payload is a plain string for the tap handler; JSON keeps it structured.
    return data.entries.map((e) => '${e.key}=${e.value}').join('&');
  }

  static Map<String, dynamic> _decode(String payload) {
    final out = <String, dynamic>{};
    for (final part in payload.split('&')) {
      final idx = part.indexOf('=');
      if (idx <= 0) continue;
      out[part.substring(0, idx)] = part.substring(idx + 1);
    }
    return out;
  }
}
