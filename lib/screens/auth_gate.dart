import 'package:flutter/material.dart';

import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/auth_service.dart';
import 'auth/login_screen.dart';
import 'root_shell.dart';
import 'splash_screen.dart';

/// Chooses what to show based on session state.
///
/// Three states: unknown (still restoring, show a splash), unauthenticated
/// (login), authenticated (the role shell). The AnimatedSwitcher gives a short
/// crossfade so a slow session restore does not flash the login screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthStatus>(
      valueListenable: AppServices.instance.auth.status,
      builder: (context, status, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          child: switch (status) {
            AuthStatus.unknown => const SplashScreen(key: ValueKey('splash')),
            AuthStatus.unauthenticated => const LoginScreen(
              key: ValueKey('login'),
            ),
            AuthStatus.authenticated => const RootShell(key: ValueKey('shell')),
          },
        );
      },
    );
  }
}
