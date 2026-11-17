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
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Charges: what the society bills for, and how it calculates it.
///
/// A charge is a rule, not an invoice — "₹4,500 per flat per month". Invoices are
/// generated from these rules, which is why a wrong charge here is a wrong bill
/// for everyone and worth getting right before generating.
class ChargesScreen extends StatefulWidget {
  const ChargesScreen({super.key});

  @override
  State<ChargesScreen> createState() => _ChargesScreenState();
}

class _ChargesScreenState extends State<ChargesScreen> {
  int _revision = 0;
  late Future<PageResult<Charge>> _charges = _load();

  Future<PageResult<Charge>> _load() =>
      AppServices.instance.admin.charges(limit: 50);

  void _reload() => setState(() {
    _charges = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Charges',
      subtitle: 'What the society bills for',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ChargeEditScreen()),
          );
          if (ok == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<PageResult<Charge>>(
        key: ValueKey(_revision),
        future: _charges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data?.items ?? const <Charge>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.finance,
              title: 'No charges yet',
              message:
                  'Add the recurring charges the society bills — maintenance, '
                  'parking, clubhouse. Invoices are generated from these.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space4,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == items.length - 1 ? 0 : Tokens.space2,
                    ),
                    child: _Card(
                      charge: items[i],
                      onTap: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ChargeEditScreen(charge: items[i]),
                          ),
                        );
                        if (ok == true) _reload();
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.charge, required this.onTap});
  final Charge charge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 14,
      child: Container(
        padding: EdgeInsets.all(Tokens.space3),
        decoration: BoxDecoration(
          color: Tokens.surface,
          borderRadius: BorderRadius.circular(Tokens.radiusMd),
          border: Border.all(color: Tokens.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    charge.name,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${charge.type} · ${charge.frequency} · ${charge.calculation}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: Tokens.space3),
            Text(
              Fmt.money(charge.amount),
              style: TextStyle(
                fontFamily: Tokens.fontFamilyFigure,
                fontSize: Tokens.typeBase,
                fontWeight: FontWeight.w600,
                color: Tokens.ink,
              ),
            ),
            const SizedBox(width: Tokens.space2),
            StatusBadge.forStatus(
              charge.active ? 'ACTIVE' : 'INACTIVE',
              domain: StatusDomain.generic,
              dot: false,
            ),
          ],
        ),
      ),
    );
  }
}

class ChargeEditScreen extends StatefulWidget {
  const ChargeEditScreen({super.key, this.charge});

  final Charge? charge;

  @override
  State<ChargeEditScreen> createState() => _ChargeEditScreenState();
}

class _ChargeEditScreenState extends State<ChargeEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _amount;

  String _type = 'MAINTENANCE';
  String _frequency = 'MONTHLY';
  String _calcMethod = 'FIXED';
  bool _active = true;
  bool _busy = false;
  String? _error;

  static final _types = <(String, String)>[
    ('MAINTENANCE', 'Maintenance'),
    ('ELECTRICITY', 'Electricity'),
    ('WATER', 'Water'),
    ('PARKING', 'Parking'),
    ('SINKING_FUND', 'Sinking fund'),
    ('AMENITY', 'Amenity'),
    ('PENALTY', 'Penalty'),
    ('OTHER', 'Other'),
  ];

  static final _frequencies = <(String, String)>[
    ('MONTHLY', 'Monthly'),
    ('QUARTERLY', 'Quarterly'),
    ('HALF_YEARLY', 'Half-yearly'),
    ('YEARLY', 'Yearly'),
    ('ONE_TIME', 'One-off'),
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.charge;
    _name = TextEditingController(text: c?.name ?? '');
    _amount = TextEditingController(
      text: c == null ? '' : c.amount.toStringAsFixed(0),
    );
    if (c != null) {
      _type = c.type.toUpperCase().replaceAll(' ', '_');
      _frequency = c.frequency.toUpperCase().replaceAll(' ', '_');
      _calcMethod = c.calculation.toUpperCase().replaceAll(' ', '_');
      _active = c.active;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'type': _type,
        'amount': double.tryParse(_amount.text.trim()) ?? 0,
        'frequency': _frequency,
        'active': _active,
      };
      final admin = AppServices.instance.admin;
      if (widget.charge == null) {
        await admin.createCharge(body);
      } else {
        await admin.updateCharge(widget.charge!.id, body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this charge?',
      message:
          'Invoices already generated keep their amount — only future generation '
          'stops using it. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.admin.deleteCharge(widget.charge!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final editing = widget.charge != null;
    return AppScaffold(
      title: editing ? 'Edit charge' : 'New charge',
      subtitle: editing ? widget.charge!.name : 'A rule the society bills by',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Name the charge'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  helperText: 'What the resident sees on their invoice',
                ),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  if (n == null || n <= 0) return 'Enter an amount';
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  helperText: 'Per flat, for the period below',
                  prefixText: '₹ ',
                ),
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Type',
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
              child: Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _types)
                    _Choice(
                      label: label,
                      selected: value == _type,
                      onTap: () => setState(() => _type = value),
                    ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'How it is calculated',
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
              child: Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  _Choice(
                    label: 'Fixed amount',
                    selected: _calcMethod == 'FIXED',
                    onTap: () => setState(() => _calcMethod = 'FIXED'),
                  ),
                  _Choice(
                    label: 'Per sq ft',
                    selected: _calcMethod == 'PER_SQFT',
                    onTap: () => setState(() => _calcMethod = 'PER_SQFT'),
                  ),
                ],
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Frequency',
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
              child: Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _frequencies)
                    _Choice(
                      label: label,
                      selected: value == _frequency,
                      onTap: () => setState(() => _frequency = value),
                    ),
                ],
              ),
            ),

            SizedBox(height: Tokens.space4),
            Panel(
              margin: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeSm,
                            fontWeight: FontWeight.w600,
                            color: Tokens.ink,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _active
                              ? 'Included when generating invoices'
                              : 'Kept for history, never billed again',
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeXs,
                            color: Tokens.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSwitch(
                    value: _active,
                    onChanged: (v) => setState(() => _active = v),
                  ),
                ],
              ),
            ),
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
                onPressed: _busy ? null : _save,
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
                    : Text(editing ? 'Save charge' : 'Create charge'),
              ),
            ),
            if (editing) ...[
              SizedBox(height: Tokens.space2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: OutlinedButton(
                  onPressed: _busy ? null : _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Tokens.danger,
                    side: BorderSide(color: Tokens.danger),
                    minimumSize: const Size.fromHeight(Tokens.controlHeight),
                  ),
                  child: const Text('Delete this charge'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Tokens.fontFamily,
              fontSize: Tokens.typeXs,
              fontWeight: FontWeight.w600,
              color: selected ? Tokens.accentOn : Tokens.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}
