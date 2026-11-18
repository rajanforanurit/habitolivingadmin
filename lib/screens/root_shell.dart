import 'package:flutter/material.dart';

import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/models/user.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'auth/login_screen.dart';
import 'admin/admin_shell.dart';
import 'super_admin/super_admin_shell.dart';
import 'change_password_screen.dart';

/// Picks the shell for the signed-in role.
///
/// This app hosts two portals: the **Super Admin** portal (platform team) and
/// the **society admin** portal. Residents and guards have their own APKs
/// (habitoliving, habitoliving_guard), so any other account gets a "wrong app"
/// screen instead of an empty dashboard.
class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppServices.instance.session,
      builder: (context, _) {
        final session = AppServices.instance.session;
        final identity = session.identity;
        if (identity == null) {
          // The session vanished mid-flight (token revoked, password changed
          // elsewhere): fall back to sign-in rather than a blank screen.
          return const LoginScreen();
        }
        // An admin with a temporary or reset password must replace it before
        // anything else (the backend refuses other calls until they do).
        if (identity.user.mustChangePassword && session.role.isAdmin) {
          return const ChangePasswordScreen(forced: true);
        }
        // Two portals in one app: the platform team and a society's admins.
        // The role comes from the verified session, never from the UI.
        return switch (session.role) {
          UserRole.superAdmin => const SuperAdminShell(),
          UserRole.societyAdmin => const AdminShell(),
          _ => const _WrongAppScreen(),
        };
      },
    );
  }
}

/// Shown when a resident / guard / super admin signs into the admin app.
class _WrongAppScreen extends StatelessWidget {
  const _WrongAppScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons2.roles, size: 48, color: Tokens.accent),
              const SizedBox(height: Tokens.space4),
              Text(
                'Wrong app for this account',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXl,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              const SizedBox(height: Tokens.space2),
              Text(
                'This is the admin app. Residents and guards have '
                'their own apps — ask your administrator for the right one.',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeMd,
                  height: 1.5,
                  color: Tokens.inkMuted,
                ),
              ),
              const SizedBox(height: Tokens.space6),
              FilledButton(
                onPressed: () => confirmAndLogout(context),
                style: FilledButton.styleFrom(
                  backgroundColor: Tokens.accent,
                  foregroundColor: Tokens.accentOn,
                ),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Log out from anywhere: clears the socket, drops the push token, returns to
/// sign-in.
Future<void> confirmAndLogout(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'Sign out?',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Text(
        'You will need your mobile number and password to sign back in.',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeSm,
          height: 1.5,
          color: Tokens.inkMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            'Stay',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              color: Tokens.inkMuted,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Tokens.danger),
          child: const Text(
            'Sign out',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeSm,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await AppServices.instance.auth.logout();
}