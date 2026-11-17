import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/society.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// One resident, in full: their flat, their membership state, and the three
/// decisions an admin can make about them.
///
/// Approve and deactivate are separate because they are different sentences:
/// "you are allowed in" versus "you are not allowed in any more". Rejecting is a
/// third thing again — it needs a reason, because the person is standing at the
/// gate holding a phone.
class ResidentDetailScreen extends StatefulWidget {
  const ResidentDetailScreen({super.key, required this.resident});

  final Resident resident;

  @override
  State<ResidentDetailScreen> createState() => _ResidentDetailScreenState();
}

class _ResidentDetailScreenState extends State<ResidentDetailScreen> {
  @override
  void initState() {
    super.initState();
    _resident = widget.resident;
  }

  late final Resident _resident;
  bool _busy = false;

  Future<void> _run(
    Future<void> Function() action,
    String message, {
    bool pop = true,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, message);
      if (pop) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reasoned({
    required String title,
    required String hint,
    required String confirm,
    required Future<void> Function(String reason) action,
    required String ok,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) =>
          _ReasonDialog(title: title, hint: hint, confirm: confirm),
    );
    if (reason == null) return;
    await _run(() => action(reason), ok);
  }

  Future<void> _recordVerification() async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ReasonDialog(
        title: 'Record a verification',
        hint: 'What you checked, e.g. "Sale deed and Aadhaar match"',
        confirm: 'Record',
      ),
    );
    if (note == null) return;
    await _run(
      () => AppServices.instance.admin.recordVerification(
        residentId: _resident.id,
        ownershipVerified: true,
        notes: note.isEmpty ? null : note,
      ),
      'Verification recorded.',
      pop: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppServices.instance.admin;
    final r = _resident;
    final status = r.status.toUpperCase();
    final pending = status == 'PENDING';
    final active = status == 'APPROVED';

    return AppScaffold(
      title: r.name,
      subtitle: r.flat?.label ?? 'No flat assigned',
      body: ListView(
        padding: EdgeInsets.only(bottom: Tokens.space8),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(Tokens.space4),
              decoration: BoxDecoration(
                color: Tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          r.name,
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeMd,
                            fontWeight: FontWeight.w600,
                            color: Tokens.ink,
                          ),
                        ),
                      ),
                      StatusBadge.forStatus(
                        r.status,
                        domain: StatusDomain.generic,
                      ),
                    ],
                  ),
                  SizedBox(height: Tokens.space1),
                  Text(
                    [
                      r.residentType,
                      if (r.email != null) r.email!,
                      if (r.joinedAt != null) 'joined ${Fmt.date(r.joinedAt)}',
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: Tokens.space6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Text(
              'Actions',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
          ),
          SizedBox(height: Tokens.space3),
          if (_busy)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Tokens.surfaceSunken,
                color: Tokens.accent,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Column(
                children: [
                  if (pending)
                    _ActionCard(
                      title: 'Approve this resident',
                      message:
                          'They will be able to use the app and see society notices.',
                      label: 'Approve',
                      icon: Icons2.success,
                      onTap: () =>
                          _run(() => admin.approveResident(r.id), 'Approved.'),
                    ),
                  if (pending)
                    _ActionCard(
                      title: 'Reject this request',
                      message:
                          'They will be told why, and can ask a guard or the admin '
                          'in person.',
                      label: 'Reject',
                      icon: Icons2.close,
                      destructive: true,
                      onTap: () => _reasoned(
                        title: 'Reject',
                        hint: 'The resident will see this',
                        confirm: 'Reject',
                        ok: 'Rejected.',
                        action: (reason) =>
                            admin.rejectResident(r.id, reason: reason),
                      ),
                    ),
                  if (active)
                    _ActionCard(
                      title: 'Suspend access',
                      message:
                          'They keep their history but cannot sign in until you '
                          'restore them.',
                      label: 'Suspend',
                      icon: Icons2.cancel,
                      destructive: true,
                      onTap: () => _reasoned(
                        title: 'Suspend',
                        hint: 'Why is access being suspended?',
                        confirm: 'Suspend',
                        ok: 'Suspended.',
                        action: (reason) => admin.deactivateResident(r.id),
                      ),
                    ),
                  if (!active)
                    _ActionCard(
                      title: 'Restore access',
                      message: 'They can sign in and use the app again.',
                      label: 'Activate',
                      icon: Icons2.refresh,
                      onTap: () => _run(
                        () => admin.activateResident(r.id),
                        'Access restored.',
                      ),
                    ),
                  _ActionCard(
                    title: 'Record a verification',
                    message:
                        'Note that you checked an ID or document. It shows on their '
                        'record so the next admin knows.',
                    label: 'Record',
                    icon: Icons2.file,
                    onTap: _recordVerification,
                  ),
                ],
              ),
            ),

          SizedBox(height: Tokens.space6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Text(
              'Account',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
          ),
          const SizedBox(height: Tokens.space3),
          Panel(
            margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Column(
              children: [
                ListRow(
                  title: 'Mobile',
                  subtitle: r.mobile.isEmpty ? 'Not on file' : r.mobile,
                  icon: Icons2.phone,
                ),
                if (r.email != null) ...[
                  const Hairline(),
                  ListRow(
                    title: 'Email',
                    subtitle: r.email,
                    icon: Icons2.email,
                  ),
                ],
                const Hairline(),
                ListRow(
                  title: 'Flat',
                  subtitle: r.flat?.label ?? 'Not assigned',
                  icon: Icons2.flat,
                ),
                const Hairline(),
                ListRow(
                  title: 'Permissions',
                  subtitle: r.permissions.isEmpty
                      ? 'Standard resident'
                      : r.permissions.entries
                            .where((e) => e.value)
                            .map((e) => e.key)
                            .join(', '),
                  icon: Icons2.roles,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.message,
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Tokens.space2),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(Tokens.space3),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
          border: Border.all(color: Tokens.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      height: 1.4,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Tokens.space3),
            _Button(
              label: label,
              icon: icon,
              destructive: destructive,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({
    required this.label,
    required this.icon,
    required this.destructive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool destructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = destructive ? Tokens.danger : Tokens.accent;
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space2,
          ),
          decoration: BoxDecoration(
            color: destructive ? Tokens.dangerTint : Tokens.accentTint,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(icon, size: IconSize.inline, color: fg),
              const SizedBox(width: Tokens.space1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.hint,
    required this.confirm,
  });

  final String title;
  final String hint;
  final String confirm;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        widget.title,
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        maxLength: 300,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
