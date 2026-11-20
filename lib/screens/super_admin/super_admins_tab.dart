import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/future_body.dart';

/// Society administrators across the platform: who has access, last sign-in,
/// and the two safety actions (deactivate, reset access).
class SuperAdminsTab extends StatelessWidget {
  const SuperAdminsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Administrators',
      subtitle: 'Society admins and platform staff',
      showBack: false,
      fillBody: true,
      body: FutureBody<List<AdminUser>>(
        load: () => AppServices.instance.superAdmin.admins(limit: 100),
        emptyIcon: Icons2.administrators,
        emptyTitle: 'No administrators',
        emptyMessage: 'Administrators appear here once a society has been created.',
        builder: (context, admins, reload) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          itemCount: admins.length,
          separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
          itemBuilder: (context, i) => _AdminCard(admin: admins[i], onChanged: reload),
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.admin, required this.onChanged});
  final AdminUser admin;
  final Future<void> Function() onChanged;

  Future<void> _deactivate(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Deactivate ${admin.name}?',
      message: 'They are signed out immediately and cannot sign in until reactivated.',
      confirmLabel: 'Deactivate',
    );
    if (!ok || !context.mounted) return;
    try {
      await AppServices.instance.superAdmin.deactivateAdmin(admin.id);
      if (context.mounted) showMessage(context, 'Administrator deactivated.');
      await onChanged();
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Reset access for ${admin.name}?',
      message: 'All their sessions are revoked and a one-time temporary password is created.',
      confirmLabel: 'Reset',
      destructive: false,
    );
    if (!ok || !context.mounted) return;
    try {
      final result = await AppServices.instance.superAdmin.resetAdminAccess(admin.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Tokens.surface,
          title: const Text('Temporary password'),
          content: SelectableText(
            '${result['temporaryPassword'] ?? '—'}\n\nShown once. Share it securely; they must change it at next sign-in.',
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Done'))],
        ),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = admin.status.toLowerCase() == 'active';
    return Panel(
      child: Row(
        children: [
          InitialsAvatar(name: admin.name),
          const SizedBox(width: Tokens.space4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(admin.name, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                if (admin.societyName != null)
                  Text(
                    [admin.societyName!, if (admin.societyCode != null) admin.societyCode!].join(' · '),
                    style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.ink),
                  ),
                Text(
                  [
                    Fmt.phone(admin.mobile),
                    if (admin.designation != null) admin.designation!,
                    if (admin.roleName != null) admin.roleName!,
                  ].join(' · '),
                  style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                ),
                Text(
                  admin.lastLoginAt == null ? 'Never signed in' : 'Last sign-in ${Fmt.relative(admin.lastLoginAt)}',
                  style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkFaint),
                ),
              ],
            ),
          ),
          StatusBadge(label: admin.status, tone: active ? Tone.positive : Tone.neutral),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'reset' ? _reset(context) : _deactivate(context),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reset', child: Text('Reset access')),
              if (active) const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
            ],
          ),
        ],
      ),
    );
  }
}
