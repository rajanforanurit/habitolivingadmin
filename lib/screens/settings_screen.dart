import 'package:flutter/material.dart';

import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/preferences.dart';
import 'package:habitoliving_shared/services/push_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'forgot_password_screen.dart';
import 'change_password_screen.dart';
import 'emergency_screen.dart';
import 'profile_edit_screen.dart';
import 'notification_preferences_screen.dart';
import '../app.dart';

/// Settings: account, appearance, push, and the sign-out.
///
/// Everything the user can change about themselves lives here. There is no
/// separate "profile edit" screen — the profile is the account section, so there
/// is one place to look.
///
/// Sign-out is at the bottom and behind a confirmation: it is destructive but
/// not irreversible, so a single confirm is enough.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppServices.instance.session;
    final prefs = Preferences.instance;

    return AppScaffold(
      title: 'Settings',
      showBack: true,
      body: AnimatedBuilder(
        animation: Listenable.merge([prefs, PushService.instance]),
        builder: (context, _) => SingleChildScrollView(
          // AppScaffold's composed-body path already applies the screen gutter
          // horizontally, so no extra padding here — that double-padded rows
          // to 36px per side and pushed text off the visible area.
          padding: EdgeInsets.only(bottom: Tokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ------------------------------------------------------ account
              SectionLabel('Account'),
              SizedBox(height: Tokens.space2),
              Panel(
                child: Column(
                  children: [
                    ListRow(
                      title: session.displayName,
                      subtitle: 'Edit your profile',
                      leading: InitialsAvatar(name: session.displayName),
                      dense: false,
                      showChevron: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditScreen(),
                        ),
                      ),
                    ),
                    Hairline(),
                    ListRow(
                      title: 'Flat',
                      subtitle: session.membership == null
                          ? 'Not linked to a flat'
                          : _flatLabel(session.membership),
                      icon: Icons2.flat,
                    ),
                    Hairline(),
                    ListRow(
                      title: 'Society',
                      subtitle: session.societyName,
                      icon: Icons2.community,
                      showChevron: session.societies.length > 1,
                      onTap: session.societies.length > 1
                          ? () async {
                              final picked = await showModalBottomSheet<String>(
                                context: context,
                                backgroundColor: Tokens.surface,
                                builder: (ctx) => SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          Tokens.space4,
                                          Tokens.space4,
                                          Tokens.space4,
                                          Tokens.space2,
                                        ),
                                        child: Text(
                                          'Switch society',
                                          style: TextStyle(
                                            fontFamily: Tokens.fontFamily,
                                            fontSize: Tokens.typeSm,
                                            fontWeight: FontWeight.w600,
                                            color: Tokens.ink,
                                          ),
                                        ),
                                      ),
                                      for (final society in session.societies)
                                        ListRow(
                                          title: society.societyName,
                                          subtitle:
                                              society.role == 'SOCIETY_ADMIN'
                                              ? 'Admin'
                                              : society.role == 'GUARD'
                                              ? 'Guard'
                                              : 'Member',
                                          icon: Icons2.community,
                                          onTap: () => Navigator.of(
                                            ctx,
                                          ).pop(society.societyId),
                                        ),
                                      const SizedBox(height: Tokens.space3),
                                    ],
                                  ),
                                ),
                              );
                              if (picked == null || !context.mounted) return;
                              try {
                                await AppServices.instance.auth.switchSociety(
                                  picked,
                                );
                                AppServices.instance.attachSession();
                                if (context.mounted) {
                                  showMessage(context, 'Switched society.');
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  showMessage(context, '$e', error: true);
                                }
                              }
                            }
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Tokens.space5),
              SectionLabel('Appearance'),
              SizedBox(height: Tokens.space2),
              Panel(
                child: Column(
                  children: [
                    ListRow(
                      title: 'Theme',
                      subtitle: prefs.themeMode.label,
                      icon: Icons2.theme,
                      onTap: () => _pickTheme(context, prefs),
                      showChevron: true,
                    ),
                    const Hairline(),
                    ListRow(
                      title: 'Change password',
                      icon: Icons2.password,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
                      showChevron: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Tokens.space5),
              SectionLabel('Notifications'),
              SizedBox(height: Tokens.space2),
              Panel(
                child: Column(
                  children: [
                    ListRow(
                      title: 'Push notifications',
                      subtitle: PushService.instance.isAvailable
                          ? (prefs.pushEnabled
                                ? 'On — this device'
                                : 'Off — you will miss gate alerts')
                          : 'Not available on this device',
                      icon: Icons2.notifications,
                      onTap: () async {
                        if (!PushService.instance.isAvailable) {
                          showMessage(
                            context,
                            'Push is not configured for this build.',
                            error: true,
                          );
                          return;
                        }
                        final next = !prefs.pushEnabled;
                        await prefs.setPushEnabled(next);
                        if (next) {
                          await PushService.instance.enable();
                          await PushService.instance.registerCurrentToken();
                        } else {
                          await PushService.instance.disable();
                        }
                      },
                      trailing: AppSwitch(
                        value:
                            prefs.pushEnabled &&
                            PushService.instance.isAvailable,
                        onChanged: PushService.instance.isAvailable
                            ? (v) async {
                                await prefs.setPushEnabled(v);
                                if (v) {
                                  await PushService.instance.enable();
                                  await PushService.instance
                                      .registerCurrentToken();
                                } else {
                                  await PushService.instance.disable();
                                }
                              }
                            : null,
                      ),
                    ),
                    const Hairline(),
                    ListRow(
                      title: 'Notification preferences',
                      subtitle: 'Visitors, dues, deliveries and more',
                      icon: Icons2.switchIcon,
                      showChevron: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationPreferencesScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: Tokens.space5),
              SectionLabel('Support'),
              SizedBox(height: Tokens.space2),
              Panel(
                child: Column(
                  children: [
                    ListRow(
                      title: 'Emergency contacts',
                      subtitle: 'Gate, security and helplines',
                      icon: Icons2.emergency,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const _EmergencyRoute(),
                        ),
                      ),
                      showChevron: true,
                    ),
                    const Hairline(),
                    ListRow(
                      title: 'Forgot password',
                      subtitle: 'Reset with an OTP',
                      icon: Icons2.password,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      showChevron: true,
                    ),
                  ],
                ),
              ),

              SizedBox(height: Tokens.space7),
              OutlinedButton(
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Sign out?',
                    message: session.isSuperAdmin
                        ? 'You will need your password to sign back in to the '
                              'platform console.'
                        : 'You will need your password or OTP to sign back in.',
                    confirmLabel: 'Sign out',
                  );
                  if (ok != true) return;
                  await AppServices.instance.auth.logout();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tokens.danger,
                  side: BorderSide(color: Tokens.line),
                  minimumSize: const Size.fromHeight(46),
                ),
                child: const Text('Sign out'),
              ),

              SizedBox(height: Tokens.space5),
              Center(
                child: Text(
                  'Habito Living · v1.0.0',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    color: Tokens.inkFaint,
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space6),
            ],
          ),
        ),
      ),
    );
  }

  /// Theme picker: three explicit choices rather than a cycle, so "which mode
  /// am I in?" is answerable at a glance and "System" is reachable in one tap.
  Future<void> _pickTheme(BuildContext context, Preferences prefs) async {
    final picked = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Tokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space5,
                Tokens.space5,
                Tokens.space5,
                Tokens.space2,
              ),
              child: Text(
                'Theme',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeLg,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            for (final mode in ThemeMode.values)
              ListRow(
                title: mode.label,
                subtitle: switch (mode) {
                  ThemeMode.light => 'Always light',
                  ThemeMode.dark => 'Always dark',
                  ThemeMode.system => 'Follow the phone setting',
                },
                leading: const AppIcon(Icons2.theme, size: IconSize.row),
                trailing: prefs.themeMode == mode
                    ? const AppIcon(Icons2.save, size: IconSize.row)
                    : null,
                onTap: () => Navigator.of(ctx).pop(mode),
              ),
            const SizedBox(height: Tokens.space4),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await prefs.setThemeMode(picked);
  }

  String _flatLabel(dynamic membership) {
    if (membership is! Map) return 'Linked';
    final flat = membership['flat'];
    if (flat is Map) {
      final label = flat['label'] ?? flat['number'];
      if (label != null) return '$label';
    }
    return membership['flatId']?.toString() ?? 'Linked';
  }
}

class _EmergencyRoute extends StatelessWidget {
  const _EmergencyRoute();
  @override
  Widget build(BuildContext context) => const EmergencyScreen();
}
