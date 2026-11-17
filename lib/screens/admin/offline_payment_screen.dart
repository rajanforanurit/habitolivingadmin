import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/json.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Record a payment that arrived outside the app — cash at the counter, a
/// cheque, a bank transfer.
///
/// The resident cannot see these, so the admin has to type them in. That is
/// why the screen is one invoice, one method, one amount: nothing clever, and
/// the amount is pre-filled from the invoice so a typo is visible immediately.
class OfflinePaymentScreen extends StatefulWidget {
  const OfflinePaymentScreen({super.key});

  @override
  State<OfflinePaymentScreen> createState() => _OfflinePaymentScreenState();
}

class _OfflinePaymentScreenState extends State<OfflinePaymentScreen> {
  final _form = GlobalKey<FormState>();
  late Future<PageResult<Invoice>> _invoices;
  Invoice? _invoice;
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _note = TextEditingController();

  String _method = 'CASH';
  DateTime _paidAt = DateTime.now();
  bool _busy = false;
  String? _error;
  bool _done = false;

  static final _methods = <(String, String, IconData)>[
    ('CASH', 'Cash', Icons2.payments),
    ('CHEQUE', 'Cheque', Icons2.file),
    ('BANK_TRANSFER', 'Bank transfer', Icons2.finance),
    ('UPI', 'UPI', Icons2.chat),
  ];

  @override
  void initState() {
    super.initState();
    _invoices = AppServices.instance.admin.invoices(
      status: 'UNPAID',
      limit: 50,
    );
  }

  void _pick(Invoice invoice) {
    setState(() {
      _invoice = invoice;
      _amount.text = invoice.balance.toStringAsFixed(0);
    });
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_invoice == null) {
      setState(() => _error = 'Pick an invoice first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.recordOfflinePayment(
        invoiceId: _invoice!.id,
        method: _method,
        amount: double.tryParse(_amount.text.trim()) ?? 0,
        paidAt: _paidAt,
        reference: _reference.text.trim().isEmpty
            ? null
            : _reference.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done = true;
      });
      showMessage(context, 'Recorded. The resident will see it as paid.');
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
    if (_done) {
      return AppScaffold(
        title: 'Recorded',
        subtitle: 'Payment added to the invoice',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(Tokens.space4),
              decoration: BoxDecoration(
                color: Tokens.positiveTint,
                borderRadius: BorderRadius.circular(Tokens.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AppIcon(
                        Icons2.success,
                        size: IconSize.row,
                        color: Tokens.positive,
                      ),
                      SizedBox(width: Tokens.space2),
                      Text(
                        'Payment recorded',
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeSm,
                          fontWeight: FontWeight.w600,
                          color: Tokens.positive,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Tokens.space2),
                  Text(
                    '${Fmt.money(double.tryParse(_amount.text) ?? 0)} against '
                    '${_invoice?.number ?? 'the invoice'}.',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      height: 1.4,
                      color: Tokens.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Tokens.space5),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.accent,
                minimumSize: const Size.fromHeight(Tokens.controlHeight),
              ),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      title: 'Record a payment',
      subtitle: 'Cash, cheque or transfer',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Invoice',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeSm,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
            ),
            SizedBox(height: Tokens.space3),
            _InvoicePicker(
              future: _invoices,
              selected: _invoice,
              onPick: _pick,
            ),

            if (_invoice != null) ...[
              SizedBox(height: Tokens.space6),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: Text(
                  'How it arrived',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    fontWeight: FontWeight.w600,
                    color: Tokens.ink,
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: Wrap(
                  spacing: Tokens.space2,
                  runSpacing: Tokens.space2,
                  children: [
                    for (final (value, label, icon) in _methods)
                      _Choice(
                        label: label,
                        icon: icon,
                        selected: value == _method,
                        onTap: () => setState(() => _method = value),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: Tokens.space5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) return 'Enter the amount received';
                    if (n > _invoice!.balance + 0.01) {
                      return 'That is more than the ₹${Fmt.amount(_invoice!.balance)} '
                          'still due';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Amount received',
                    prefixText: '₹ ',
                  ),
                ),
              ),

              const SizedBox(height: Tokens.space4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: TextFormField(
                  controller: _reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference (optional)',
                    helperText: 'Cheque number, UTR, or receipt number',
                    prefixIcon: AppIcon(Icons2.file, size: IconSize.inline),
                  ),
                ),
              ),
              const SizedBox(height: Tokens.space3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
              ),

              const SizedBox(height: Tokens.space5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: ListRow(
                  title: Fmt.dateFull(_paidAt),
                  subtitle: 'Received on',
                  leading: const AppIcon(Icons2.calendar, size: IconSize.row),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _paidAt,
                      firstDate: DateTime(now.year - 3),
                      lastDate: now,
                    );
                    if (picked != null) setState(() => _paidAt = picked);
                  },
                ),
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
                onPressed: _busy ? null : _submit,
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
                    : const Text('Record payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoicePicker extends StatelessWidget {
  const _InvoicePicker({
    required this.future,
    required this.selected,
    required this.onPick,
  });

  final Future<PageResult<Invoice>> future;
  final Invoice? selected;
  final ValueChanged<Invoice> onPick;

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
        final invoices = snapshot.data?.items ?? const <Invoice>[];
        if (invoices.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Panel(
              child: EmptyState(
                compact: true,
                icon: Icons2.success,
                title: 'Nothing unpaid',
                message:
                    'Every invoice is settled. Generate new invoices for the '
                    'cycle first.',
              ),
            ),
          );
        }
        return SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            children: [
              for (final invoice in invoices)
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.space2),
                  child: _InvoiceCard(
                    invoice: invoice,
                    selected: invoice.id == selected?.id,
                    onTap: () => onPick(invoice),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.selected,
    required this.onTap,
  });

  final Invoice invoice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 10,
        child: Container(
          width: 168,
          padding: EdgeInsets.all(Tokens.space3),
          decoration: BoxDecoration(
            color: selected ? Tokens.accentTint : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                invoice.number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              Text(
                Fmt.money(invoice.balance),
                style: TextStyle(
                  fontFamily: Tokens.fontFamilyFigure,
                  fontSize: Tokens.typeBase,
                  fontWeight: FontWeight.w600,
                  color: Tokens.ink,
                ),
              ),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      invoice.flatLabel ?? invoice.chargeType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        color: Tokens.inkFaint,
                      ),
                    ),
                  ),
                  const SizedBox(width: Tokens.space1),
                  StatusBadge.forStatus(
                    invoice.status.name,
                    domain: StatusDomain.invoice,
                    dot: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space3,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: selected ? Tokens.accent : Tokens.surface,
            borderRadius: BorderRadius.circular(Tokens.radiusFull),
            border: Border.all(
              color: selected ? Tokens.accent : Tokens.lineStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(
                icon,
                size: IconSize.inline,
                color: selected ? Tokens.accentOn : Tokens.inkMuted,
              ),
              const SizedBox(width: Tokens.space1),
              Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  fontWeight: FontWeight.w600,
                  color: selected ? Tokens.accentOn : Tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
