import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/future_body.dart';

/// Authentication activity for this society only.
///
/// Shows who signed in, who failed and why, and authorisation errors (401,
/// 403, 429) for this society's users. It is intentionally not a server log:
/// no stack traces, no infrastructure errors, no other society's data. The
/// backend filters by the admin's society and masks identifiers.
class PlatformMonitorScreen extends StatefulWidget {
  const PlatformMonitorScreen({super.key});

  @override
  State<PlatformMonitorScreen> createState() => _PlatformMonitorScreenState();
}

class _PlatformMonitorScreenState extends State<PlatformMonitorScreen> {
  String _view = 'overview';
  int _days = 7;
  String _loginFilter = '';
  String _errorFilter = '';

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Platform',
      subtitle: 'Sign-ins and access errors in your society',
      fillBody: true,
      header: FilterChips(
        options: const [('overview', 'Overview'), ('logins', 'Sign-ins'), ('errors', 'Access errors')],
        value: _view,
        onChanged: (v) => setState(() => _view = v),
      ),
      body: switch (_view) {
        'logins' => _logins(),
        'errors' => _errors(),
        _ => _overview(),
      },
    );
  }

  // ------------------------------------------------------------- overview

  Widget _overview() {
    return FutureBody<AuthSummary>(
      key: ValueKey('overview-$_days'),
      load: () => AppServices.instance.ops.platformSummary(days: _days),
      builder: (context, s, reload) {
        final total = s.successful + s.failed;
        final failRate = total == 0 ? 0 : (s.failed * 100 / total).round();
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          children: [
            FilterChips(
              options: const [('1', 'Today'), ('7', '7 days'), ('30', '30 days')],
              value: '$_days',
              onChanged: (v) => setState(() => _days = int.parse(v)),
            ),
            const SizedBox(height: Tokens.space3),
            Row(
              children: [
                Expanded(child: MetricTile(label: 'Successful sign-ins', value: '${s.successful}', tone: Tokens.positive, hint: '${s.distinctUsers} people')),
                const SizedBox(width: Tokens.space3),
                Expanded(child: MetricTile(label: 'Failed sign-ins', value: '${s.failed}', tone: s.failed > 0 ? Tokens.warning : null, hint: '$failRate% of attempts')),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            Row(
              children: [
                Expanded(child: MetricTile(label: 'Unauthorised', value: '${s.unauthorized}', hint: '401')),
                const SizedBox(width: Tokens.space3),
                Expanded(child: MetricTile(label: 'Forbidden', value: '${s.forbidden}', hint: '403')),
                const SizedBox(width: Tokens.space3),
                Expanded(child: MetricTile(label: 'Rate limited', value: '${s.rateLimited}', hint: '429')),
              ],
            ),
            if (s.byDay.isNotEmpty) ...[
              const SizedBox(height: Tokens.space6),
              const SectionLabel('Sign-ins by day'),
              const SizedBox(height: Tokens.space2),
              Panel(child: _DayBars(rows: s.byDay)),
            ],
            const SizedBox(height: Tokens.space6),
            const SectionLabel('Needs attention'),
            const SizedBox(height: Tokens.space2),
            if (s.suspicious.isEmpty)
              Panel(child: Text('Nothing suspicious in this period.', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)))
            else
              Panel(
                child: Column(
                  children: [
                    for (var i = 0; i < s.suspicious.length; i++) ...[
                      if (i > 0) const Hairline(),
                      ListRow(
                        title: humanize(asString(s.suspicious[i]['type'], fallback: 'Activity')),
                        subtitle: '${asString(s.suspicious[i]['key'])} · ${asInt(s.suspicious[i]['count'])} times · ${Fmt.relative(asDateOrNull(s.suspicious[i]['lastSeenAt']))}',
                        icon: Icons2.warning,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // --------------------------------------------------------------- logins

  Widget _logins() {
    return Column(
      children: [
        FilterChips(
          options: const [('', 'All'), ('true', 'Successful'), ('false', 'Failed')],
          value: _loginFilter,
          onChanged: (v) => setState(() => _loginFilter = v),
        ),
        const SizedBox(height: Tokens.space2),
        Expanded(
          child: PagedBody<LoginActivity>(
            key: ValueKey('logins-$_loginFilter'),
            emptyIcon: Icons2.security,
            emptyTitle: 'No sign-ins recorded',
            fetch: (page) => AppServices.instance.ops.loginActivity(
              page: page,
              success: _loginFilter.isEmpty ? null : _loginFilter == 'true',
            ),
            itemBuilder: (context, a, _) => Panel(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(a.success ? Icons2.success : Icons2.warning, size: IconSize.row, color: a.success ? Tokens.positive : Tokens.warning),
                  const SizedBox(width: Tokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.userName ?? a.identifier,
                          style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink),
                        ),
                        Text(
                          [
                            if (a.userName != null) a.identifier,
                            if (!a.success && a.reason != null) humanize(a.reason!),
                            if (a.method != null) humanize(a.method!),
                          ].join(' · '),
                          style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                        ),
                        Text(
                          [Fmt.dateTime(a.createdAt), if (a.ip != null) a.ip!].join(' · '),
                          style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkFaint),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(label: a.success ? 'Success' : 'Failed', tone: a.success ? Tone.positive : Tone.warning),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------- errors

  Widget _errors() {
    return Column(
      children: [
        FilterChips(
          options: const [('', 'All'), ('401', 'Unauthorised'), ('403', 'Forbidden'), ('429', 'Rate limited')],
          value: _errorFilter,
          onChanged: (v) => setState(() => _errorFilter = v),
        ),
        const SizedBox(height: Tokens.space2),
        Expanded(
          child: PagedBody<AuthEvent>(
            key: ValueKey('errors-$_errorFilter'),
            emptyIcon: Icons2.security,
            emptyTitle: 'No access errors',
            emptyMessage: 'Rejected sign-ins and blocked requests from your society show up here.',
            fetch: (page) => AppServices.instance.ops.authEvents(
              page: page,
              status: _errorFilter.isEmpty ? null : int.parse(_errorFilter),
            ),
            itemBuilder: (context, e, _) => Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.title, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink))),
                      StatusBadge(label: '${e.status}', tone: e.status == 429 ? Tone.warning : Tone.danger),
                    ],
                  ),
                  if (e.message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(e.message!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted)),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (e.userName != null) e.userName!,
                      if (e.method != null && e.path != null) '${e.method} ${e.path}',
                      Fmt.dateTime(e.createdAt),
                    ].join(' · '),
                    style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Stacked bars: successful over failed, one per day.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) {
      final t = asInt(r['successful']) + asInt(r['failed']);
      return t > m ? t : m;
    });
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final r in rows)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(height: 90 * asInt(r['failed']) / max, color: Tokens.warning),
                        Container(height: 90 * asInt(r['successful']) / max, color: Tokens.positive),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space2),
        Row(
          children: [
            for (final r in rows)
              Expanded(
                child: Text(
                  asString(r['date']).length >= 10 ? asString(r['date']).substring(8, 10) : asString(r['date']),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: 10, color: Tokens.inkFaint),
                ),
              ),
          ],
        ),
        const SizedBox(height: Tokens.space2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10, height: 10, color: Tokens.positive),
            const SizedBox(width: 4),
            Text('Successful', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkMuted)),
            const SizedBox(width: Tokens.space4),
            Container(width: 10, height: 10, color: Tokens.warning),
            const SizedBox(width: 4),
            Text('Failed', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkMuted)),
          ],
        ),
      ],
    );
  }
}
