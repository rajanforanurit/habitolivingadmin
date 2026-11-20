import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

/// Generate the cycle's maintenance invoices.
///
/// Two choices, both required: the period (`2026-11`) and which charge to bill.
/// Flat selection is left empty on purpose — the backend bills every occupied
/// flat by default, and a screen that asks you to tick 400 flats is a screen
/// nobody finishes.
class GenerateInvoicesScreen extends StatefulWidget {
  const GenerateInvoicesScreen({super.key});

  @override
  State<GenerateInvoicesScreen> createState() => _GenerateInvoicesScreenState();
}

class _GenerateInvoicesScreenState extends State<GenerateInvoicesScreen> {
  late Future<PageResult<Charge>> _charges;
  String? _chargeId;
  String _period = _currentPeriod();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _result;

  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _charges = AppServices.instance.admin.charges();
  }

  Future<void> _generate() async {
    if (_chargeId == null) {
      setState(() => _error = 'Pick a charge first.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Generate invoices for $_period?',
      message:
          'Every occupied flat is billed. Invoices that already exist for this '
          'period are skipped, so this is safe to run twice.',
      confirmLabel: 'Generate',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AppServices.instance.admin.generateInvoices(
        period: _period,
        chargeId: _chargeId,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Generate invoices',
      subtitle: 'Bill every occupied flat for a period',
      body: ListView(
        padding: EdgeInsets.only(bottom: Tokens.space8),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Text(
              'Period',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
          ),
          SizedBox(height: Tokens.space2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: _PeriodField(
              value: _period,
              onChanged: (v) => setState(() => _period = v),
            ),
          ),

          SizedBox(height: Tokens.space6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Text(
              'Charge to bill',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
          ),
          SizedBox(height: Tokens.space3),
          _Charges(
            future: _charges,
            selected: _chargeId,
            onSelected: (id) => setState(() => _chargeId = id),
          ),

          if (_result != null) ...[
            const SizedBox(height: Tokens.space6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _DoneCard(result: _result!),
            ),
          ],

          if (_error != null) ...[
            SizedBox(height: Tokens.space4),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Container(
                padding: EdgeInsets.all(Tokens.space3),
                decoration: BoxDecoration(
                  color: Tokens.dangerTint,
                  borderRadius: BorderRadius.circular(Tokens.radiusSm),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    color: Tokens.danger,
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: Tokens.space6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: FilledButton(
              onPressed: _busy ? null : _generate,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.accent,
                minimumSize: const Size.fromHeight(Tokens.controlHeight),
              ),
              child: _busy
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Tokens.accentOn,
                      ),
                    )
                  : const Text('Generate invoices'),
            ),
          ),
          SizedBox(height: Tokens.space3),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space5),
            child: Text(
              'Only occupied flats are billed. A flat with no resident is skipped, '
              'and an invoice that already exists for the period is left alone.',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                height: 1.5,
                color: Tokens.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodField extends StatelessWidget {
  const _PeriodField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      radius: 10,
      onTap: () async {
        final now = DateTime.now();
        final current = DateTime.tryParse('$value-01') ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(now.year - 2),
          lastDate: now,
          helpText: 'Pick any day in the billing month',
        );
        if (picked == null) return;
        onChanged('${picked.year}-${picked.month.toString().padLeft(2, '0')}');
      },
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
          children: [
            AppIcon(
              Icons2.calendar,
              size: IconSize.row,
              color: Tokens.inkMuted,
            ),
            SizedBox(width: Tokens.space2),
            Expanded(
              child: Text(
                Fmt.monthYear(DateTime.parse('$value-01')),
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  color: Tokens.ink,
                ),
              ),
            ),
            AppIcon(Icons2.expand, size: IconSize.row, color: Tokens.inkFaint),
          ],
        ),
      ),
    );
  }
}

class _Charges extends StatelessWidget {
  const _Charges({
    required this.future,
    required this.selected,
    required this.onSelected,
  });

  final Future<PageResult<Charge>> future;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PageResult<Charge>>(
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
        final charges = snapshot.data?.items ?? const <Charge>[];
        if (charges.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.finance,
                title: 'No charges configured',
                message:
                    'This society has no charges set up yet, so there is '
                    'nothing to invoice.',
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              children: [
                for (var i = 0; i < charges.length; i++) ...[
                  if (i > 0) const Hairline(indent: Tokens.space3),
                  _ChargeRow(
                    charge: charges[i],
                    selected: charges[i].id == selected,
                    onTap: () => onSelected(charges[i].id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChargeRow extends StatelessWidget {
  const _ChargeRow({
    required this.charge,
    required this.selected,
    required this.onTap,
  });

  final Charge charge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: charge.name,
      subtitle: '${charge.type} · ${charge.frequency}',
      dense: true,
      leading: Icon(
        selected ? Icons2.success : Icons2.expand,
        size: IconSize.row,
        color: selected ? Tokens.accent : Tokens.lineStrong,
      ),
      trailing: Text(
        Fmt.money(charge.amount),
        style: TextStyle(
          fontFamily: Tokens.fontFamilyFigure,
          fontSize: Tokens.typeSm,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      onTap: onTap,
      showChevron: false,
    );
  }
}

class _DoneCard extends StatelessWidget {
  const _DoneCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final created = result['created'] ?? result['count'] ?? result['total'];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.positiveTint,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
        border: Border.all(color: Tokens.positive.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          AppIcon(Icons2.success, size: IconSize.row, color: Tokens.positive),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              created == null
                  ? 'Invoices generated.'
                  : '$created invoices generated. Residents will see them in '
                        'Payments straight away.',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                height: 1.4,
                color: Tokens.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
