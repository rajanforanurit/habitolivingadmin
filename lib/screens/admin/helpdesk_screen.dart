import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';
import '../widgets/future_body.dart';
import '../widgets/validators.dart';

/// Service providers residents can call: plumbers, electricians, mechanics,
/// doctors. They are outsiders with no login; residents see name, category and
/// number in their app and call directly.
class HelpdeskScreen extends StatefulWidget {
  const HelpdeskScreen({super.key});

  @override
  State<HelpdeskScreen> createState() => _HelpdeskScreenState();
}

class _HelpdeskScreenState extends State<HelpdeskScreen> {
  String _category = '';
  int _revision = 0;
  late Future<List<CategoryCount>> _categories = AppServices.instance.ops.helpdeskCategories();

  void _refresh() => setState(() {
    _revision++;
    _categories = AppServices.instance.ops.helpdeskCategories();
  });

  Future<void> _edit([HelpdeskContact? contact]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tokens.surface,
      builder: (_) => _HelpdeskForm(contact: contact),
    );
    if (saved == true && mounted) {
      showMessage(context, contact == null ? 'Contact added. Residents can see it now.' : 'Contact updated.');
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Helpdesk',
      subtitle: 'Plumber, mechanic, doctor and more',
      fillBody: true,
      floatingAction: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        icon: const AppIcon(Icons2.add, size: IconSize.row),
        label: const Text('Add contact'),
      ),
      header: FutureBuilder<List<CategoryCount>>(
        future: _categories,
        builder: (context, snap) {
          final cats = snap.data ?? const <CategoryCount>[];
          if (cats.isEmpty) return const SizedBox.shrink();
          return FilterChips(
            options: [('', 'All'), for (final c in cats) (c.category, '${c.label} (${c.count})')],
            value: _category,
            onChanged: (v) => setState(() {
              _category = v;
              _revision++;
            }),
          );
        },
      ),
      body: PagedBody<HelpdeskContact>(
        key: ValueKey('$_category|$_revision'),
        refreshOn: const ['helpdesk:changed'],
        emptyIcon: Icons2.directory,
        emptyTitle: 'No contacts yet',
        emptyMessage: 'Add the plumbers, mechanics and doctors your residents rely on. They see them in the resident app and can call with one tap.',
        padding: const EdgeInsets.only(bottom: 96),
        fetch: (page) => AppServices.instance.ops.helpdesk(page: page, category: _category.isEmpty ? null : _category),
        itemBuilder: (context, c, reload) => Panel(
          onTap: () => _edit(c),
          child: Row(
            children: [
              InitialsAvatar(name: c.name),
              const SizedBox(width: Tokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                    Text(
                      [c.categoryLabel, Fmt.phone(c.mobile), if (c.availability != null) c.availability!].join(' · '),
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                    ),
                  ],
                ),
              ),
              if (!c.isVisible) const StatusBadge(label: 'Hidden', tone: Tone.neutral),
              IconButton(
                tooltip: 'Remove',
                icon: AppIcon(Icons2.delete, size: IconSize.row, color: Tokens.inkFaint),
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Remove ${c.name}?',
                    message: 'Residents will no longer see this contact.',
                    confirmLabel: 'Remove',
                  );
                  if (!ok || !context.mounted) return;
                  try {
                    await AppServices.instance.ops.deleteHelpdesk(c.id);
                    if (context.mounted) showMessage(context, 'Contact removed.');
                    _refresh();
                  } catch (e) {
                    if (context.mounted) showMessage(context, friendlyError(e), error: true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpdeskForm extends StatefulWidget {
  const _HelpdeskForm({this.contact});
  final HelpdeskContact? contact;

  @override
  State<_HelpdeskForm> createState() => _HelpdeskFormState();
}

class _HelpdeskFormState extends State<_HelpdeskForm> {
  static const _standard = <String>[
    'PLUMBER', 'ELECTRICIAN', 'MECHANIC', 'DOCTOR', 'CARPENTER', 'PAINTER',
    'PEST_CONTROL', 'APPLIANCE_REPAIR', 'CLEANING', 'GAS_AGENCY', 'WATER_SUPPLIER', 'TAXI', 'OTHER',
  ];

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.contact?.name ?? '');
  late final _mobile = TextEditingController(text: widget.contact?.mobile ?? '');
  late final _alt = TextEditingController(text: widget.contact?.alternateMobile ?? '');
  late final _designation = TextEditingController(text: widget.contact?.designation ?? '');
  late final _availability = TextEditingController(text: widget.contact?.availability ?? '');
  late final _description = TextEditingController(text: widget.contact?.description ?? '');
  late final _custom = TextEditingController();
  late String _category = widget.contact?.category ?? 'PLUMBER';
  late bool _visible = widget.contact?.isVisible ?? true;
  bool _useCustom = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!_standard.contains(_category)) {
      _useCustom = true;
      _custom.text = humanizeKey(_category);
    }
  }

  static String humanizeKey(String v) =>
      v.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');

  @override
  void dispose() {
    for (final c in [_name, _mobile, _alt, _designation, _availability, _description, _custom]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final category = _useCustom ? _custom.text.trim() : _category;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ops = AppServices.instance.ops;
    try {
      if (widget.contact == null) {
        await ops.createHelpdesk(
          name: _name.text, mobile: _mobile.text, category: category,
          alternateMobile: _alt.text, designation: _designation.text,
          description: _description.text, availability: _availability.text, isVisible: _visible,
        );
      } else {
        await ops.updateHelpdesk(
          widget.contact!.id,
          name: _name.text, mobile: _mobile.text, category: category,
          alternateMobile: _alt.text, designation: _designation.text,
          description: _description.text, availability: _availability.text, isVisible: _visible,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(Tokens.space5, Tokens.space5, Tokens.space5, Tokens.space5 + inset),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.contact == null ? 'Add helpdesk contact' : 'Edit contact',
                style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeMd, fontWeight: FontWeight.w600, color: Tokens.ink),
              ),
              const SizedBox(height: Tokens.space4),
              TextFormField(controller: _name, validator: Validators.required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: Tokens.space3),
              TextFormField(controller: _mobile, validator: Validators.mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
              const SizedBox(height: Tokens.space3),
              DropdownButtonFormField<String>(
                initialValue: _useCustom ? '__custom' : _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (final c in _standard) DropdownMenuItem(value: c, child: Text(humanizeKey(c))),
                  const DropdownMenuItem(value: '__custom', child: Text('Other category…')),
                ],
                onChanged: (v) => setState(() {
                  if (v == '__custom') {
                    _useCustom = true;
                  } else {
                    _useCustom = false;
                    _category = v ?? _category;
                  }
                }),
              ),
              if (_useCustom) ...[
                const SizedBox(height: Tokens.space3),
                TextFormField(controller: _custom, validator: Validators.required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category name', hintText: 'Swimming coach')),
              ],
              const SizedBox(height: Tokens.space3),
              TextFormField(controller: _availability, decoration: const InputDecoration(labelText: 'Availability (optional)', hintText: 'Mon–Sat, 9am–7pm')),
              const SizedBox(height: Tokens.space3),
              TextFormField(controller: _designation, decoration: const InputDecoration(labelText: 'Designation (optional)')),
              const SizedBox(height: Tokens.space3),
              TextFormField(
                controller: _alt,
                keyboardType: TextInputType.phone,
                validator: (v) => (v ?? '').trim().isEmpty ? null : Validators.mobile(v),
                decoration: const InputDecoration(labelText: 'Alternate phone (optional)'),
              ),
              const SizedBox(height: Tokens.space3),
              TextFormField(controller: _description, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true)),
              const SizedBox(height: Tokens.space3),
              Row(
                children: [
                  Expanded(child: Text('Visible to residents', style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink))),
                  AppSwitch(value: _visible, onChanged: (v) => setState(() => _visible = v)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: Tokens.space3),
                Text(_error!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.danger)),
              ],
              const SizedBox(height: Tokens.space5),
              FilledButton(
                onPressed: _busy ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: Tokens.accent, foregroundColor: Tokens.accentOn, minimumSize: const Size.fromHeight(48)),
                child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
