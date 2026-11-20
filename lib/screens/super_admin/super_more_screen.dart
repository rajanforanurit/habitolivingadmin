import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../root_shell.dart' show confirmAndLogout;
import '../settings_screen.dart';
import '../widgets/future_body.dart';

/// Account, platform announcements and sign-out.
class SuperMoreScreen extends StatelessWidget {
  const SuperMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = currentIdentity()?.user;
    return AppScaffold(
      title: 'More',
      subtitle: 'Account and platform tools',
      showBack: false,
      fillBody: true,
      body: ListView(
        padding: const EdgeInsets.only(bottom: Tokens.space8),
        children: [
          Panel(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            child: Row(
              children: [
                InitialsAvatar(name: user?.name ?? 'Super admin', size: 44),
                const SizedBox(width: Tokens.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'Super admin', style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                      Text(
                        [if (user != null) Fmt.phone(user.mobile), 'Super admin'].join(' · '),
                        style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                      ),
                    ],
                  ),
                ),
                AppIcon(Icons2.forward, size: IconSize.row, color: Tokens.inkFaint),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space6),
          const SectionLabel('Platform'),
          const SizedBox(height: Tokens.space2),
          Panel(
            child: Column(
              children: [
                ListRow(
                  title: 'Announcements',
                  subtitle: 'Messages to society admins',
                  icon: Icons2.communications,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _AnnouncementsScreen())),
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space6),
          const SectionLabel('Account'),
          const SizedBox(height: Tokens.space2),
          Panel(
            child: Column(
              children: [
                ListRow(
                  title: 'Settings',
                  subtitle: 'Theme, notifications, password',
                  icon: Icons2.settings,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                const Hairline(),
                ListRow(
                  title: 'Sign out',
                  icon: Icons2.logout,
                  onTap: () => confirmAndLogout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsScreen extends StatefulWidget {
  const _AnnouncementsScreen();

  @override
  State<_AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<_AnnouncementsScreen> {
  int _revision = 0;

  Future<void> _create() async {
    final created = await showDialog<bool>(context: context, builder: (_) => const _AnnouncementDialog());
    if (created == true && mounted) {
      showMessage(context, 'Announcement sent.');
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Announcements',
      subtitle: 'Sent to society administrators',
      fillBody: true,
      floatingAction: FloatingActionButton(
        onPressed: _create,
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBody<List<Map<String, dynamic>>>(
        key: ValueKey(_revision),
        load: () => AppServices.instance.superAdmin.announcements(limit: 50),
        emptyIcon: Icons2.communications,
        emptyTitle: 'No announcements',
        emptyMessage: 'Tell society admins about maintenance, releases or policy changes.',
        builder: (context, items, reload) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
          itemBuilder: (context, i) {
            final a = items[i];
            final severity = asString(a['severity'], fallback: 'INFO');
            return Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(asString(a['title']), style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink))),
                      StatusBadge(
                        label: humanize(severity),
                        tone: switch (severity) { 'CRITICAL' => Tone.danger, 'WARNING' => Tone.warning, _ => Tone.info },
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: AppIcon(Icons2.delete, size: IconSize.row, color: Tokens.inkFaint),
                        onPressed: () async {
                          final ok = await confirmDialog(context, title: 'Delete announcement?', message: 'Admins will no longer see it.', confirmLabel: 'Delete');
                          if (!ok || !context.mounted) return;
                          try {
                            await AppServices.instance.superAdmin.deleteAnnouncement(asString(a['id']));
                            await reload();
                          } catch (e) {
                            if (context.mounted) showMessage(context, friendlyError(e), error: true);
                          }
                        },
                      ),
                    ],
                  ),
                  Text(asString(a['body']), style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted, height: 1.4)),
                  const SizedBox(height: Tokens.space2),
                  Text(Fmt.dateTime(asDateOrNull(a['createdAt'])), style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkFaint)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog();

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _severity = 'INFO';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().length < 3 || _body.text.trim().length < 3) {
      setState(() => _error = 'Add a title and a message.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.superAdmin.createAnnouncement(
        title: _title.text.trim(),
        body: _body.text.trim(),
        severity: _severity,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: const Text('New announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: Tokens.space3),
            TextField(controller: _body, maxLines: 4, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
            const SizedBox(height: Tokens.space3),
            Wrap(
              spacing: Tokens.space2,
              children: [
                for (final s in const ['INFO', 'WARNING', 'CRITICAL'])
                  ChoiceChip(label: Text(humanize(s)), selected: _severity == s, onSelected: (_) => setState(() => _severity = s)),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: Tokens.space3),
              Text(_error!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          onPressed: _busy ? null : _send,
          child: const Text('Send'),
        ),
      ],
    );
  }
}
