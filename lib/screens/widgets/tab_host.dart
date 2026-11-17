import 'package:flutter/material.dart';

import '../../services/notification_router.dart';

/// Lets a role shell answer [NotificationRouter.requestTab].
///
/// A notification tap has two possible shapes: push a screen, or bring the
/// already-open shell to the tab that owns the thing. Mixing both in the router
/// would make the router know about every shell's tab order, so the shell
/// subscribes here instead and the router only records the intent.
///
/// The shell supplies [onTabRequest]; the mixin clears the request after
/// dispatch so a rebuild does not replay the jump.
mixin TabHost<T extends StatefulWidget> on State<T> {
  /// Called when a notification asks for a tab. Must call setState.
  void onTabRequest(int index);

  /// Optional: how many tabs this shell has. Bounds checking only.
  int get tabCount => 5;

  void _onTabValue() {
    final requested = NotificationRouter.tabRequest.value;
    if (requested < 0 || requested >= tabCount) return;
    NotificationRouter.clearTabRequest();
    if (!mounted) return;
    onTabRequest(requested);
  }

  /// Call from the state's `initState`.
  void listenForTabRequests() {
    NotificationRouter.tabRequest.addListener(_onTabValue);
  }

  @override
  void dispose() {
    NotificationRouter.tabRequest.removeListener(_onTabValue);
    super.dispose();
  }
}
