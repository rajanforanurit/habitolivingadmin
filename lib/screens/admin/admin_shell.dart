import 'package:flutter/material.dart';

import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/widgets/bottom_nav.dart';
import '../../services/notification_router.dart';
import '../widgets/tab_host.dart';
import 'approvals_tab.dart';
import 'complaints_tab.dart';
import 'finance_tab.dart';
import 'gate_screen.dart';
import 'notices_screen.dart';
import 'overview_tab.dart';
import 'residents_tab.dart';

/// Admin shell.
///
/// Five tabs, in the order an admin's day goes: what needs me now, the
/// paperwork, money, people, then the building itself. Everything else — staff,
/// vendors, amenities, marketplace, notices — lives one level down in More,
/// because there are too many to keep on the nav bar and the nav bar is the
/// one thing that must stay small.
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

  @override
  void initState() {
    super.initState();
    listenForTabRequests();
    _routes = NotificationRouter.register(
      {
        'gate': (_) => const GateScreen(),
        'notices': (_) => const NoticesScreen(),
      },
      tabSections: const {
        'approvals': 1,
        'approval': 1,
        'finance': 2,
        'invoices': 2,
        'expenses': 2,
        'charges': 2,
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
    _routes.dispose();
    super.dispose();
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
    FinanceTab(),
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
      icon: Icons2.finance,
      activeIcon: Icons2.finance,
      label: 'Money',
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
    return RoleShell(
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
    );
  }
}
