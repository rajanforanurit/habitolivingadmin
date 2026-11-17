import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import '../../services/notification_router.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import '../widgets/tab_host.dart';
import 'admin_more_screen.dart';
import 'gate_screen.dart';
import 'notices_screen.dart';
import '../notifications_inbox_screen.dart';

/// The admin's morning: what is true right now.
///
/// Built from the same numbers an admin would otherwise open three screens to
/// see — the money summary, the approval queue, the building counts, and any
/// open panic alerts. Each count is a link, not a decoration: tapping
/// "7 pending" opens the approvals list, because a dashboard that only reports
/// is a dashboard nobody opens twice.
class OverviewTab extends StatefulWidget {
  const OverviewTab({super.key});

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> with TabHost<OverviewTab> {
  late Future<FinanceSummary> _money;
  late Future<PageResult<ApprovalRequest>> _approvals;
  late Future<Map<String, dynamic>> _overview;
  late Future<List<EmergencyAlert>> _alerts;

  @override
  void initState() {
    super.initState();
    listenForTabRequests();
    _reload();
  }

  @override
  int get tabCount => 5;

  @override
  void onTabRequest(int index) => NotificationRouter.clearTabRequest();

  void _reload() {
    final admin = AppServices.instance.admin;
    _money = admin.financeSummary();
    _approvals = admin.approvals(status: 'SUBMITTED', limit: 3);
    _overview = admin.overview();
    _alerts = admin.alerts(status: 'ACTIVE');
  }

  Future<void> _pull() async {
    _reload();
    setState(() {});
    try {
      await Future.wait([_money, _approvals, _overview, _alerts]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppServices.instance.session;
    return AppScaffold(
      title: 'Overview',
      subtitle: session.societyName,
      onRefresh: _pull,
      actions: [
        HeaderAction(
          icon: Icons2.notifications,
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()),
          ),
        ),
        HeaderAction(
          icon: Icons2.more,
          tooltip: 'Everything else',
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AdminMoreScreen())),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _pull,
        color: Tokens.accent,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space6),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _HeroCard(
                future: _money,
                onTap: () => NotificationRouter.requestTab(2),
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Needs a decision',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            SizedBox(height: Tokens.space3),
            _Queue(future: _approvals),

            SizedBox(height: Tokens.space6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Building today',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            SizedBox(height: Tokens.space3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _Breakdown(future: _overview),
            ),

            SizedBox(height: Tokens.space6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Active alerts',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            const SizedBox(height: Tokens.space3),
            _AlertStrip(future: _alerts, onResolved: _pull),

            const SizedBox(height: Tokens.space6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _Shortcuts(
                onGate: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const GateScreen())),
                onNotices: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NoticesScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The headline: how much money came in this cycle, what is still outstanding,
/// and how much of it is collected. Tapping opens Money.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.future, required this.onTap});

  final Future<FinanceSummary> future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FinanceSummary>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Panel(child: LoadingList(rows: 3));
        }
        if (snapshot.hasError) {
          return Panel(
            child: ErrorState(compact: true, message: '${snapshot.error}'),
          );
        }
        final s = snapshot.data ?? FinanceSummary();
        return InkResponse(
          onTap: onTap,
          radius: 14,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(Tokens.space4),
            decoration: BoxDecoration(
              color: Tokens.accent,
              borderRadius: BorderRadius.circular(Tokens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COLLECTED THIS CYCLE',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: Color(0xCCFFFFFF),
                  ),
                ),
                SizedBox(height: Tokens.space1),
                Text(
                  Fmt.money(s.collected),
                  style: TextStyle(
                    fontFamily: Tokens.fontFamilyFigure,
                    fontSize: Tokens.type2Xl,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                    color: Tokens.accentOn,
                  ),
                ),
                const SizedBox(height: Tokens.space3),
                Row(
                  children: [
                    _Stat(
                      label: 'Outstanding',
                      value: Fmt.moneyCompact(s.outstanding),
                    ),
                    const SizedBox(width: Tokens.space5),
                    _Stat(label: 'Overdue', value: Fmt.moneyCompact(s.overdue)),
                    const SizedBox(width: Tokens.space5),
                    _Stat(
                      label: 'Collected',
                      value: '${s.collectionRate.toStringAsFixed(0)}%',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: Tokens.fontFamilyFigure,
            fontSize: Tokens.typeBase,
            fontWeight: FontWeight.w600,
            color: Tokens.accentOn,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeXs,
            color: Color(0xB3FFFFFF),
          ),
        ),
      ],
    );
  }
}

/// The queue of submitted approvals, three deep with a link to the full list.
class _Queue extends StatelessWidget {
  const _Queue({required this.future});
  final Future<PageResult<ApprovalRequest>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResult<ApprovalRequest>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(child: LoadingList(rows: 2)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: ErrorState(compact: true, message: '${snapshot.error}'),
            ),
          );
        }
        final items = snapshot.data?.items ?? <ApprovalRequest>[];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.success,
                title: 'Queue is clear',
                message: 'Nothing is waiting on you right now.',
              ),
            ),
          );
        }
        return Panel(
          margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Column(
            children: [
              for (var i = 0; i < items.length && i < 3; i++) ...[
                if (i > 0) const Hairline(indent: Tokens.space3),
                _Row(item: items[i]),
              ],
              Hairline(indent: Tokens.space3),
              InkResponse(
                onTap: () => NotificationRouter.requestTab(1),
                radius: 8,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: Tokens.space2),
                  child: Text(
                    'Open the queue',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      fontWeight: FontWeight.w600,
                      color: Tokens.accent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});
  final ApprovalRequest item;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: item.title ?? item.entityLabel,
      subtitle: [
        humanize(item.entityType),
        if (item.submittedBy != null) 'from ${item.submittedBy}',
        if (item.submittedAt != null) Fmt.relative(item.submittedAt),
      ].join(' · '),
      leading: const AppIcon(Icons2.approvals, size: IconSize.row),
      onTap: () => NotificationRouter.requestTab(1),
      showChevron: true,
    );
  }
}

/// The building's numbers, each one tappable.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.future});
  final Future<Map<String, dynamic>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Panel(child: LoadingList(rows: 2));
        }
        if (snapshot.hasError) {
          return Panel(
            child: ErrorState(compact: true, message: '${snapshot.error}'),
          );
        }
        final data = snapshot.data ?? const {};
        final tiles = <Widget>[
          _Tile(
            label: 'Flats',
            value: '${_int(data['flats']) ?? '—'}',
            icon: Icons2.flat,
            onTap: () => NotificationRouter.requestTab(3),
          ),
          _Tile(
            label: 'Occupied',
            value: '${_int(data['occupiedFlats']) ?? '—'}',
            icon: Icons2.residents,
            onTap: () => NotificationRouter.requestTab(3),
          ),
          _Tile(
            label: 'Guards',
            value: '${_int(data['guards']) ?? '—'}',
            icon: Icons2.guard,
            onTap: () => NotificationRouter.requestTab(4),
          ),
          _Tile(
            label: 'Open complaints',
            value: '${_int(data['openComplaints']) ?? '—'}',
            icon: Icons2.complaints,
            onTap: () => NotificationRouter.requestTab(4),
          ),
        ];
        return Panel(
          padding: const EdgeInsets.all(Tokens.space3),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: tiles[0]),
                  Expanded(child: tiles[1]),
                ],
              ),
              const SizedBox(height: Tokens.space2),
              Row(
                children: [
                  Expanded(child: tiles[2]),
                  Expanded(child: tiles[3]),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 10,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space3,
          ),
          child: Row(
            children: [
              AppIcon(icon, size: IconSize.row, color: Tokens.inkMuted),
              SizedBox(width: Tokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontFamily: Tokens.fontFamilyFigure,
                        fontSize: Tokens.typeLg,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        color: Tokens.inkFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Open panic alerts. A missed panic is the failure that matters most, so this
/// strip is loud and every alert can be resolved from here.
class _AlertStrip extends StatelessWidget {
  const _AlertStrip({required this.future, required this.onResolved});

  final Future<List<EmergencyAlert>> future;
  final Future<void> Function() onResolved;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EmergencyAlert>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(child: LoadingList(rows: 1)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: ErrorState(compact: true, message: '${snapshot.error}'),
            ),
          );
        }
        final alerts = snapshot.data ?? const <EmergencyAlert>[];
        if (alerts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.success,
                title: 'Nothing active',
                message: 'No panic alerts are open in the society.',
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final a in alerts)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Tokens.space2),
                  child: _AlertRow(alert: a, onChanged: onResolved),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert, required this.onChanged});

  final EmergencyAlert alert;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    final resolved =
        alert.resolvedAt != null || alert.status.toUpperCase() == 'RESOLVED';
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.dangerTint,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          AppIcon(Icons2.incidents, size: IconSize.row, color: Tokens.danger),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.type,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.danger,
                  ),
                ),
                Text(
                  [
                    if (alert.flatLabel != null) alert.flatLabel!,
                    if (alert.location != null) alert.location!,
                    if (alert.createdAt != null) Fmt.relative(alert.createdAt),
                  ].join(' · '),
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    color: Tokens.inkMuted,
                  ),
                ),
                if (alert.message != null) ...[
                  SizedBox(height: 4),
                  Text(
                    alert.message!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      height: 1.4,
                      color: Tokens.ink,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!resolved)
            TextButton(
              onPressed: () async {
                try {
                  await AppServices.instance.admin.updateAlert(
                    alert.id,
                    status: 'RESOLVED',
                  );
                  if (context.mounted) showMessage(context, 'Resolved.');
                  await onChanged();
                } catch (e) {
                  if (context.mounted) showMessage(context, '$e', error: true);
                }
              },
              child: const Text('Resolve'),
            ),
        ],
      ),
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.onGate, required this.onNotices});
  final VoidCallback onGate;
  final VoidCallback onNotices;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        children: [
          ListRow(
            title: 'Gate & visitors',
            subtitle: 'Who is in and who is expected',
            icon: Icons2.gate,
            onTap: onGate,
            showChevron: true,
          ),
          const Hairline(),
          ListRow(
            title: 'Notices',
            subtitle: 'Draft, publish, retract',
            icon: Icons2.notices,
            onTap: onNotices,
            showChevron: true,
          ),
        ],
      ),
    );
  }
}
