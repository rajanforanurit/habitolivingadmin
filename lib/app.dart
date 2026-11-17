import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:habitoliving_shared/models/user.dart';
import 'package:habitoliving_shared/services/api_client.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/auth_service.dart';
import 'package:habitoliving_shared/services/preferences.dart';
import 'services/notification_router.dart';
import 'package:habitoliving_shared/services/push_service.dart';
import 'package:habitoliving_shared/services/session.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/typography.dart';
import 'screens/auth_gate.dart';
// In-app updater: disabled for now. Re-enable by uncommenting the import and
// the UpdateBanner mount below (search for "updater").
// import 'updates/update_banner.dart';
// import 'updates/update_service.dart';

/// App entry widget.
///
/// Responsibilities:
/// - restore the session before showing any UI,
/// - provide the theme (light/dark/system) from settings,
/// - mount the text styles so `context.st` works,
/// - initialise push and route a notification tap to the right screen.
class HabitoApp extends StatefulWidget {
  const HabitoApp({super.key});

  @override
  State<HabitoApp> createState() => _HabitoAppState();
}

class _HabitoAppState extends State<HabitoApp> {
  GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// The brightness the current navigator was built for. A flip rebuilds the
  /// navigator key, and with it every pushed route.
  bool? _navDark;

  @override
  void initState() {
    super.initState();
    _registerPushRouting();
    _bootstrap();
  }

  void _registerPushRouting() {
    NavigationBus.instance.register((data) {
      final context = _navigatorKey.currentContext;
      if (context == null) return;
      NotificationRouter.open(context, data);
    });
  }

  Future<void> _bootstrap() async {
    // Preferences first: the theme must be right on the first frame.
    await Preferences.instance.load();
    if (mounted) setState(() {});

    // Restore the session next: the auth gate shows a splash until it resolves.
    await AppServices.instance.auth.restoreSession();

    if (!mounted) return;

    // Push: safe when the Firebase config is absent, in which case it logs and
    // stays disabled.
    await PushService.instance.init(onMessage: _onPushTap);
    if (Preferences.instance.pushEnabled) {
      await PushService.instance.registerCurrentToken();
    }

    if (AppServices.instance.auth.status.value == AuthStatus.authenticated) {
      AppServices.instance.attachSession();
    }
    // In-app updater: disabled for now. To re-enable, uncomment this block and
    // the UpdateBanner import/mount in this file (search for "updater").
    // unawaited(UpdateService.instance.init().then((_) => UpdateService.instance.check()));
    if (mounted) setState(() {});
  }

  /// A notification was tapped. Wait for the session, then let the router open
  /// the right screen.
  void _onPushTap(Map<String, dynamic> data) {
    if (AppServices.instance.auth.status.value != AuthStatus.authenticated) {
      return;
    }
    NavigationBus.instance.open(data);
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on preference changes: the settings screen flips the theme and
    // the whole app must repaint.
    return AnimatedBuilder(
      animation: Preferences.instance,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final mode = Preferences.instance.themeMode;
    final isDark =
        mode == ThemeMode.dark ||
        (mode == ThemeMode.system && brightness == Brightness.dark);

    // Resolve the colour palette before anything below reads a colour token.
    //
    // A theme flip has to rebuild the routes as well as the shell. Reparenting
    // MaterialApp through its ValueKey rebuilds the shell, but the Navigator is
    // held by a GlobalKey: it keeps its route entries and the widgets that were
    // pushed onto it, so a screen opened before the switch kept painting with
    // the old palette (a dark app with a light panel in the middle of it).
    // Re-keying the navigator forces every route to be rebuilt too.
    if (_navDark != isDark) {
      _navDark = isDark;
      _navigatorKey = GlobalKey<NavigatorState>();
      Tokens.apply(isDark ? Palette.dark : Palette.light);
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Tokens.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: MaterialApp(
        // Keyed on the brightness: the tree is rebuilt from scratch when the
        // theme flips, which is what makes token-driven colours update.
        key: ValueKey(isDark),
        navigatorKey: _navigatorKey,
        title: 'Habito Living',
        debugShowCheckedModeBanner: false,
        theme: _materialTheme(isDark),
        home: AppTextStylesScope(
          styles: isDark ? AppTextStyles.dark() : AppTextStyles.light(),
          child: const AuthGate(),
        ),
        builder: (context, child) {
          // Scale-independent UI: the design is tuned for 1.0, and a system
          // text scale above 1.3 would break row heights. Clamp instead of
          // ignoring the setting.
          final media = MediaQuery.of(context);
          final clamped = media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.3,
            ),
          );
          return MediaQuery(
            data: clamped,
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  ThemeData _materialTheme(bool isDark) {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: isDark
          ? Tokens.backgroundDark
          : Tokens.background,
      colorScheme: base.colorScheme.copyWith(
        primary: isDark ? Tokens.accentDark : Tokens.accent,
        surface: isDark ? Tokens.surfaceDark : Tokens.surface,
      ),
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Opens a route from anywhere in the app (push taps, notification taps).
class NavigationBus {
  NavigationBus._();
  static final NavigationBus instance = NavigationBus._();

  void Function(Map<String, dynamic> data)? _handler;

  void register(void Function(Map<String, dynamic> data) handler) =>
      _handler = handler;

  void open(Map<String, dynamic> data) => _handler?.call(data);
}

/// Small helper so screens can show a one-off message without a Scaffold.
void showMessage(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: 14,
          color: Tokens.ink,
        ),
      ),
      backgroundColor: error ? Tokens.dangerTint : Tokens.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        side: BorderSide(color: Tokens.line),
      ),
      margin: const EdgeInsets.all(Tokens.space4),
    ),
  );
}

/// Asks for confirmation before a destructive action.
///
/// Returns true when the user confirmed. Used everywhere a delete, cancel or
/// logout happens, so the wording is consistent.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        title,
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Text(
        message,
        style: TextStyle(
          fontFamily: 'InstrumentSans',
          fontSize: Tokens.typeSm,
          height: 1.45,
          color: Tokens.inkMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: destructive ? Tokens.danger : Tokens.accent,
            foregroundColor: Tokens.ink,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Reads the current identity for a screen that needs it.
AuthIdentity? currentIdentity() => AppServices.instance.identity;

/// The signed-in session.
Session get session => AppServices.instance.session;

/// The API client.
ApiClient get api => AppServices.instance.api;
