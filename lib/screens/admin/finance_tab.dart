import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import 'charges_screen.dart';
import 'expenses_screen.dart';
import 'generate_invoices_screen.dart';
import 'offline_payment_screen.dart';

/// Money: what came in, what is owed, what was spent.
///
/// Four facts, in the order a treasurer checks them: the summary, the invoices,
/// the payments received, and the expenses. Generating invoices and recording a
/// cash payment are actions, so they are the two buttons at the top — the rest
/// of the screen is reading.
class FinanceTab extends StatefulWidget {
  const FinanceTab({super.key});

  @override
  State<FinanceTab> createState() => _FinanceTabState();
}

class _FinanceTabState extends State<FinanceTab> {
  late Future<FinanceSummary> _summary;
  late Future<PageResult<Invoice>> _invoices;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final admin = AppServices.instance.admin;
    _summary = admin.financeSummary();
    _invoices = admin.invoices(limit: 10);
  }

  Future<void> _pull() async {
    _reload();
    setState(() {});
    try {
      await Future.wait([_summary, _invoices]);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _pull();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Money',
      subtitle: 'Cycle summary, invoices and payments',
      onRefresh: _pull,
      body: RefreshIndicator(
        onRefresh: _pull,
        color: Tokens.accent,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space6),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _Summary(future: _summary),
            ),

            SizedBox(height: Tokens.space6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: _Action(
                      label: 'Generate invoices',
                      icon: Icons2.finance,
                      onTap: () => _open(const GenerateInvoicesScreen()),
                    ),
                  ),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: _Action(
                      label: 'Record cash',
                      icon: Icons2.payments,
                      onTap: () => _open(const OfflinePaymentScreen()),
                    ),
                  ),
                  const SizedBox(width: Tokens.space2),
                  Expanded(
                    child: _Action(
                      label: 'Charges',
                      icon: Icons2.setup,
                      onTap: () => _open(const ChargesScreen()),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: Tokens.space6),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Latest invoices',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        fontWeight: FontWeight.w600,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  InkResponse(
                    radius: 16,
                    onTap: () => _open(const ExpensesScreen()),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: Tokens.space1,
                        vertical: 2,
                      ),
                      child: Text(
                        'Expenses',
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
            ),
            const SizedBox(height: Tokens.space3),
            _InvoicePanel(future: _invoices),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.future});
  final Future<FinanceSummary> future;

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
        final s = snapshot.data;
        if (s == null) {
          return const Panel(
            child: EmptyState(
              compact: true,
              icon: Icons2.finance,
              title: 'No money summary yet',
              message: 'Generate the first cycle of invoices first.',
            ),
          );
        }
        return Panel(
          child: Column(
            children: [
              _Line(
                label: 'Collected',
                value: Fmt.money(s.collected),
                strong: true,
              ),
              const Hairline(),
              _Line(label: 'Outstanding', value: Fmt.money(s.outstanding)),
              const Hairline(),
              _Line(
                label: 'Overdue invoices',
                value: '${s.overdueInvoiceCount}',
              ),
              const Hairline(),
              _Line(
                label: 'Collection rate',
                value: s.collected <= 0 && s.collectionRate <= 0
                    ? '\u2014'
                    : '${s.collectionRate.toStringAsFixed(0)}%',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.space4,
        vertical: Tokens.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: strong ? Tokens.ink : Tokens.inkMuted,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: Tokens.fontFamilyFigure,
              fontSize: strong ? Tokens.typeLg : Tokens.typeBase,
              fontWeight: FontWeight.w600,
              color: Tokens.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 10,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: Tokens.space3,
          ),
          decoration: BoxDecoration(
            color: Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(color: Tokens.lineStrong),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: IconSize.row, color: Tokens.accent),
              SizedBox(width: Tokens.space2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoicePanel extends StatelessWidget {
  const _InvoicePanel({required this.future});
  final Future<PageResult<Invoice>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResult<Invoice>>(
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
        final items = snapshot.data?.items ?? const <Invoice>[];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.invoices,
                title: 'No invoices yet',
                message: 'Set up charges, then generate the cycle\'s invoices.',
              ),
            ),
          );
        }
        return Panel(
          margin: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Hairline(indent: Tokens.space4),
                _Row(invoice: items[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: invoice.number,
      subtitle: [
        if (invoice.flatLabel != null) invoice.flatLabel!,
        if (invoice.dueDate != null) 'due ${Fmt.date(invoice.dueDate)}',
      ].join(' · '),
      leading: AppIcon(Icons2.invoices, size: IconSize.row),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            Fmt.money(invoice.amount),
            style: TextStyle(
              fontFamily: Tokens.fontFamilyFigure,
              fontSize: Tokens.typeSm,
              fontWeight: FontWeight.w600,
              color: Tokens.ink,
            ),
          ),
          const SizedBox(height: 2),
          StatusBadge.forStatus(
            invoice.status.name,
            domain: StatusDomain.invoice,
            dot: false,
          ),
        ],
      ),
    );
  }
}
