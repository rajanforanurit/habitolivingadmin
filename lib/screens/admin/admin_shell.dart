import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/socket_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/bottom_nav.dart';
import '../../services/notification_router.dart';
import '../calls/call_contacts_screen.dart';
import '../widgets/tab_host.dart';
import 'admin_settings_tab.dart';
import 'approvals_tab.dart';
import 'complaints_tab.dart';
import 'community_moderation_screen.dart';
import 'emergency_alarms_screen.dart';
import 'helpdesk_screen.dart';
import 'platform_monitor_screen.dart';
import 'society_info_screen.dart';
import 'gate_screen.dart';
import 'notices_screen.dart';
import 'overview_tab.dart';
import 'residents_tab.dart';

/// Admin shell.
///
/// Five tabs: what needs me now, the paperwork, settings, people, then the
/// reports. Settings holds everything that is not an everyday job — gates,
/// guards, staff, amenities, marketplace, documents, account — because there
/// are too many to keep on the nav bar and the nav bar must stay small.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with TabHost<AdminShell> {
  late int _index = widget.initialTab;
  final List<bool> _visited = <bool>[true, false, false, false, false];
  late final Registration _routes;
  void Function()? _cancelAlerts;
  final Set<String> _shownAlerts = {};

  @override
  void initState() {
    super.initState();
    listenForTabRequests();
    _cancelAlerts = AppServices.instance.socket.on(Events.emergencyAlert, _onEmergency);
    _routes = NotificationRouter.register(
      {
        'gate': (_) => const GateScreen(),
        'notices': (_) => const NoticesScreen(),
        // An admin's emergency tap opens the alarm centre, not the resident
        // panic screen the shared fallback would show.
        'emergency': (_) => const EmergencyAlarmsScreen(),
        'alarm': (_) => const EmergencyAlarmsScreen(),
        'panic': (_) => const EmergencyAlarmsScreen(),
        'sos': (_) => const EmergencyAlarmsScreen(),
        'helpdesk': (_) => const HelpdeskScreen(),
        'call': (_) => const CallContactsScreen(),
        'calls': (_) => const CallContactsScreen(),
        'posts': (_) => const CommunityModerationScreen(),
        'community': (_) => const CommunityModerationScreen(),
        'platform': (_) => const PlatformMonitorScreen(),
        'society': (_) => const SocietyInfoScreen(),
      },
      tabSections: const {
        'approvals': 1,
        'approval': 1,
        'settings': 2,
        'residents': 3,
        'resident': 3,
        'complaints': 4,
        'complaint': 4,
        'tickets': 4,
        'reports': 4,
        'overview': 0,
      },
    );
  }

  @override
  void dispose() {
    _cancelAlerts?.call();
    _routes.dispose();
    super.dispose();
  }

  /// A live emergency alarm from this society. Interrupts whatever the admin
  /// is doing: who raised it, where, and one tap to the alarm centre.
  void _onEmergency(RealtimeEvent e) {
    if (!mounted) return;
    final d = e.data;
    final id = asStringOrNull(d['id'] ?? d['alertId']);
    if (id != null && !_shownAlerts.add(id)) return; // already shown (duplicate event)
    HapticFeedback.heavyImpact();
    final who = asString(d['raisedByName'], fallback: 'A resident');
    final flat = asStringOrNull(d['flatLabel'] ?? d['flat']);
    final message = asStringOrNull(d['message']);
    final location = asStringOrNull(d['location']);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tokens.dangerTint,
        icon: Icon(Icons.warning_amber_rounded, color: Tokens.danger, size: 40),
        title: Text(
          'Emergency alarm',
          style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w700, color: Tokens.danger),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              flat == null ? who : '$who · Flat $flat',
              style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeMd, fontWeight: FontWeight.w600, color: Tokens.ink),
            ),
            if (location != null) Text(location, style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.inkMuted)),
            if (message != null && message.isNotEmpty) ...[
              const SizedBox(height: Tokens.space3),
              Text(message, style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Dismiss')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Tokens.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyAlarmsScreen()));
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  @override
  int get tabCount => 5;

  @override
  void onTabRequest(int index) => _select(index);

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      if (index >= 0 && index < _visited.length) _visited[index] = true;
    });
  }

  static const _pages = <Widget>[
    OverviewTab(),
    ApprovalsTab(),
    AdminSettingsTab(),
    ResidentsTab(),
    ComplaintsTab(),
  ];

  static const _destinations = <NavDestination>[
    NavDestination(
      icon: Icons2.monitoring,
      activeIcon: Icons2.monitoring,
      label: 'Overview',
    ),
    NavDestination(
      icon: Icons2.approvals,
      activeIcon: Icons2.approvals,
      label: 'Approvals',
    ),
    NavDestination(
      icon: Icons2.settings,
      activeIcon: Icons2.settings,
      label: 'Settings',
    ),
    NavDestination(
      icon: Icons2.residents,
      activeIcon: Icons2.residents,
      label: 'Residents',
    ),
    NavDestination(
      icon: Icons2.reports,
      activeIcon: Icons2.reports,
      label: 'Reports',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return IncomingCallOverlay(
      child: RoleShell(
        index: _index,
        onSelected: _select,
        destinations: _destinations,
        child: IndexedStack(
          index: _index,
          children: [
            for (var i = 0; i < _pages.length; i++)
              _visited[i] ? _pages[i] : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
