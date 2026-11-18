import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../widgets/future_body.dart';

/// The gates guards are assigned to. Gates are an operating detail the society
/// admin manages; the building itself (towers, floors, flats) is configured by
/// the platform team and is read-only here.
class GatesScreen extends StatefulWidget {
  const GatesScreen({super.key});

  @override
  State<GatesScreen> createState() => _GatesScreenState();
}

class _GatesScreenState extends State<GatesScreen> {
  int _revision = 0;

  static const _types = <(String, String)>[
    ('MAIN', 'Main'),
    ('SERVICE', 'Service'),
    ('VISITOR', 'Visitor'),
    ('DELIVERY', 'Delivery'),
    ('EMERGENCY', 'Emergency'),
  ];

  Future<void> _add() async {
    final name = TextEditingController();
    var type = 'MAIN';
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Tokens.surface,
          title: const Text('New gate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name', hintText: 'Main gate'),
              ),
              const SizedBox(height: Tokens.space4),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final (value, label) in _types)
                    ChoiceChip(
                      label: Text(label),
                      selected: value == type,
                      selectedColor: Tokens.accentTint,
                      onSelected: (_) => setLocal(() => type = value),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
              onPressed: () {
                final n = name.text.trim();
                if (n.isEmpty) {
                  showMessage(ctx, 'Give the gate a name.', error: true);
                  return;
                }
                Navigator.of(ctx).pop((n, type));
              },
              child: const Text('Add gate'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    if (result == null) return;
    try {
      await AppServices.instance.admin.createGate(name: result.$1, type: result.$2);
      if (!mounted) return;
      showMessage(context, 'Gate added.');
      setState(() => _revision++);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete(Gate gate) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${gate.name}?',
      message: 'Guards assigned to this gate keep working; only the gate record goes.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await AppServices.instance.admin.deleteGate(gate.id);
      if (!mounted) return;
      showMessage(context, 'Gate removed.');
      setState(() => _revision++);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Gates',
      subtitle: 'Where guards are posted',
      fillBody: true,
      floatingAction: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        icon: const AppIcon(Icons2.add, size: IconSize.inline),
        label: const Text('Add gate'),
      ),
      body: FutureBody<List<Gate>>(
        key: ValueKey(_revision),
        load: AppServices.instance.admin.gates,
        emptyIcon: Icons2.gate,
        emptyTitle: 'No gates yet',
        emptyMessage: 'Add the gates of your society so guards can be assigned to them.',
        builder: (context, gates, reload) => ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: Tokens.space9),
          itemCount: gates.length,
          separatorBuilder: (_, _) => const SizedBox(height: Tokens.space2),
          itemBuilder: (context, i) => Panel(
            child: ListRow(
              title: gates[i].name,
              subtitle: '${gates[i].assignedGuards} guards assigned',
              icon: Icons2.gate,
              showChevron: false,
              trailing: IconButton(
                tooltip: 'Delete',
                icon: AppIcon(Icons2.delete, size: IconSize.row, color: Tokens.inkFaint),
                onPressed: () => _delete(gates[i]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
