import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../widgets/future_body.dart';
import 'super_society_detail_screen.dart';

class _Overview {
  const _Overview(this.dashboard, this.pending);
  final Map<String, dynamic> dashboard;
  final List<PlatformSociety> pending;
}

/// Platform overview: how many societies and how many are waiting for approval.
///
/// Deliberately has no platform-health, login, authentication-failure or error figures. Those
/// are per-society operational data and live in each society admin's Platform
/// section.
class SuperOverviewTab extends StatelessWidget {
  const SuperOverviewTab({super.key});

  Future<_Overview> _load() async {
    final api = AppServices.instance.superAdmin;
    final results = await Future.wait<Object?>([
      api.dashboard(),
      api.societies(status: 'PENDING', limit: 5),
    ]);
    return _Overview(
      results[0] as Map<String, dynamic>,
      (results[1] as PageResult<PlatformSociety>).items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Platform',
      subtitle: 'Societies and administrators',
      showBack: false,
      fillBody: true,
      body: FutureBody<_Overview>(
        load: _load,
        refreshOn: const ['society:updated'],
        builder: (context, data, reload) {
          final societies = asMap(data.dashboard['societies']);
          final pending = asInt(societies['pending']);
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            children: [
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Societies', value: '${asInt(societies['total'])}', hint: '${asInt(societies['active'])} active')),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: MetricTile(
                      label: 'Awaiting approval',
                      value: '$pending',
                      tone: pending > 0 ? Tokens.warning : null,
                      hint: pending > 0 ? 'Needs your review' : 'All clear',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space3),
              Row(
                children: [
                  Expanded(child: MetricTile(label: 'Residents', value: '${asInt(data.dashboard['residents'])}')),
                  const SizedBox(width: Tokens.space3),
                  Expanded(child: MetricTile(label: 'Guards', value: '${asInt(data.dashboard['guards'])}')),
                  const SizedBox(width: Tokens.space3),
                  Expanded(child: MetricTile(label: 'Admins', value: '${asInt(data.dashboard['admins'])}')),
                ],
              ),
              const SizedBox(height: Tokens.space6),
              SectionLabel('Pending societies', trailing: Text('${data.pending.length} shown', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkFaint))),
              const SizedBox(height: Tokens.space2),
              if (data.pending.isEmpty)
                Panel(
                  child: Text(
                    'No society is waiting for approval.',
                    style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                  ),
                )
              else
                Panel(
                  child: Column(
                    children: [
                      for (var i = 0; i < data.pending.length; i++) ...[
                        if (i > 0) const Hairline(),
                        ListRow(
                          title: data.pending[i].name,
                          subtitle: [
                            if (data.pending[i].city != null) data.pending[i].city!,
                            if (data.pending[i].adminName != null) 'Applicant ${data.pending[i].adminName}',
                          ].join(' · '),
                          icon: Icons2.societies,
                          showChevron: true,
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => SuperSocietyDetailScreen(societyId: data.pending[i].id),
                            ));
                            reload();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

}
