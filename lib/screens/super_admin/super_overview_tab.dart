import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../widgets/future_body.dart';

/// Platform overview: how many societies are active and inactive, and who uses them.
///
/// Deliberately has no platform-health, login, authentication-failure or error figures. Those
/// are per-society operational data and live in each society admin's Platform
/// section.
class SuperOverviewTab extends StatelessWidget {
  const SuperOverviewTab({super.key});

  Future<Map<String, dynamic>> _load() => AppServices.instance.superAdmin.dashboard();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Platform',
      subtitle: 'Societies and administrators',
      showBack: false,
      fillBody: true,
      body: FutureBody<Map<String, dynamic>>(
        load: _load,
        refreshOn: const ['society:updated'],
        builder: (context, data, _) {
          final societies = asMap(data['societies']);
          final inactive = asInt(societies['inactive']);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            children: [
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Societies', value: '${asInt(societies['total'])}', hint: '${asInt(societies['active'])} active')),
                  const SizedBox(width: Tokens.space3),
                  Expanded(child: MetricTile(label: 'Inactive', value: '$inactive', hint: 'Societies switched off')),
                ],
              ),
              const SizedBox(height: Tokens.space3),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Residents', value: '${asInt(data['residents'])}')),
                  const SizedBox(width: Tokens.space3),
                  Expanded(child: MetricTile(label: 'Guards', value: '${asInt(data['guards'])}')),
                  const SizedBox(width: Tokens.space3),
                  Expanded(child: MetricTile(label: 'Admins', value: '${asInt(data['admins'])}')),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

}
