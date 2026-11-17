import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// The gate from the admin's seat: who is inside, and what walked through today.
///
/// Read-only on purpose. Decisions belong to the residents and the guards; the
/// admin opens this to answer "is anyone in the tower right now?" and to see
/// whether the rules are working.
class GateScreen extends StatefulWidget {
  const GateScreen({super.key});

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  int _revision = 0;
  late Future<List<Visitor>> _inside;
  late Future<PageResult<Visitor>> _activity;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final admin = AppServices.instance.admin;
    _inside = admin.activeVisitors();
    _activity = admin.visitors(limit: 30);
  }

  Future<void> _pull() async {
    _reload();
    setState(() => _revision++);
    try {
      await Future.wait([_inside, _activity]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gate & visitors',
      subtitle: 'Who is in and what walked through',
      onRefresh: _pull,
      body: RefreshIndicator(
        key: ValueKey(_revision),
        onRefresh: _pull,
        color: Tokens.accent,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          children: [
            const SectionLabel('Inside right now'),
            const SizedBox(height: Tokens.space2),
            _Inside(future: _inside),

            const SizedBox(height: Tokens.space6),
            const SectionLabel('Recent movement'),
            const SizedBox(height: Tokens.space2),
            _Activity(future: _activity),
          ],
        ),
      ),
    );
  }
}

class _Inside extends StatelessWidget {
  const _Inside({required this.future});
  final Future<List<Visitor>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Visitor>>(
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
        final inside = snapshot.data ?? const <Visitor>[];
        if (inside.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.gate,
                title: 'Nobody inside',
                message:
                    'No unaccounted visitors are in the society right now.',
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              children: [
                for (var i = 0; i < inside.length; i++) ...[
                  if (i > 0) const Hairline(indent: Tokens.space3),
                  _Row(visitor: inside[i], inside: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Activity extends StatelessWidget {
  const _Activity({required this.future});
  final Future<PageResult<Visitor>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResult<Visitor>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(child: LoadingList(rows: 4)),
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
        final items = snapshot.data?.items ?? const <Visitor>[];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.visitors,
                title: 'No visitor records yet',
                message: 'Once the gate sees traffic, it shows up here.',
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Hairline(indent: Tokens.space3),
                  _Row(visitor: items[i], inside: false),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.visitor, required this.inside});

  final Visitor visitor;
  final bool inside;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: visitor.name,
      subtitle: [
        visitor.type,
        if (visitor.purpose != null && visitor.purpose!.isNotEmpty)
          visitor.purpose!,
        if (visitor.flatLabel != null) visitor.flatLabel!,
        if (visitor.checkedInAt != null) Fmt.dateTime(visitor.checkedInAt),
      ].join(' · '),
      leading: AppIcon(
        inside ? Icons2.gate : Icons2.visitors,
        size: IconSize.row,
        color: inside ? Tokens.warning : Tokens.inkMuted,
      ),
      trailing: StatusBadge.forStatus(
        visitor.status.name,
        domain: StatusDomain.visitor,
        dot: false,
      ),
      dense: true,
    );
  }
}
