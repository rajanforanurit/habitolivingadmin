import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';

/// Property type and layout, driven entirely by what the Super Admin enters.
///
/// - **Multifamily**: "Number of towers" generates that many tower cards.
///   Each tower has its own name, code, floor count and units per floor, and
///   individual floors can be adjusted. Unit numbers are generated from the
///   tower code (A-101, A-102 ...). Nothing is pre-filled or hardcoded.
/// - **Single family**: a house count with a label prefix and start number.
///
/// [isComplete] stays false until every tower (or the house block) is fully
/// configured; screens use it to enable the final create / approve action.
class PropertyLayoutEditor extends StatefulWidget {
  const PropertyLayoutEditor({
    super.key,
    this.initialType,
    this.initialTowers = const [],
    this.initialSingleFamily,
    this.lockType = false,
    this.onChanged,
  });

  final String? initialType;
  final List<TowerConfig> initialTowers;
  final SingleFamilyConfig? initialSingleFamily;

  /// True once units exist: the type can no longer change.
  final bool lockType;

  /// Called after every edit so the parent can re-evaluate [isComplete].
  final VoidCallback? onChanged;

  @override
  State<PropertyLayoutEditor> createState() => PropertyLayoutEditorState();
}

class _TowerRow {
  _TowerRow({String name = '', String code = '', int floors = 0, int unitsPerFloor = 0, List<int>? floorUnits})
    : name = TextEditingController(text: name),
      code = TextEditingController(text: code),
      floorCount = TextEditingController(text: floors == 0 ? '' : '$floors'),
      unitsPerFloor = TextEditingController(text: unitsPerFloor == 0 ? '' : '$unitsPerFloor'),
      floorUnits = floorUnits ?? <int>[];

  factory _TowerRow.fromConfig(TowerConfig t) {
    final units = [for (final f in t.floors) f.units];
    final uniform = units.isNotEmpty && units.every((u) => u == units.first);
    return _TowerRow(
      name: t.name,
      code: t.code,
      floors: t.floors.length,
      unitsPerFloor: uniform ? units.first : 0,
      floorUnits: units,
    )..customised = !uniform;
  }

  final TextEditingController name;
  final TextEditingController code;
  final TextEditingController floorCount;
  final TextEditingController unitsPerFloor;

  /// Units on floor 1, 2, 3 ... (index 0 is floor 1).
  final List<int> floorUnits;
  bool expanded = false;
  bool customised = false;

  void dispose() {
    name.dispose();
    code.dispose();
    floorCount.dispose();
    unitsPerFloor.dispose();
  }

  int get floors => int.tryParse(floorCount.text.trim()) ?? 0;
  int get defaultUnits => int.tryParse(unitsPerFloor.text.trim()) ?? 0;
  int get totalUnits => floorUnits.fold(0, (a, b) => a + b);

  /// Floor count changed: keep what was entered for existing floors, fill new ones with the default.
  void resizeFloors() {
    final n = floors.clamp(0, 200);
    while (floorUnits.length > n) {
      floorUnits.removeLast();
    }
    while (floorUnits.length < n) {
      floorUnits.add(defaultUnits);
    }
  }

  /// "Units per floor" changed: apply to every floor.
  void applyDefaultUnits() {
    final n = floors.clamp(0, 200);
    floorUnits
      ..clear()
      ..addAll(List<int>.filled(n, defaultUnits));
    customised = false;
  }

  static final _code = RegExp(r'^[A-Za-z0-9]{1,6}$');

  String? get problem {
    if (name.text.trim().isEmpty) return 'Enter a tower name';
    if (!_code.hasMatch(code.text.trim())) return 'Enter a tower code (1–6 letters or digits)';
    if (floors < 1 || floors > 200) return 'Enter the number of floors';
    if (floorUnits.length != floors) return 'Set the units per floor';
    if (floorUnits.any((u) => u < 1 || u > 50)) return 'Every floor needs 1–50 units';
    return null;
  }

  TowerConfig toConfig() => TowerConfig(
    name: name.text.trim(),
    code: code.text.trim().toUpperCase(),
    floors: [for (var i = 0; i < floorUnits.length; i++) FloorConfig(number: i + 1, units: floorUnits[i])],
  );
}

class PropertyLayoutEditorState extends State<PropertyLayoutEditor> {
  String? _type;
  final _towerCount = TextEditingController();
  final List<_TowerRow> _towers = [];
  final _houses = TextEditingController();
  final _prefix = TextEditingController(text: 'H-');
  final _start = TextEditingController(text: '1');

  static const _maxTowers = 100;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    for (final t in widget.initialTowers) {
      _towers.add(_TowerRow.fromConfig(t));
    }
    if (_towers.isNotEmpty) _towerCount.text = '${_towers.length}';
    final sf = widget.initialSingleFamily;
    if (sf != null) {
      _houses.text = '${sf.totalHouses}';
      _prefix.text = sf.labelPrefix;
      _start.text = '${sf.startNumber}';
    }
  }

  @override
  void dispose() {
    for (final c in [_towerCount, _houses, _prefix, _start]) {
      c.dispose();
    }
    for (final t in _towers) {
      t.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ public API

  String? get propertyType => _type;

  /// The multifamily layout as entered (complete towers only).
  List<TowerConfig> get towers => [
    for (final t in _towers)
      if (t.problem == null) t.toConfig(),
  ];

  SingleFamilyConfig? get singleFamily {
    final n = int.tryParse(_houses.text.trim());
    if (n == null || n < 1) return null;
    return SingleFamilyConfig(
      totalHouses: n,
      labelPrefix: _prefix.text.trim().isEmpty ? 'H-' : _prefix.text.trim(),
      startNumber: int.tryParse(_start.text.trim()) ?? 1,
    );
  }

  int get towerCount => _towers.length;
  int get configuredTowers => _towers.where((t) => t.problem == null).length;
  int get totalUnits => _type == PropertyKind.singleFamily
      ? (singleFamily?.totalHouses ?? 0)
      : _towers.where((t) => t.problem == null).fold(0, (a, t) => a + t.totalUnits);

  /// First thing still missing, or null when the layout is complete.
  String? validate() {
    if (_type == null) return 'Choose a property type: Multifamily or Single family.';
    if (_type == PropertyKind.singleFamily) {
      final n = int.tryParse(_houses.text.trim());
      if (n == null || n < 1) return 'Enter the number of houses.';
      if (n > 20000) return 'A society can have at most 20,000 houses.';
      final s = int.tryParse(_start.text.trim());
      if (s == null || s < 1) return 'Enter a valid starting house number.';
      if (_prefix.text.trim().length > 8) return 'The house label prefix is too long.';
      return null;
    }
    if (_towers.isEmpty) return 'Enter the number of towers.';
    final names = <String>{};
    final codes = <String>{};
    var units = 0;
    for (var i = 0; i < _towers.length; i++) {
      final t = _towers[i];
      final p = t.problem;
      if (p != null) return 'Tower ${i + 1}: $p.';
      if (!names.add(t.name.text.trim().toLowerCase())) return 'Tower ${i + 1}: the name "${t.name.text.trim()}" is already used.';
      if (!codes.add(t.code.text.trim().toUpperCase())) return 'Tower ${i + 1}: the code "${t.code.text.trim().toUpperCase()}" is already used.';
      units += t.totalUnits;
    }
    if (units > 20000) return 'A society can have at most 20,000 units.';
    return null;
  }

  bool get isComplete => validate() == null;

  // ---------------------------------------------------------------- state

  void _changed(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  void _setType(String type) {
    if (widget.lockType || _type == type) return;
    _changed(() => _type = type);
  }

  void _setTowerCount(String raw) {
    final n = (int.tryParse(raw.trim()) ?? 0).clamp(0, _maxTowers);
    _changed(() {
      while (_towers.length > n) {
        _towers.removeLast().dispose();
      }
      while (_towers.length < n) {
        _towers.add(_TowerRow());
      }
    });
  }

  static String _letter(int i) => i < 26 ? String.fromCharCode(65 + i) : 'T${i + 1}';

  /// Convenience: fills blank names / codes with Tower A, B, C ... The admin can still edit them.
  void _autoName() => _changed(() {
    for (var i = 0; i < _towers.length; i++) {
      final t = _towers[i];
      if (t.name.text.trim().isEmpty) t.name.text = 'Tower ${_letter(i)}';
      if (t.code.text.trim().isEmpty) t.code.text = _letter(i);
    }
  });

  /// Copies the first tower's floors and units to every tower that has none yet.
  void _copyFirst() => _changed(() {
    final first = _towers.first;
    for (final t in _towers.skip(1)) {
      if (t.floors != 0) continue;
      t.floorCount.text = first.floorCount.text;
      t.unitsPerFloor.text = first.unitsPerFloor.text;
      t.floorUnits
        ..clear()
        ..addAll(first.floorUnits);
      t.customised = first.customised;
    }
  });

  // ------------------------------------------------------------------ UI

  Widget _typeTile(String type, String title, String subtitle, IconData icon) {
    final selected = _type == type;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        onTap: widget.lockType ? null : () => _setType(type),
        child: Container(
          padding: const EdgeInsets.all(Tokens.space4),
          decoration: BoxDecoration(
            color: selected ? Tokens.accentTint : Tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            border: Border.all(color: selected ? Tokens.accent : Tokens.line, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppIcon(icon, size: IconSize.row, color: selected ? Tokens.accent : Tokens.inkMuted),
              const SizedBox(height: Tokens.space2),
              Text(title, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.inkMuted, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _muted => TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted, height: 1.4);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Property type'),
        const SizedBox(height: Tokens.space2),
        // IntrinsicHeight: a stretched Row inside a scrolling body has unbounded height and would throw.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _typeTile(PropertyKind.multifamily, 'Multifamily', 'Towers with floors and units', Icons2.tower),
              const SizedBox(width: Tokens.space3),
              _typeTile(PropertyKind.singleFamily, 'Single family', 'Individual houses', Icons2.family),
            ],
          ),
        ),
        if (widget.lockType)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space2),
            child: Text('The property type cannot change once units exist. You can add towers, floors and units.', style: _muted),
          ),
        const SizedBox(height: Tokens.space5),
        if (_type == PropertyKind.multifamily) ..._multifamily(),
        if (_type == PropertyKind.singleFamily) ..._single(),
      ],
    );
  }

  // ------------------------------------------------------- multifamily UI

  List<Widget> _multifamily() {
    final done = configuredTowers;
    final total = _towers.length;
    return [
      const SectionLabel('Towers'),
      const SizedBox(height: Tokens.space2),
      TextField(
        controller: _towerCount,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Number of towers',
          helperText: 'Enter a number and a section appears for each tower (up to $_maxTowers).',
        ),
        onChanged: _setTowerCount,
      ),
      if (total > 0) ...[
        const SizedBox(height: Tokens.space4),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$done of $total towers configured',
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: done == total ? Tokens.positive : Tokens.ink),
                    ),
                  ),
                  Text('$totalUnits units', style: _muted),
                ],
              ),
              const SizedBox(height: Tokens.space2),
              ClipRRect(
                borderRadius: BorderRadius.circular(Tokens.radiusFull),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  backgroundColor: Tokens.surfaceSunken,
                  color: done == total ? Tokens.positive : Tokens.accent,
                ),
              ),
              const SizedBox(height: Tokens.space2),
              Text('All towers must be completed before the society can be saved.', style: _muted),
              const SizedBox(height: Tokens.space2),
              Wrap(
                spacing: Tokens.space2,
                children: [
                  ActionChip(label: const Text('Suggest names'), onPressed: _autoName),
                  if (total > 1) ActionChip(label: const Text('Copy tower 1 layout to empty towers'), onPressed: _copyFirst),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space3),
        for (var i = 0; i < total; i++) _towerCard(i),
      ],
    ];
  }

  Widget _towerCard(int i) {
    final t = _towers[i];
    final problem = t.problem;
    final ok = problem == null;
    final letter = _letter(i);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Tower ${i + 1}', style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.space2, vertical: 3),
                  decoration: BoxDecoration(color: ok ? Tokens.positiveTint : Tokens.warningTint, borderRadius: BorderRadius.circular(Tokens.radiusFull)),
                  child: Text(
                    ok ? 'Configured' : 'Incomplete',
                    style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, fontWeight: FontWeight.w600, color: ok ? Tokens.positive : Tokens.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: t.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: 'Tower name', hintText: 'Tower $letter'),
                    onChanged: (_) => _changed(() {}),
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: t.code,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: InputDecoration(labelText: 'Code', hintText: letter, counterText: ''),
                    onChanged: (_) => _changed(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: t.floorCount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Number of floors'),
                    onChanged: (_) => _changed(t.resizeFloors),
                  ),
                ),
                const SizedBox(width: Tokens.space3),
                Expanded(
                  child: TextField(
                    controller: t.unitsPerFloor,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Units per floor'),
                    onChanged: (_) => _changed(t.applyDefaultUnits),
                  ),
                ),
              ],
            ),
            if (t.floorUnits.isNotEmpty) ...[
              const SizedBox(height: Tokens.space3),
              _preview(t),
              const SizedBox(height: Tokens.space1),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => t.expanded = !t.expanded),
                  icon: AppIcon(t.expanded ? Icons2.collapse : Icons2.expand, size: IconSize.inline),
                  label: Text(t.expanded ? 'Hide floors' : 'Customise units for each floor'),
                ),
              ),
              if (t.expanded) _floorList(t),
            ],
            if (!ok && (t.name.text.isNotEmpty || t.code.text.isNotEmpty || t.floorCount.text.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Text(problem ?? '', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.warning)),
              ),
          ],
        ),
      ),
    );
  }

  /// The generated nomenclature, so the Super Admin sees exactly what will be created.
  Widget _preview(_TowerRow t) {
    final code = t.code.text.trim().isEmpty ? '?' : t.code.text.trim().toUpperCase();
    final first = t.floorUnits.first;
    if (t.totalUnits == 0) return Text('${t.floorUnits.length} floors · set the units per floor', style: _muted);
    final sample = [for (var u = 1; u <= first && u <= 4; u++) TowerConfig.unitLabel(code, 1, u)].join(', ');
    return Text(
      '${t.floorUnits.length} floors · ${t.totalUnits} units\nFloor 1: $sample${first > 4 ? ' …' : ''}',
      style: _muted,
    );
  }

  Widget _floorList(_TowerRow t) {
    final code = t.code.text.trim().isEmpty ? '?' : t.code.text.trim().toUpperCase();
    return Column(
      children: [
        for (var f = 0; f < t.floorUnits.length; f++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.space1),
            child: Row(
              children: [
                SizedBox(width: 64, child: Text('Floor ${f + 1}', style: TextStyle(fontFamily: Tokens.fontFamily, color: Tokens.ink))),
                Expanded(
                  child: Text(
                    t.floorUnits[f] <= 0
                        ? '—'
                        : t.floorUnits[f] <= 3
                        ? [for (var u = 1; u <= t.floorUnits[f]; u++) TowerConfig.unitLabel(code, f + 1, u)].join(', ')
                        : '${TowerConfig.unitLabel(code, f + 1, 1)} … ${TowerConfig.unitLabel(code, f + 1, t.floorUnits[f])}',
                    style: _muted,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Fewer units',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: t.floorUnits[f] <= 1 ? null : () => _changed(() {
                    t.floorUnits[f]--;
                    t.customised = true;
                  }),
                ),
                SizedBox(width: 28, child: Text('${t.floorUnits[f]}', textAlign: TextAlign.center, style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: Tokens.ink))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'More units',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: t.floorUnits[f] >= 50 ? null : () => _changed(() {
                    t.floorUnits[f]++;
                    t.customised = true;
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------- single family UI

  List<Widget> _single() {
    final sf = singleFamily;
    return [
      const SectionLabel('Houses'),
      const SizedBox(height: Tokens.space2),
      TextField(
        controller: _houses,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Number of houses'),
        onChanged: (_) => _changed(() {}),
      ),
      const SizedBox(height: Tokens.space3),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _prefix,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'House label prefix', helperText: 'e.g. H- or V-', counterText: ''),
              onChanged: (_) => _changed(() {}),
            ),
          ),
          const SizedBox(width: Tokens.space3),
          Expanded(
            child: TextField(
              controller: _start,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Starting number'),
              onChanged: (_) => _changed(() {}),
            ),
          ),
        ],
      ),
      if (sf != null) ...[
        const SizedBox(height: Tokens.space3),
        Panel(
          child: Text(
            '${sf.totalHouses} houses: ${sf.labelAt(0)}${sf.totalHouses > 1 ? ', ${sf.labelAt(1)}' : ''}${sf.totalHouses > 2 ? ' … ${sf.labelAt(sf.totalHouses - 1)}' : ''}',
            style: _muted,
          ),
        ),
      ],
    ];
  }
}
