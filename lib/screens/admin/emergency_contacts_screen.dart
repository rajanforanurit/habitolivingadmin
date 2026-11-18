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

/// The society's emergency numbers.
///
/// The backend is the single source of truth: what is saved here is what the
/// resident and guard apps list, and they update live. Each number can be shown
/// to residents, guards or both, and categories can be your own.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  int _revision = 0;

  Future<void> _edit([ManagedEmergencyContact? contact]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Tokens.surface,
      builder: (_) => _ContactForm(contact: contact),
    );
    if (saved == true && mounted) {
      showMessage(context, 'Saved. Residents and guards see the change now.');
      setState(() => _revision++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Emergency contacts',
      subtitle: 'Numbers residents and guards see',
      fillBody: true,
      floatingAction: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        icon: const AppIcon(Icons2.add, size: IconSize.row),
        label: const Text('Add number'),
      ),
      body: FutureBody<List<ManagedEmergencyContact>>(
        key: ValueKey(_revision),
        refreshOn: const ['emergency:contacts-changed'],
        load: AppServices.instance.ops.managedContacts,
        emptyIcon: Icons2.emergency,
        emptyTitle: 'No contacts yet',
        emptyMessage: 'Add the numbers people should dial in an emergency: police, fire, ambulance, the gate, the manager.',
        builder: (context, items, reload) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
          itemBuilder: (context, i) {
            final c = items[i];
            return Panel(
              onTap: () => _edit(c),
              child: Row(
                children: [
                  AppIcon(Icons2.emergency, size: IconSize.header, color: Tokens.accent),
                  const SizedBox(width: Tokens.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                        Text(
                          '${c.categoryLabel} · ${Fmt.phone(c.phone)}',
                          style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted),
                        ),
                        const SizedBox(height: Tokens.space1),
                        Wrap(
                          spacing: Tokens.space1,
                          children: [
                            MetaTag(c.visibleToResidents ? 'Residents' : 'Hidden from residents'),
                            MetaTag(c.visibleToGuards ? 'Guards' : 'Hidden from guards'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: AppIcon(Icons2.delete, size: IconSize.row, color: Tokens.inkFaint),
                    onPressed: () async {
                      final ok = await confirmDialog(
                        context,
                        title: 'Remove ${c.name}?',
                        message: 'Residents and guards will no longer see this number.',
                        confirmLabel: 'Remove',
                      );
                      if (!ok || !context.mounted) return;
                      try {
                        await AppServices.instance.ops.deleteContact(c.id);
                        if (context.mounted) showMessage(context, 'Contact removed.');
                        await reload();
                      } catch (e) {
                        if (context.mounted) showMessage(context, friendlyError(e), error: true);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({this.contact});
  final ManagedEmergencyContact? contact;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  static const _standard = <String>['POLICE', 'FIRE', 'HOSPITAL', 'AMBULANCE', 'GATE', 'MANAGER', 'SECURITY', 'OTHER'];

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.contact?.name ?? '');
  late final _phone = TextEditingController(text: widget.contact?.phone ?? '');
  late final _notes = TextEditingController(text: widget.contact?.notes ?? '');
  final _custom = TextEditingController();
  late String _category = widget.contact?.category ?? 'POLICE';
  late bool _residents = widget.contact?.visibleToResidents ?? true;
  late bool _guards = widget.contact?.visibleToGuards ?? true;
  bool _custom_ = false;
  bool _busy = false;
  String? _error;
  late Future<List<CategoryCount>> _used = AppServices.instance.ops.contactCategories();

  static String _label(String v) =>
      v.split('_').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');

  @override
  void initState() {
    super.initState();
    if (!_standard.contains(_category)) {
      _custom_ = true;
      _custom.text = _label(_category);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.ops.saveContact(
        id: widget.contact?.id,
        name: _name.text,
        phone: _phone.text,
        category: _custom_ ? _custom.text : _category,
        notes: _notes.text,
        visibleToResidents: _residents,
        visibleToGuards: _guards,
      );
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
                widget.contact == null ? 'New emergency contact' : 'Edit contact',
                style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeMd, fontWeight: FontWeight.w600, color: Tokens.ink),
              ),
              const SizedBox(height: Tokens.space4),
              TextFormField(controller: _name, validator: Validators.required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name', hintText: 'MG Road Police Station')),
              const SizedBox(height: Tokens.space3),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                validator: (v) => (v ?? '').trim().length < 3 ? 'Enter a number' : null,
                decoration: const InputDecoration(labelText: 'Phone', hintText: '100'),
              ),
              const SizedBox(height: Tokens.space3),
              FutureBuilder<List<CategoryCount>>(
                future: _used,
                builder: (context, snap) {
                  final extra = [
                    for (final c in snap.data ?? const <CategoryCount>[])
                      if (!_standard.contains(c.category)) c.category,
                  ];
                  final all = [..._standard, ...extra];
                  final current = _custom_ ? '__custom' : _category;
                  return DropdownButtonFormField<String>(
                    initialValue: all.contains(current) || current == '__custom' ? current : null,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final c in all) DropdownMenuItem(value: c, child: Text(_label(c))),
                      const DropdownMenuItem(value: '__custom', child: Text('New category…')),
                    ],
                    onChanged: (v) => setState(() {
                      if (v == '__custom') {
                        _custom_ = true;
                      } else {
                        _custom_ = false;
                        _category = v ?? _category;
                      }
                    }),
                  );
                },
              ),
              if (_custom_) ...[
                const SizedBox(height: Tokens.space3),
                TextFormField(controller: _custom, validator: Validators.required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category name', hintText: 'Blood bank')),
              ],
              const SizedBox(height: Tokens.space3),
              TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)', alignLabelWithHint: true)),
              const SizedBox(height: Tokens.space4),
              Row(
                children: [
                  Expanded(child: Text('Show to residents', style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink))),
                  AppSwitch(value: _residents, onChanged: (v) => setState(() => _residents = v)),
                ],
              ),
              const SizedBox(height: Tokens.space2),
              Row(
                children: [
                  Expanded(child: Text('Show to guards', style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink))),
                  AppSwitch(value: _guards, onChanged: (v) => setState(() => _guards = v)),
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
