import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../app.dart';

/// Emergency: the screen that must work first.
///
/// Two things are true of an emergency screen:
///   1. It works offline-ish — contacts come from a cached copy as well as the
///      network, because a panic button that needs a round trip is not one.
///   2. It is one tap to call. No confirmation dialog: a resident in an
///      emergency does not need to confirm that they meant it.
///
/// The panic alert is a separate, deliberate action with a confirmation, because
/// it pages the whole security team.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  late Future<void> _load;

  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<void> _fetch() async {
    final api = AppServices.instance.resident;
    final results = await Future.wait([
      api.emergencyContacts(),
      api.incidents(limit: 5),
    ]);
    if (!mounted) return;
    setState(() {
      _contacts = results[0] as List<EmergencyContact>;
      _incidents = results[1] as PageResult<Incident>;
    });
  }

  List<EmergencyContact> _contacts = const [];
  PageResult<Incident>? _incidents;
  Object? _error;

  Future<void> _refresh() async {
    try {
      await _fetch();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _call(EmergencyContact contact) async {
    final number = (contact.phone ?? '').trim();
    if (number.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: number);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        showMessage(context, 'Could not start the call: $e', error: true);
      }
    }
  }

  Future<void> _panic() async {
    final ok = await confirmDialog(
      context,
      title: 'Raise a panic alert?',
      message:
          'Security and the society admin are alerted immediately, with '
          'your flat and the time. Only use this if you need help now.',
      confirmLabel: 'Send alert',
    );
    if (ok != true) return;
    try {
      await AppServices.instance.resident.raisePanic(
        message: 'Panic alert raised from the app',
      );
      if (!mounted) return;
      showMessage(context, 'Alert sent. Security has been notified.');
      await _refresh();
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Emergency',
      subtitle: AppServices.instance.session.societyName,
      showBack: true,
      onRefresh: _refresh,
      body: FutureBuilder<void>(
        future: _load,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingPage();
          }
          if (_error != null && _contacts.isEmpty) {
            return ErrorState(message: '$_error', onRetry: _refresh);
          }
          return ListView(
            padding: EdgeInsets.only(
              left: Tokens.gutter,
              right: Tokens.gutter,
              bottom: kScreenBottomPadding,
            ),
            children: [
              _PanicCard(onPressed: _panic),
              const SectionLabel('Call now'),
              const SizedBox(height: Tokens.space2),
              if (_contacts.isEmpty)
                const EmptyState(
                  icon: Icons2.phone,
                  title: 'No contacts published',
                  message:
                      'Your society has not added security or helpline '
                      'numbers yet.',
                  compact: true,
                )
              else
                Column(
                  children: [
                    for (final c in _contacts) ...[
                      _ContactTile(contact: c, onCall: _call),
                      if (c != _contacts.last) const Hairline(),
                    ],
                  ],
                ),
              if (_incidents != null && _incidents!.items.isNotEmpty) ...[
                const SectionLabel('Recent incidents'),
                const SizedBox(height: Tokens.space2),
                for (final i in _incidents!.items) ...[
                  ListRow(
                    title: i.type,
                    subtitle: i.description ?? i.location,
                    leading: const AppIcon(
                      Icons2.incidents,
                      size: IconSize.row,
                    ),
                    trailing: StatusBadge.forStatus(
                      i.status,
                      domain: StatusDomain.incident,
                    ),
                  ),
                  const Hairline(),
                ],
              ],
              const SizedBox(height: Tokens.space6),
            ],
          );
        },
      ),
    );
  }
}

/// The panic button. Full width, danger colour, no icon that looks friendly.
class _PanicCard extends StatelessWidget {
  const _PanicCard({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space6),
      child: SizedBox(
        height: 64,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Tokens.danger,
            // White glyph and white label: the dark ink colour was nearly
            // invisible against the dark red fill.
            foregroundColor: Tokens.accentOn,
          ),
          icon: AppIcon(
            Icons2.emergency,
            size: IconSize.header,
            color: Tokens.accentOn,
          ),
          label: Text(
            'Panic alert',
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeMd,
              fontWeight: FontWeight.w600,
              color: Tokens.accentOn,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onCall});
  final EmergencyContact contact;
  final ValueChanged<EmergencyContact> onCall;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: contact.name,
      subtitle: [contact.category, contact.phone].join(' · '),
      icon: Icons2.phone,
      onTap: () => onCall(contact),
      trailing: const AppIcon(Icons2.external, size: IconSize.inline),
    );
  }
}
