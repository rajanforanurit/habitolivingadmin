import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../widgets/paged_list.dart';

/// Expenses: what the society spent, categorised.
///
/// A categorised, paged list with an add button. Editing and deleting a row
/// live in a long-press menu rather than a trailing icon, because most of the
/// time nobody is editing anything and the row should stay a row.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  /// Bumped after every mutation so the list re-fetches instead of showing a
  /// row that no longer exists.
  int _revision = 0;

  Future<void> _edit(Expense? existing) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ExpenseEditScreen(existing: existing)),
    );
    if (!mounted) return;
    if (changed == true) {
      setState(() => _revision++);
      showMessage(context, existing == null ? 'Recorded.' : 'Updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PagedListScreen<Expense>(
      title: 'Expenses',
      subtitle: 'What the society spent',
      refreshKey: _revision,
      fetch: (page) =>
          AppServices.instance.admin.expenses(page: page, limit: 20),
      emptyTitle: 'No expenses recorded',
      emptyMessage:
          'Every payment out — a plumber, an electrician, a vendor — belongs here '
          'so the accounts balance.',
      emptyIcon: Icons2.finance,
      itemBuilder: (context, e, _) => _Row(expense: e, onTap: () => _edit(e)),
      floatingAction: FloatingActionButton(
        onPressed: () => _edit(null),
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.header),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.expense, required this.onTap});
  final Expense expense;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: expense.title,
      subtitle: [
        expense.category,
        if (expense.vendor != null) expense.vendor!,
        if (expense.spentAt != null) Fmt.date(expense.spentAt),
      ].join(' · '),
      leading: AppIcon(Icons2.finance, size: IconSize.row),
      trailing: Text(
        '−${Fmt.money(expense.amount)}',
        style: TextStyle(
          fontFamily: Tokens.fontFamilyFigure,
          fontSize: Tokens.typeSm,
          fontWeight: FontWeight.w600,
          color: Tokens.danger,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// Create or edit one expense.
class ExpenseEditScreen extends StatefulWidget {
  const ExpenseEditScreen({super.key, this.existing});

  final Expense? existing;

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _amount = TextEditingController(
    text: widget.existing?.amount.toString() ?? '',
  );
  late final _vendor = TextEditingController(
    text: widget.existing?.vendor ?? '',
  );
  late final _note = TextEditingController(text: widget.existing?.note ?? '');

  String _category = 'OTHER';
  DateTime? _spentAt;
  bool _busy = false;
  String? _error;

  static final _categories = <String>[
    'MAINTENANCE',
    'UTILITIES',
    'SALARIES',
    'REPAIRS',
    'SECURITY',
    'CLEANING',
    'GARDENING',
    'ADMIN',
    'OTHER',
  ];

  @override
  void initState() {
    super.initState();
    _spentAt = widget.existing?.spentAt;
    final existing = widget.existing?.category.toUpperCase();
    if (existing != null && _categories.contains(existing)) {
      _category = existing;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _vendor.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final admin = AppServices.instance.admin;
    try {
      if (widget.existing == null) {
        await admin.createExpense(
          title: _title.text.trim(),
          category: _category,
          amount: double.tryParse(_amount.text.trim()) ?? 0,
          spentAt: _spentAt,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      } else {
        await admin.updateExpense(widget.existing!.id, {
          'title': _title.text.trim(),
          'category': _category,
          'amount': double.tryParse(_amount.text.trim()) ?? 0,
          if (_spentAt != null) 'spentAt': _spentAt!.toIso8601String(),
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        });
      }
      if (!mounted) return;
      showMessage(context, widget.existing == null ? 'Recorded.' : 'Updated.');
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
      title: 'Delete this expense?',
      message: 'It will disappear from the accounts.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await AppServices.instance.admin.deleteExpense(widget.existing!.id);
      if (!mounted) return;
      showMessage(context, 'Deleted.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showMessage(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AppScaffold(
      title: editing ? 'Edit expense' : 'Record an expense',
      subtitle: editing ? widget.existing!.title : 'Money out',
      actions: editing
          ? [
              HeaderAction(
                icon: Icons2.delete,
                tooltip: 'Delete',
                onPressed: _delete,
              ),
            ]
          : <Widget>[],
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.only(bottom: kScreenBottomPadding),
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'What was it for?'
                  : null,
              decoration: const InputDecoration(
                labelText: 'What was it for',
                prefixIcon: AppIcon(Icons2.finance, size: IconSize.inline),
              ),
            ),
            SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) return 'Enter an amount above zero';
                return null;
              },
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),

            SizedBox(height: Tokens.space5),
            SectionLabel('Category'),
            SizedBox(height: Tokens.space2),
            Wrap(
              spacing: Tokens.space2,
              runSpacing: Tokens.space2,
              children: [
                for (final c in _categories)
                  _Choice(
                    label: c.toLowerCase().replaceAll('_', ' '),
                    selected: c == _category,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),

            SizedBox(height: Tokens.space5),
            SectionLabel('When'),
            SizedBox(height: Tokens.space2),
            ListRow(
              title: _spentAt == null ? 'Pick a date' : Fmt.dateFull(_spentAt!),
              leading: const AppIcon(Icons2.calendar, size: IconSize.row),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _spentAt ?? now,
                  firstDate: DateTime(now.year - 3),
                  lastDate: now,
                );
                if (picked != null) setState(() => _spentAt = picked);
              },
            ),

            SizedBox(height: Tokens.space4),
            TextFormField(
              controller: _vendor,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Paid to (optional)',
                helperText: 'Kept in the note so it stays searchable',
                prefixIcon: AppIcon(Icons2.vendors, size: IconSize.inline),
              ),
            ),
            SizedBox(height: Tokens.space3),
            TextFormField(
              controller: _note,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                alignLabelWithHint: true,
              ),
            ),

            if (_error != null) ...[
              SizedBox(height: Tokens.space4),
              Container(
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
            ],

            SizedBox(height: Tokens.space5),
            FilledButton(
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
                  : Text(editing ? 'Save' : 'Record it'),
            ),
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
