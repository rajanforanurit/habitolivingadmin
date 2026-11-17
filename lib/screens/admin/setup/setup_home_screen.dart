import 'package:flutter/material.dart';

import '../../../app.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/society.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// The physical building: what towers exist, how they are numbered, where the
/// gates are, what the society is called.
///
/// Set once when the society is onboarded, touched rarely afterwards — which is
/// exactly why it lives on one screen instead of behind six menus.
class SetupHomeScreen extends StatefulWidget {
  const SetupHomeScreen({super.key});

  @override
  State<SetupHomeScreen> createState() => _SetupHomeScreenState();
}

class _SetupHomeScreenState extends State<SetupHomeScreen> {
  late Future<List<Tower>> _towers;
  late Future<List<Gate>> _gates;
  late Future<List<Map<String, dynamic>>> _blocks;
  Map<String, dynamic>? _society;
  String? _societyError;
  bool _societyLoading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _pull() => _asyncReload();

  /// Sections await this before their own follow-up UI work, so mutating a row
  /// waits for the refresh to be kicked off.
  Future<void> _asyncReload() async {
    _reload();
  }

  void _reload() {
    final admin = AppServices.instance.admin;
    _towers = admin.towers();
    _gates = admin.gates();
    _blocks = admin.blocks();
    _societyLoading = true;
    _societyError = null;
    admin
        .society()
        .then((map) {
          if (!mounted) return;
          setState(() {
            _society = map;
            _societyLoading = false;
          });
        })
        .catchError((e) {
          if (!mounted) return;
          setState(() {
            _societyError = '$e';
            _societyLoading = false;
          });
        });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Society setup',
      subtitle: 'Towers, floors, flats, gates and blocks',
      onRefresh: _pull,
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        color: Tokens.accent,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Tokens.space8),
          children: [
            const SectionLabel('Society profile'),
            const SizedBox(height: Tokens.space2),
            _SocietyProfile(
              loading: _societyLoading,
              error: _societyError,
              society: _society,
              onEdit: (name, units) async {
                await AppServices.instance.admin.updateSociety({
                  'name': name,
                  'totalUnits': units,
                });
                _reload();
              },
            ),

            const SizedBox(height: Tokens.space6),
            const SectionLabel('Towers'),
            const SizedBox(height: Tokens.space2),
            _Towers(future: _towers, onChanged: _asyncReload),

            const SizedBox(height: Tokens.space6),
            const SectionLabel('Flats'),
            const SizedBox(height: Tokens.space2),
            _Flats(towersFuture: _towers, onChanged: _asyncReload),

            const SizedBox(height: Tokens.space6),
            const SectionLabel('Gates'),
            const SizedBox(height: Tokens.space2),
            _Gates(future: _gates, onChanged: _asyncReload),

            const SizedBox(height: Tokens.space6),
            const SectionLabel('Blocks'),
            const SizedBox(height: Tokens.space2),
            _Blocks(future: _blocks, onChanged: _asyncReload),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- society

class _SocietyProfile extends StatelessWidget {
  const _SocietyProfile({
    required this.loading,
    required this.error,
    required this.society,
    required this.onEdit,
  });

  final bool loading;
  final String? error;
  final Map<String, dynamic>? society;
  final Future<void> Function(String name, int totalUnits) onEdit;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: Panel(child: LoadingList(rows: 2)),
      );
    }
    if (error != null || society == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: Panel(
          child: ErrorState(compact: true, message: error ?? 'Could not load.'),
        ),
      );
    }
    final s = society!;
    final name = asString(s['name'], fallback: 'Unnamed society');
    final code = asStringOrNull(s['code']);
    final units = asInt(s['totalUnits']);
    final status = asStringOrNull(s['status']);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InitialsAvatar(name: 'S', size: 44),
                SizedBox(width: Tokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeBase,
                          fontWeight: FontWeight.w600,
                          color: Tokens.ink,
                        ),
                      ),
                      Text(
                        [
                          if (code != null) code,
                          if (units > 0) '$units units',
                        ].join(' · '),
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeXs,
                          color: Tokens.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status != null)
                  StatusBadge.forStatus(status, domain: StatusDomain.generic),
                SizedBox(width: Tokens.space2),
                IconButton(
                  tooltip: 'Edit',
                  icon: AppIcon(
                    Icons2.edit,
                    size: IconSize.row,
                    color: Tokens.inkMuted,
                  ),
                  onPressed: () async {
                    final result = await showDialog<(String, int)>(
                      context: context,
                      builder: (_) =>
                          _SocietyEditDialog(name: name, totalUnits: units),
                    );
                    if (result == null) return;
                    try {
                      await onEdit(result.$1, result.$2);
                      if (context.mounted) {
                        showMessage(context, 'Society updated.');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SocietyEditDialog extends StatefulWidget {
  const _SocietyEditDialog({required this.name, required this.totalUnits});

  final String name;
  final int totalUnits;

  @override
  State<_SocietyEditDialog> createState() => _SocietyEditDialogState();
}

class _SocietyEditDialogState extends State<_SocietyEditDialog> {
  late final _name = TextEditingController(text: widget.name);
  late final _units = TextEditingController(
    text: widget.totalUnits > 0 ? '${widget.totalUnits}' : '',
  );

  @override
  void dispose() {
    _name.dispose();
    _units.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'Society profile',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: _units,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Total units'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            final u = int.tryParse(_units.text.trim());
            if (n.length < 2 || u == null || u < 1) {
              showMessage(
                context,
                'Name and a unit count of at least 1 are required.',
                error: true,
              );
              return;
            }
            Navigator.of(context).pop((n, u));
          },
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- towers

class _Towers extends StatelessWidget {
  const _Towers({required this.future, required this.onChanged});

  final Future<List<Tower>> future;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tower>>(
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
        final towers = snapshot.data ?? <Tower>[];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              children: [
                for (var i = 0; i < towers.length; i++) ...[
                  if (i > 0) Hairline(),
                  ListRow(
                    title: towers[i].name,
                    subtitle:
                        '${towers[i].floors} floors · ${towers[i].flats} flats',
                    icon: Icons2.tower,
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: AppIcon(
                        Icons2.delete,
                        size: IconSize.row,
                        color: Tokens.inkFaint,
                      ),
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete ${towers[i].name}?',
                          message:
                              'Flats in this tower lose their tower link. Only an '
                              'empty tower can be removed.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (!ok) return;
                        try {
                          await AppServices.instance.admin.deleteTower(
                            towers[i].id,
                          );
                          await onChanged();
                          if (context.mounted) {
                            showMessage(context, 'Tower removed.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, '$e', error: true);
                          }
                        }
                      },
                    ),
                    showChevron: false,
                  ),
                ],
                if (towers.isNotEmpty) const Hairline(),
                _AddRow(
                  label: 'Add tower',
                  onTap: () async {
                    final result = await showDialog<(String, int)>(
                      context: context,
                      builder: (_) => const _TowerDialog(),
                    );
                    if (result == null) return;
                    try {
                      await AppServices.instance.admin.createTower(
                        name: result.$1,
                        totalFloors: result.$2,
                      );
                      await onChanged();
                      if (context.mounted) showMessage(context, 'Tower added.');
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TowerDialog extends StatefulWidget {
  const _TowerDialog();

  @override
  State<_TowerDialog> createState() => _TowerDialogState();
}

class _TowerDialogState extends State<_TowerDialog> {
  final _name = TextEditingController();
  final _floors = TextEditingController(text: '10');

  @override
  void dispose() {
    _name.dispose();
    _floors.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'New tower',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Tower A',
            ),
          ),
          const SizedBox(height: Tokens.space3),
          TextField(
            controller: _floors,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Number of floors'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            final f = int.tryParse(_floors.text.trim());
            if (n.isEmpty || f == null || f < 1) {
              showMessage(
                context,
                'Give the tower a name and at least one floor.',
                error: true,
              );
              return;
            }
            Navigator.of(context).pop((n, f));
          },
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- flats

class _Flats extends StatelessWidget {
  const _Flats({required this.towersFuture, required this.onChanged});

  final Future<List<Tower>> towersFuture;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Tower>>(
      future: towersFuture,
      builder: (context, snapshot) {
        final towers = snapshot.data ?? <Tower>[];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (towers.isEmpty)
                  Text(
                    'Add a tower first — flats live inside towers.',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      color: Tokens.inkMuted,
                    ),
                  )
                else ...[
                  _AddRow(
                    label: 'Bulk generate flats',
                    icon: Icons2.setup,
                    onTap: () async {
                      final done = await showDialog<bool>(
                        context: context,
                        builder: (_) => _BulkDialog(towers: towers),
                      );
                      if (done == true) {
                        await onChanged();
                        if (context.mounted) {
                          showMessage(context, 'Flats generated.');
                        }
                      }
                    },
                  ),
                  const Hairline(),
                  _AddRow(
                    label: 'Add a single flat',
                    onTap: () async {
                      final done = await showDialog<bool>(
                        context: context,
                        builder: (_) => _FlatDialog(towers: towers),
                      );
                      if (done == true) {
                        await onChanged();
                        if (context.mounted) {
                          showMessage(context, 'Flat added.');
                        }
                      }
                    },
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

class _BulkDialog extends StatefulWidget {
  const _BulkDialog({required this.towers});

  final List<Tower> towers;

  @override
  State<_BulkDialog> createState() => _BulkDialogState();
}

class _BulkDialogState extends State<_BulkDialog> {
  late Tower? _tower = widget.towers.isEmpty ? null : widget.towers.first;
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '10');
  final _units = TextEditingController(text: '4');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _units.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'Bulk generate flats',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Tower>(
            initialValue: _tower,
            decoration: const InputDecoration(labelText: 'Tower'),
            items: [
              for (final t in widget.towers)
                DropdownMenuItem(value: t, child: Text(t.name)),
            ],
            onChanged: (t) => setState(() => _tower = t),
          ),
          SizedBox(height: Tokens.space3),
          Row(
            children: [
              Expanded(child: _number(_from, 'From floor')),
              const SizedBox(width: Tokens.space2),
              Expanded(child: _number(_to, 'To floor')),
              const SizedBox(width: Tokens.space2),
              Expanded(child: _number(_units, 'Units / floor')),
            ],
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
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _generate,
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: _busy
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tokens.accentOn,
                  ),
                )
              : const Text('Generate'),
        ),
      ],
    );
  }

  Widget _number(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: label),
    );
  }

  Future<void> _generate() async {
    final t = _tower;
    final from = int.tryParse(_from.text.trim());
    final to = int.tryParse(_to.text.trim());
    final units = int.tryParse(_units.text.trim());
    if (t == null || from == null || to == null || units == null) {
      setState(() => _error = 'Fill in every field.');
      return;
    }
    if (from < 0 || to < from || units < 1) {
      setState(() => _error = 'Floor range and units must be sensible.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.bulkCreateFlats(
        towerId: t.id,
        fromFloor: from,
        toFloor: to,
        unitsPerFloor: units,
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

class _FlatDialog extends StatefulWidget {
  const _FlatDialog({required this.towers});

  final List<Tower> towers;

  @override
  State<_FlatDialog> createState() => _FlatDialogState();
}

class _FlatDialogState extends State<_FlatDialog> {
  final _label = TextEditingController();
  final _unit = TextEditingController();
  final _area = TextEditingController();
  Tower? _tower;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _unit.dispose();
    _area.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'New flat',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Tower?>(
            initialValue: _tower,
            decoration: const InputDecoration(labelText: 'Tower (optional)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('No tower')),
              for (final t in widget.towers)
                DropdownMenuItem(value: t, child: Text(t.name)),
            ],
            onChanged: (t) => setState(() => _tower = t),
          ),
          SizedBox(height: Tokens.space3),
          TextField(
            controller: _label,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Label',
              hintText: 'A-1204',
            ),
          ),
          SizedBox(height: Tokens.space3),
          TextField(
            controller: _unit,
            decoration: const InputDecoration(
              labelText: 'Unit number',
              helperText: 'Required by the backend, e.g. "1204"',
            ),
          ),
          SizedBox(height: Tokens.space3),
          TextField(
            controller: _area,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Area in sq ft (optional)',
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
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _add,
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: _busy
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Tokens.accentOn,
                  ),
                )
              : const Text('Add flat'),
        ),
      ],
    );
  }

  Future<void> _add() async {
    final label = _label.text.trim();
    final unit = _unit.text.trim();
    if (label.isEmpty || unit.isEmpty) {
      setState(() => _error = 'Label and unit number are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.createFlat(
        label: label,
        unitNumber: unit,
        towerId: _tower?.id,
        areaSqft: int.tryParse(_area.text.trim()),
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

// ---------------------------------------------------------------- gates

class _Gates extends StatelessWidget {
  const _Gates({required this.future, required this.onChanged});

  final Future<List<Gate>> future;
  final Future<void> Function() onChanged;

  static final _types = <(String, String)>[
    ('MAIN', 'Main'),
    ('SERVICE', 'Service'),
    ('VISITOR', 'Visitor'),
    ('DELIVERY', 'Delivery'),
    ('EMERGENCY', 'Emergency'),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Gate>>(
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
        final gates = snapshot.data ?? <Gate>[];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              children: [
                for (var i = 0; i < gates.length; i++) ...[
                  if (i > 0) Hairline(),
                  ListRow(
                    title: gates[i].name,
                    subtitle: '${gates[i].assignedGuards} guards assigned',
                    icon: Icons2.gate,
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: AppIcon(
                        Icons2.delete,
                        size: IconSize.row,
                        color: Tokens.inkFaint,
                      ),
                      onPressed: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete ${gates[i].name}?',
                          message:
                              'Guards assigned to this gate keep working; '
                              'only the gate record goes.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (!ok) return;
                        try {
                          await AppServices.instance.admin.deleteGate(
                            gates[i].id,
                          );
                          await onChanged();
                          if (context.mounted) {
                            showMessage(context, 'Gate removed.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, '$e', error: true);
                          }
                        }
                      },
                    ),
                    showChevron: false,
                  ),
                ],
                if (gates.isNotEmpty) const Hairline(),
                _AddRow(
                  label: 'Add gate',
                  onTap: () async {
                    final result = await showDialog<(String, String)>(
                      context: context,
                      builder: (_) => _GateDialog(types: _types),
                    );
                    if (result == null) return;
                    try {
                      await AppServices.instance.admin.createGate(
                        name: result.$1,
                        type: result.$2,
                      );
                      await onChanged();
                      if (context.mounted) showMessage(context, 'Gate added.');
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GateDialog extends StatefulWidget {
  const _GateDialog({required this.types});

  final List<(String, String)> types;

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  final _name = TextEditingController();
  String _type = 'MAIN';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'New gate',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Main gate',
            ),
          ),
          const SizedBox(height: Tokens.space4),
          Wrap(
            spacing: Tokens.space2,
            runSpacing: Tokens.space2,
            children: [
              for (final (value, label) in widget.types)
                ChoiceChip(
                  label: Text(label),
                  selected: value == _type,
                  selectedColor: Tokens.accentTint,
                  onSelected: (_) => setState(() => _type = value),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) {
              showMessage(context, 'Give the gate a name.', error: true);
              return;
            }
            Navigator.of(context).pop((n, _type));
          },
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: const Text('Add gate'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- blocks

class _Blocks extends StatelessWidget {
  const _Blocks({required this.future, required this.onChanged});

  final Future<List<Map<String, dynamic>>> future;
  final Future<void> Function() onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
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
        final blocks = snapshot.data ?? <Map<String, dynamic>>[];
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
          child: Panel(
            child: Column(
              children: [
                for (var i = 0; i < blocks.length; i++) ...[
                  if (i > 0) Hairline(),
                  ListRow(
                    title: asString(blocks[i]['name'], fallback: 'Block'),
                    subtitle: asStringOrNull(blocks[i]['description']),
                    icon: Icons2.flat,
                    trailing: IconButton(
                      tooltip: 'Delete',
                      icon: AppIcon(
                        Icons2.delete,
                        size: IconSize.row,
                        color: Tokens.inkFaint,
                      ),
                      onPressed: () async {
                        final id = asString(blocks[i]['id']);
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete this block?',
                          message:
                              'Towers in this block lose their association. Only an '
                              'empty block can be removed.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );
                        if (!ok) return;
                        try {
                          await AppServices.instance.admin.deleteBlock(id);
                          await onChanged();
                          if (context.mounted) {
                            showMessage(context, 'Block removed.');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, '$e', error: true);
                          }
                        }
                      },
                    ),
                    showChevron: false,
                  ),
                ],
                if (blocks.isNotEmpty) const Hairline(),
                _AddRow(
                  label: 'Add block',
                  onTap: () async {
                    final name = await showDialog<String>(
                      context: context,
                      builder: (_) => const _BlockDialog(),
                    );
                    if (name == null) return;
                    try {
                      await AppServices.instance.admin.createBlock(name: name);
                      await onChanged();
                      if (context.mounted) showMessage(context, 'Block added.');
                    } catch (e) {
                      if (context.mounted) {
                        showMessage(context, '$e', error: true);
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BlockDialog extends StatefulWidget {
  const _BlockDialog();

  @override
  State<_BlockDialog> createState() => _BlockDialogState();
}

class _BlockDialogState extends State<_BlockDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Tokens.surface,
      title: Text(
        'New block',
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeMd,
          fontWeight: FontWeight.w600,
          color: Tokens.ink,
        ),
      ),
      content: TextField(
        controller: _name,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Block C',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final n = _name.text.trim();
            if (n.isEmpty) {
              showMessage(context, 'Give the block a name.', error: true);
              return;
            }
            Navigator.of(context).pop(n);
          },
          style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
          child: const Text('Add block'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- shared

class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.label,
    required this.onTap,
    this.icon = Icons2.add,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 10,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: Tokens.space1,
          vertical: Tokens.space2,
        ),
        child: Row(
          children: [
            AppIcon(icon, size: IconSize.row, color: Tokens.accent),
            SizedBox(width: Tokens.space3),
            Text(
              label,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                fontWeight: FontWeight.w600,
                color: Tokens.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
