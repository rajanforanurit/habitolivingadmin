import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/resident.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';

/// The society's emergency numbers, shown to residents and guards.
///
/// When the lift is jammed at 11 PM nobody wants to search for a number.
/// Keep the list short and current — police, fire, hospital, gate, manager.
/// The resident app shows exactly what is configured here.
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  int _revision = 0;
  late Future<List<EmergencyContact>> _contacts = _load();

  Future<List<EmergencyContact>> _load() =>
      AppServices.instance.admin.emergencyContacts();

  void _reload() => setState(() {
    _contacts = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Emergency contacts',
      subtitle: 'Numbers residents and guards see',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => const _ContactDialog(),
          );
          if (ok == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<List<EmergencyContact>>(
        key: ValueKey(_revision),
        future: _contacts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data ?? const <EmergencyContact>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.emergency,
              title: 'No contacts yet',
              message:
                  'Add the numbers residents should dial in an emergency — '
                  'police, fire, hospital, the gate, the manager.',
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
                    child: _Card(contact: items[i], onChanged: _reload),
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
  const _Card({required this.contact, required this.onChanged});

  final EmergencyContact contact;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListRow(
      title: contact.name,
      subtitle: [
        contact.category,
        contact.phone ?? 'no number',
        if (contact.available24x7) '24×7',
      ].join(' · '),
      icon: Icons2.emergency,
      showChevron: false,
      dense: true,
      trailing: IconButton(
        tooltip: 'Remove',
        icon: AppIcon(
          Icons2.delete,
          size: IconSize.row,
          color: Tokens.inkFaint,
        ),
        onPressed: () async {
          final ok = await confirmDialog(
            context,
            title: 'Remove ${contact.name}?',
            message: 'Residents and guards will no longer see this number.',
            confirmLabel: 'Remove',
            destructive: true,
          );
          if (!ok || !context.mounted) return;
          try {
            await AppServices.instance.admin.deleteEmergencyContact(contact.id);
            if (context.mounted) showMessage(context, 'Contact removed.');
            onChanged();
          } catch (e) {
            if (context.mounted) showMessage(context, '$e', error: true);
          }
        },
      ),
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();

  static final _categories = <(String, String)>[
    ('POLICE', 'Police'),
    ('FIRE', 'Fire'),
    ('HOSPITAL', 'Hospital'),
    ('AMBULANCE', 'Ambulance'),
    ('GATE', 'Gate'),
    ('MANAGER', 'Society manager'),
    ('SECURITY', 'Security'),
    ('OTHER', 'Other'),
  ];

  String _category = 'POLICE';
  bool _available24x7 = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text('New emergency contact'),
      content: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'MG Road Police Station',
                ),
              ),
              SizedBox(height: Tokens.space3),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: '100',
                ),
              ),
              SizedBox(height: Tokens.space3),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _categories)
                    ChoiceChip(
                      label: Text(label),
                      selected: value == _category,
                      selectedColor: Tokens.accentTint,
                      checkmarkColor: Tokens.accent,
                      onSelected: (_) => setState(() => _category = value),
                    ),
                ],
              ),
              SizedBox(height: Tokens.space3),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Available 24×7',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        color: Tokens.ink,
                      ),
                    ),
                  ),
                  AppSwitch(
                    value: _available24x7,
                    onChanged: (v) => setState(() => _available24x7 = v),
                  ),
                ],
              ),
              SizedBox(height: Tokens.space2),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: Tokens.space3),
                Text(
                  _error!,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    color: Tokens.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: _busy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Name and phone are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.createEmergencyContact(
        name: name,
        category: _category,
        phone: phone,
        available24x7: _available24x7,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
      );
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
}
