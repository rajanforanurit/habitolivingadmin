import 'package:flutter/material.dart';

import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/widgets/bottom_nav.dart';
import 'super_more_screen.dart';
import 'super_overview_tab.dart';
import 'super_societies_tab.dart';

/// Super Admin portal: the platform team's view.
///
/// Three tabs: Overview, Societies and More. The portal manages the platform and its societies; per-society
/// operations (logins, auth errors, community moderation, emergencies) belong
/// to each society's own admin portal and are not shown here.
class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});

  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _index = 0;
  final List<bool> _visited = [true, false, false];

  static const _pages = <Widget>[
    SuperOverviewTab(),
    SuperSocietiesTab(),
    SuperMoreScreen(),
  ];

  static const _destinations = <NavDestination>[
    NavDestination(icon: Icons2.monitoring, activeIcon: Icons2.monitoring, label: 'Overview'),
    NavDestination(icon: Icons2.societies, activeIcon: Icons2.societies, label: 'Societies'),
    NavDestination(icon: Icons2.more, activeIcon: Icons2.more, label: 'More'),
  ];

  void _select(int i) => setState(() {
    _index = i;
    _visited[i] = true;
  });

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
