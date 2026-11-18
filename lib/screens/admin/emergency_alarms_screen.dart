import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/future_body.dart';

Tone alarmTone(String raw) => switch (raw) {
  'ACTIVE' => Tone.danger,
  'ACKNOWLEDGED' => Tone.warning,
  'RESOLVED' => Tone.positive,
  _ => Tone.neutral,
};

/// Emergency incident management for the society admin.
///
/// Active alarms first, with who raised it, which flat, how to reach them and
/// what the guards have done so far. Acknowledge, resolve or mark a false
/// alarm; every action is attributed in the backend and shown to the others.
class EmergencyAlarmsScreen extends StatefulWidget {
  const EmergencyAlarmsScreen({super.key});

  @override
  State<EmergencyAlarmsScreen> createState() => _EmergencyAlarmsScreenState();
}

class _EmergencyAlarmsScreenState extends State<EmergencyAlarmsScreen> {
  String _view = 'active';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Emergencies',
      subtitle: 'Alarms raised in your society',
      fillBody: true,
      header: FilterChips(
        options: const [('active', 'Active'), ('history', 'History'), ('messages', 'Messages')],
        value: _view,
        onChanged: (v) => setState(() => _view = v),
      ),
      body: switch (_view) {
        'messages' => _messages(),
        'history' => _alarms('history'),
        _ => _alarms('active'),
      },
    );
  }

  Widget _alarms(String mode) {
    // The backend filters by one status at a time, so each tab asks for its
    // statuses and merges them, newest first. 50 per status is far more than a
    // society raises in practice; older history stays in the audit trail.
    final statuses = mode == 'active' ? const ['ACTIVE', 'ACKNOWLEDGED'] : const ['RESOLVED', 'FALSE_ALARM'];
    return FutureBody<List<EmergencyAlarm>>(
      key: ValueKey('alarms-$mode'),
      refreshOn: const [Events.emergencyAlert, Events.emergencyUpdated, 'emergency:panic'],
      emptyIcon: Icons2.emergency,
      emptyTitle: mode == 'active' ? 'No active emergencies' : 'No past alarms',
      emptyMessage: mode == 'active' ? 'New alarms appear here instantly.' : 'Resolved alarms and false alarms are kept here.',
      load: () async {
        final pages = await Future.wait(
          statuses.map((st) => AppServices.instance.ops.alarms(limit: 50, status: st)),
        );
        final merged = [for (final p in pages) ...p.items];
        merged.sort((x, y) => (y.createdAt ?? DateTime(0)).compareTo(x.createdAt ?? DateTime(0)));
        return merged;
      },
      builder: (context, alarms, reload) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: Tokens.space8),
        itemCount: alarms.length,
        separatorBuilder: (_, _) => const SizedBox(height: Tokens.space3),
        itemBuilder: (context, i) => _AlarmCard(alarm: alarms[i], onChanged: reload),
      ),
    );
  }

  Widget _messages() {
    return PagedBody<StaffMessage>(
      key: const ValueKey('messages'),
      refreshOn: const [Events.notification],
      emptyIcon: Icons2.chat,
      emptyTitle: 'No messages',
      emptyMessage: 'Emergency messages residents send to the admins and guards appear here.',
      fetch: (page) => AppServices.instance.ops.staffMessages(page: page),
      itemBuilder: (context, m, _) => Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    m.subject ?? 'Message',
                    style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink),
                  ),
                ),
                StatusBadge(label: m.audience == 'GUARDS' ? 'To guards' : 'To admins', tone: Tone.info),
              ],
            ),
            const SizedBox(height: 2),
            Text(m.message, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.ink, height: 1.4)),
            const SizedBox(height: Tokens.space2),
            Text(
              [if (m.fromName != null) m.fromName!, if (m.flatLabel != null) 'Flat ${m.flatLabel}', Fmt.dateTime(m.createdAt)].join(' · '),
              style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmCard extends StatefulWidget {
  const _AlarmCard({required this.alarm, required this.onChanged});
  final EmergencyAlarm alarm;
  final Future<void> Function() onChanged;

  @override
  State<_AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<_AlarmCard> {
  bool _busy = false;

  Future<void> _update(String status, String done, {bool askNote = false}) async {
    String? note;
    if (askNote) {
      note = await promptText(
        context,
        title: status == 'FALSE_ALARM' ? 'Mark as false alarm' : 'Resolve emergency',
        hint: 'Note (optional)',
        confirmLabel: 'Confirm',
      );
      if (note == null) return;
    }
    setState(() => _busy = true);
    try {
      await AppServices.instance.ops.updateAlarm(widget.alarm.id, status: status, note: note);
      if (!mounted) return;
      showMessage(context, done);
      widget.onChanged();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alarm;
    return Panel(
      color: a.isActive ? Tokens.dangerTint : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(Icons2.panic, size: IconSize.header, color: a.isActive ? Tokens.danger : Tokens.inkMuted),
              const SizedBox(width: Tokens.space3),
              Expanded(
                child: Text(
                  '${a.typeLabel}${a.flatLabel == null ? '' : ' · Flat ${a.flatLabel}'}',
                  style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeMd, fontWeight: FontWeight.w600, color: Tokens.ink),
                ),
              ),
              StatusBadge(label: a.statusLabel, tone: alarmTone(a.rawStatus), dot: a.isActive),
            ],
          ),
          if ((a.message ?? '').isNotEmpty) ...[
            const SizedBox(height: Tokens.space3),
            Text(a.message!, style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink, height: 1.4)),
          ],
          const SizedBox(height: Tokens.space3),
          DetailRow(label: 'Raised by', value: a.raisedByName ?? 'Unknown'),
          if (a.raisedByMobile != null) DetailRow(label: 'Contact', value: Fmt.phone(a.raisedByMobile), icon: Icons2.phone),
          if ((a.location ?? '').isNotEmpty) DetailRow(label: 'Location', value: a.location!),
          DetailRow(label: 'Time', value: '${Fmt.dateTime(a.createdAt)} (${Fmt.relative(a.createdAt)})'),
          if (a.acknowledgedAt != null)
            DetailRow(
              label: 'Acknowledged',
              value: '${a.acknowledgedByName ?? 'Staff'}${a.acknowledgedByRole == null ? '' : ' (${a.acknowledgedByRole!.toLowerCase()})'} · ${Fmt.time(a.acknowledgedAt)}',
            ),
          if (a.resolvedAt != null)
            DetailRow(
              label: a.rawStatus == 'FALSE_ALARM' ? 'Closed as false alarm' : 'Resolved',
              value: '${a.resolvedByName ?? 'Staff'}${a.resolvedByRole == null ? '' : ' (${a.resolvedByRole!.toLowerCase()})'} · ${Fmt.time(a.resolvedAt)}',
            ),
          if (a.isOpen) ...[
            const SizedBox(height: Tokens.space3),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                if (a.isActive)
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _update('ACKNOWLEDGED', 'Acknowledged. Residents and guards can see you are on it.'),
                    style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.accentOn),
                    icon: const AppIcon(Icons2.success, size: IconSize.inline),
                    label: const Text('Acknowledge'),
                  ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _update('RESOLVED', 'Marked resolved.', askNote: true),
                  style: FilledButton.styleFrom(backgroundColor: Tokens.positive, foregroundColor: Colors.white),
                  icon: const AppIcon(Icons2.success, size: IconSize.inline),
                  label: const Text('Resolve'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _update('FALSE_ALARM', 'Marked as a false alarm.', askNote: true),
                  child: const Text('False alarm'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
