import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../widgets/file_preview.dart';
import '../widgets/future_body.dart';

/// Property details, floor plans and hospitals, as set up by the platform team.
///
/// Read-only on purpose: these are maintained by the Super Admin so they
/// cannot be lost to a mistaken edit. A society admin who needs a change asks
/// the platform team.
class SocietyInfoScreen extends StatelessWidget {
  const SocietyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Property details',
      subtitle: 'Towers, units, floor plans and hospitals',
      fillBody: true,
      body: FutureBody<SocietyInfo>(
        load: AppServices.instance.ops.societyInfo,
        refreshOn: const ['society:property-info-changed'],
        builder: (context, info, reload) {
          final d = info.propertyDetails;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            children: [
              Panel(
                color: Tokens.accentTint,
                child: Row(
                  children: [
                    AppIcon(Icons2.info, size: IconSize.row, color: Tokens.accent),
                    const SizedBox(width: Tokens.space3),
                    Expanded(
                      child: Text(
                        'Managed by the platform team and shown to your residents. To change it, contact support.',
                        style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.ink, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Tokens.space5),
              if (d.isEmpty)
                Panel(child: Text('The platform team has not added property details yet.', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)))
              else ...[
                Panel(
                  child: Column(
                    children: [
                      DetailRow(label: 'Property', value: d.propertyName ?? info.societyName),
                      if (info.code != null) DetailRow(label: 'Society code', value: info.code!),
                      if (info.propertyType != null) DetailRow(label: 'Type', value: PropertyKind.label(info.propertyType)),
                      if (d.totalTowers != null && d.totalTowers! > 0) DetailRow(label: 'Towers', value: '${d.totalTowers}'),
                      if (d.totalFloors != null && d.totalFloors! > 0) DetailRow(label: 'Max floors', value: '${d.totalFloors}'),
                      if (d.totalUnits != null) DetailRow(label: 'Units', value: '${d.totalUnits}'),
                      if ((d.parkingInfo ?? '').isNotEmpty) DetailRow(label: 'Parking', value: d.parkingInfo!),
                      if ((d.description ?? '').isNotEmpty) DetailRow(label: 'About', value: d.description!),
                      if ((d.notes ?? '').isNotEmpty) DetailRow(label: 'Notes', value: d.notes!),
                    ],
                  ),
                ),
                if (d.towers.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space5),
                  const SectionLabel('Towers'),
                  const SizedBox(height: Tokens.space2),
                  Panel(
                    child: Column(
                      children: [
                        for (var i = 0; i < d.towers.length; i++) ...[
                          if (i > 0) const Hairline(),
                          ListRow(
                            title: '${d.towers[i].name} (${d.towers[i].code})',
                            subtitle: '${d.towers[i].floors.length} floors · ${d.towers[i].totalUnits} units',
                            icon: Icons2.tower,
                            dense: true,
                            showChevron: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (d.singleFamily != null) ...[
                  const SizedBox(height: Tokens.space5),
                  const SectionLabel('Houses'),
                  const SizedBox(height: Tokens.space2),
                  Panel(
                    child: DetailRow(
                      label: 'Houses',
                      value: '${d.singleFamily!.totalHouses} · ${d.singleFamily!.labelAt(0)} … ${d.singleFamily!.labelAt(d.singleFamily!.totalHouses - 1)}',
                    ),
                  ),
                ],
                if (d.floorPlans.isNotEmpty) ...[
                  const SizedBox(height: Tokens.space5),
                  const SectionLabel('Floor plans'),
                  const SizedBox(height: Tokens.space2),
                  for (final plan in d.floorPlans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Tokens.space3),
                      child: Panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plan.title, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                            if ((plan.description ?? '').isNotEmpty)
                              Text(plan.description!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)),
                            if (plan.fileId != null) ...[
                              const SizedBox(height: Tokens.space3),
                              FilePreview(fileId: plan.fileId!),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: Tokens.space5),
              const SectionLabel('Hospitals'),
              const SizedBox(height: Tokens.space2),
              if (info.hospitals.isEmpty)
                Panel(child: Text('No hospitals added yet.', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)))
              else
                Panel(
                  child: Column(
                    children: [
                      for (var i = 0; i < info.hospitals.length; i++) ...[
                        if (i > 0) const Hairline(),
                        ListRow(
                          title: info.hospitals[i].name,
                          subtitle: [
                            Fmt.phone(info.hospitals[i].phone),
                            if (info.hospitals[i].distanceKm != null) '${info.hospitals[i].distanceKm} km',
                            if (info.hospitals[i].open24x7) '24×7',
                          ].join(' · '),
                          icon: Icons2.emergency,
                          dense: true,
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
