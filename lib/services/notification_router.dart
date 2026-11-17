import 'package:flutter/material.dart';

import '../screens/emergency_screen.dart';
import '../screens/notifications_inbox_screen.dart';
import '../screens/settings_screen.dart';

/// A handler turns a notification payload into a screen to push.
typedef RouteHandler = Widget Function(Map<String, dynamic> data);

/// Turns a notification payload into a screen.
///
/// Why a registry rather than a giant switch: each role owns its screens, and
/// only the role's shell knows what exists. A shell registers its routes when it
/// mounts and unregisters when it is disposed, so a notification can never open
/// a screen the signed-in role is not allowed to see.
///
/// The backend is free to attach arbitrary data to a notification; what matters
/// is that a tap always lands somewhere sensible and never crashes. Unknown
/// routes fall through to the inbox, which always exists.
class NotificationRouter {
  NotificationRouter._();

  static final Map<String, RouteHandler> _handlers = {};
  static final List<Registration> _registrations = [];

  static final Map<String, int> _tabSections = {};

  /// Registers routes and returns a handle to unregister them.
  ///
  /// [tabSections] maps a payload section to a shell tab index; a section that
  /// is neither a handler nor a tab request falls through to the shared-screen
  /// resolution and finally the inbox.
  static Registration register(
    Map<String, RouteHandler> routes, {
    Map<String, int> tabSections = const {},
  }) {
    final owned = <String>[];
    routes.forEach((prefix, handler) {
      _handlers[prefix] = handler;
      owned.add(prefix);
    });
    final ownedTabs = <String, int>{};
    tabSections.forEach((section, tab) {
      _tabSections[section] = tab;
      ownedTabs[section] = tab;
    });
    final registration = Registration._(owned, ownedTabs);
    for (final entry in routes.entries) {
      registration._ownedHandlers[entry.key] = entry.value;
    }
    registration._ownedTabs.addAll(tabSections);
    _registrations.add(registration);
    return registration;
  }

  /// Routes a tap. Returns true when a handler was found and the screen opened.
  static Future<bool> open(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final route = asRoute(data);
    if (route == null) return false;

    final section = _sectionOf(route);
    if (section != null) {
      final tab = _tabSections[section];
      if (tab != null) {
        // A tab owns this thing; no screen to push.
        requestTab(tab);
        return true;
      }
      final handler = _handlers[section];
      if (handler != null) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => handler(data)));
        return true;
      }
    }

    // Shared screens exist for every role.
    final shared = _shared(context, section);
    if (shared != null) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => shared));
      return true;
    }

    // Never fail silently: the user tapped something, so show the inbox.
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()));
    return false;
  }

  /// The route string from a payload, or null.
  static String? asRoute(Map<String, dynamic> data) {
    final route = data['route'] ?? data['link'] ?? data['deeplink'];
    if (route is! String) return null;
    final trimmed = route.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String? _sectionOf(String route) {
    var path = route.replaceFirst(RegExp(r'^https?://[^/]+'), '');
    path = path.replaceFirst(RegExp(r'^/'), '');
    path = path.split('?').first;
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    // Strip a role segment so "/user/invoices" and "/invoices" agree.
    const rolePrefixes = {'user', 'guard', 'admin', 'super', 'resident', 'app'};
    if (rolePrefixes.contains(parts.first) && parts.length > 1) {
      parts.removeAt(0);
    }
    return parts.first;
  }

  static Widget? _shared(BuildContext context, String? section) {
    switch (section) {
      case 'notifications':
      case 'inbox':
        return const NotificationsInboxScreen();
      case 'settings':
      case 'preferences':
        return const SettingsScreen();
      case 'emergency':
      case 'panic':
      case 'sos':
        return const EmergencyScreen();
      default:
        return null;
    }
  }

  /// Whether a route is registered, used by tests and by the dev route list.
  static bool handles(String section) => _handlers.containsKey(section);

  // ------------------------------------------------------------- tab jumps

  /// A request for the current shell to select a tab.
  ///
  /// Notification routing has two shapes: "open this screen" (a handler that
  /// returns a widget to push) and "show me the tab that owns this". The second
  /// is how a guard's alert tap lands on the Alerts tab instead of pushing a
  /// second copy of it on top of the shell.
  static final ValueNotifier<int> tabRequest = ValueNotifier<int>(-1);

  /// Asks the active shell to switch to [index].
  static void requestTab(int index) => tabRequest.value = index;

  /// Clears a request once a shell has acted on it, so a rebuild does not
  /// replay the jump.
  static void clearTabRequest() => tabRequest.value = -1;
}

/// Handle returned by [NotificationRouter.register].
class Registration {
  Registration._(this._owned, this._ownedTabs);
  final List<String> _owned;
  final Map<String, int> _ownedTabs;

  /// Drops this role's routes. Safe to call more than once.
  void dispose() {
    if (!NotificationRouter._registrations.remove(this)) return;
    for (final key in _owned) {
      // Only drop a key this registration still owns. Two roles can map the
      // same section (e.g. "invoices"), and the later registration wins; the
      // earlier one must not remove the newer handler.
      if (identical(NotificationRouter._handlers[key], _ownedHandlers[key])) {
        NotificationRouter._handlers.remove(key);
      }
    }
    for (final entry in _ownedTabs.entries) {
      // Only drop a tab mapping this registration still owns.
      if (NotificationRouter._tabSections[entry.key] == entry.value) {
        NotificationRouter._tabSections.remove(entry.key);
      }
    }
    _ownedHandlers.clear();
    _ownedTabs.clear();
  }

  /// The handler each key pointed at when it was registered.
  final Map<String, RouteHandler> _ownedHandlers = {};
}
