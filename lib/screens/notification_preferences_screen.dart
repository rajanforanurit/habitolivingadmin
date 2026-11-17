import 'package:flutter/material.dart';

import '../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

/// Notification preferences: what the society is allowed to ping you about.
///
/// One switch per category, matching the backend's `notificationPrefs` record.
/// These gate push, SMS and email in one place — muting PAYMENT here means no
/// invoice reminder arrives on any channel, which is what a resident means
/// when they say "stop reminding me".
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  static final _labels = <(String, String, String, IconData)>[
    (
      'visitor',
      'Visitors at the gate',
      'Entry approvals and expected guests',
      Icons2.visitors,
    ),
    ('delivery', 'Deliveries', 'Parcels and handovers', Icons2.deliveries),
    (
      'payment',
      'Payments and dues',
      'Invoices, receipts and overdue reminders',
      Icons2.payments,
    ),
    (
      'complaint',
      'Complaints',
      'Status updates on your requests',
      Icons2.complaints,
    ),
    (
      'marketplace',
      'Marketplace',
      'Offers and activity in the store',
      Icons2.marketplace,
    ),
    (
      'announcement',
      'Announcements',
      'Society notices and circulars',
      Icons2.notices,
    ),
    (
      'booking',
      'Bookings',
      'Amenity slot confirmations and changes',
      Icons2.calendar,
    ),
    ('chat', 'Chat', 'Direct messages from the society team', Icons2.chat),
    (
      'push',
      'Push notifications',
      'In-app banners on this device',
      Icons2.notifications,
    ),
    ('sms', 'SMS', 'Text messages for critical events', Icons2.phone),
    ('email', 'Email', 'Receipts and long-form notices', Icons2.email),
  ];

  final Map<String, bool> _prefs = {
    for (final (key, _, _, _) in _labels) key: true,
  };

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await AppServices.instance.resident.profile();
      final stored = asMapOrNull(profile['notificationPrefs']);
      if (!mounted) return;
      setState(() {
        if (stored != null) {
          for (final entry in stored.entries) {
            if (_prefs.containsKey(entry.key)) {
              _prefs[entry.key] = entry.value == true;
            }
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AppServices.instance.resident.saveNotificationPreferences(
        Map<String, bool>.from(_prefs),
      );
      if (!mounted) return;
      showMessage(context, 'Notification preferences saved.');
      setState(() => _saving = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(title: 'Notifications', body: LoadingList());
    }
    if (_error != null && _prefs.values.every((v) => v)) {
      return AppScaffold(
        title: 'Notifications',
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    return AppScaffold(
      title: 'Notifications',
      subtitle: 'What the society may ping you about',
      actions: [
        HeaderAction(
          icon: Icons2.save,
          tooltip: 'Save',
          onPressed: _saving ? null : _save,
        ),
      ],
      body: ListView(
        // AppScaffold's composed-body path already applies the screen gutter
        // horizontally, so no extra horizontal padding here.
        // Rows are ListRows with their own inner padding; the page gutter
        // comes from here so the rows and the header share the same edges.
        padding: EdgeInsets.only(
          left: Tokens.gutter,
          right: Tokens.gutter,
          bottom: kScreenBottomPadding,
        ),
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            ListRow(
              title: _labels[i].$2,
              subtitle: _labels[i].$3,
              leading: AppIcon(_labels[i].$4, size: IconSize.row),
              dense: false,
              showChevron: false,
              trailing: AppSwitch(
                value: _prefs[_labels[i].$1] ?? true,
                onChanged: (v) => setState(() => _prefs[_labels[i].$1] = v),
              ),
            ),
            if (i < _labels.length - 1) const Hairline(indent: 60),
          ],
          Hairline(indent: 0),
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space4),
            child: Text(
              'These switches gate push, SMS and email for each category. '
              'The notification inbox inside the app always records everything, '
              'whatever you choose here.',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.5,
                color: Tokens.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
