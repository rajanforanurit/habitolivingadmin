import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';

/// Property type and layout, driven entirely by what the Super Admin enters.
///
/// - **Multifamily**: "Number of towers" generates that many tower sections.
///   Each tower asks for just two things: its name and the names of its flats
///   (e.g. A-101, A-102). There are no separate floor settings; the floor is
///   part of the flat name. Nothing is pre-filled or hardcoded.
/// - **Single family**: "Number of houses / villas" generates that many
///   entries, and each one asks only for the house / villa name.
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
  _TowerRow({String name = '', List<String>? flats})
    : name = TextEditingController(text: name),
      flats = flats ?? <String>[];

  factory _TowerRow.fromConfig(TowerConfig t) => _TowerRow(name: t.name, flats: [...t.flatNames]);

  final TextEditingController name;

  /// What is being typed into "Add flats" before it is added.
  final TextEditingController flatInput = TextEditingController();

  /// The flat names of this tower, in the order they were added.
  final List<String> flats;

  /// Whether every flat chip is shown (long towers collapse to the first few).
  bool expanded = false;

  void dispose() {
    name.dispose();
    flatInput.dispose();
  }

  int get totalUnits => flats.length;

  static const maxFlatLength = 30;
  static const maxFlatsPerTower = 2000;

  /// `101-110` / `A-101 to A-110` / `B1-B4`: a prefix (optional) and a number range.
  static final _range = RegExp(r'^(\D*?)(\d+)\s*(?:-|–|to)\s*(\D*?)(\d+)$', caseSensitive: false);

  /// Splits what was typed into flat names. Commas and new lines separate
  /// names; a range like `101-110` or `A-101 to A-110` expands to every flat in it.
  static List<String> parse(String raw) {
    final out = <String>[];
    for (final part in raw.split(RegExp(r'[,\n;]'))) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final m = _range.firstMatch(p);
      if (m != null) {
        final prefix = m.group(1)!;
        final endPrefix = m.group(3)!;
        final from = int.parse(m.group(2)!);
        final to = int.parse(m.group(4)!);
        final samePrefix = endPrefix.isEmpty || endPrefix.toLowerCase() == prefix.toLowerCase();
        if (samePrefix && to > from && to - from < 500) {
          final width = m.group(2)!.startsWith('0') ? m.group(2)!.length : 0;
          for (var n = from; n <= to; n++) {
            out.add('$prefix${n.toString().padLeft(width, '0')}');
          }
          continue;
        }
      }
      out.add(p);
    }
    return out;
  }

  /// Adds the typed names, skipping ones this tower already has. Returns how many were added.
  int addTyped() {
    final have = {for (final f in flats) f.toLowerCase()};
    var added = 0;
    for (final f in parse(flatInput.text)) {
      if (flats.length >= maxFlatsPerTower) break;
      if (have.add(f.toLowerCase())) {
        flats.add(f);
        added++;
      }
    }
    flatInput.clear();
    return added;
  }

  String? get problem {
    if (name.text.trim().isEmpty) return 'Enter a tower name';
    if (flats.isEmpty) return 'Add the flats in this tower';
    for (final f in flats) {
      if (f.length > maxFlatLength) return 'Flat name "$f" is too long (max $maxFlatLength characters)';
    }
    return null;
  }

  TowerConfig toConfig() => TowerConfig(name: name.text.trim(), flats: List<String>.unmodifiable(flats));
}

class PropertyLayoutEditorState extends State<PropertyLayoutEditor> {
  String? _type;
  final _towerCount = TextEditingController();
  final List<_TowerRow> _towers = [];
  final _houses = TextEditingController();

  /// One name field per house / villa, generated from the house count.
  final List<TextEditingController> _houseNames = [];

  static const _maxTowers = 100;
  static const _maxHouses = 1000;
  static const _maxHouseName = 30;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    for (final t in widget.initialTowers) {
      _towers.add(_TowerRow.fromConfig(t));
    }
    if (_towers.isNotEmpty) _towerCount.text = '${_towers.length}';
    final sf = widget.initialSingleFamily;
    if (sf != null && sf.totalHouses > 0) {
      for (final name in sf.houseNames) {
        _houseNames.add(TextEditingController(text: name));
      }
      _houses.text = '${_houseNames.length}';
    }
  }

  @override
  void dispose() {
    for (final c in [_towerCount, _houses, ..._houseNames]) {
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
    if (_houseNames.isEmpty) return null;
    return SingleFamilyConfig(houses: [for (final c in _houseNames) c.text.trim()]);
  }

  int get towerCount => _towers.length;
  int get configuredTowers => _towers.where((t) => t.problem == null).length;
  int get totalUnits => _type == PropertyKind.singleFamily
      ? _houseNames.where((c) => c.text.trim().isNotEmpty).length
      : _towers.where((t) => t.problem == null).fold(0, (a, t) => a + t.totalUnits);

  /// First thing still missing, or null when the layout is complete.
  String? validate() {
    if (_type == null) return 'Choose a property type: Multifamily or Single family.';
    if (_type == PropertyKind.singleFamily) {
      if (_houseNames.isEmpty) return 'Enter the number of houses / villas.';
      // House names identify a home across the society, so each must be filled in and unique.
      final seen = <String>{};
      for (var i = 0; i < _houseNames.length; i++) {
        final name = _houseNames[i].text.trim();
        if (name.isEmpty) return 'Enter a name for house ${i + 1}.';
        if (name.length > _maxHouseName) return 'House ${i + 1}: the name is too long (max $_maxHouseName characters).';
        if (!seen.add(name.toLowerCase())) return 'House ${i + 1}: the name "$name" is already used.';
      }
      return null;
    }
    if (_towers.isEmpty) return 'Enter the number of towers.';
    final names = <String>{};
    // Flat names must be unique across the whole society, since that is how residents and guards identify a flat.
    final flatOwner = <String, int>{};
    var units = 0;
    for (var i = 0; i < _towers.length; i++) {
      final t = _towers[i];
      final p = t.problem;
      if (p != null) return 'Tower ${i + 1}: $p.';
      if (!names.add(t.name.text.trim().toLowerCase())) return 'Tower ${i + 1}: the name "${t.name.text.trim()}" is already used.';
      for (final f in t.flats) {
        final other = flatOwner[f.toLowerCase()];
        if (other != null && other != i) {
          return 'Flat "$f" is in both ${_towerLabel(other)} and ${_towerLabel(i)}. Flat names must be unique, e.g. A-101 and B-101.';
        }
        flatOwner[f.toLowerCase()] = i;
      }
      units += t.totalUnits;
    }
    if (units > 20000) return 'A society can have at most 20,000 units.';
    return null;
  }

  String _towerLabel(int i) {
    final n = _towers[i].name.text.trim();
    return n.isEmpty ? 'Tower ${i + 1}' : n;
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

  /// Convenience: fills blank names with Tower A, B, C ... The admin can still edit them.
  void _autoName() => _changed(() {
    for (var i = 0; i < _towers.length; i++) {
      final t = _towers[i];
      if (t.name.text.trim().isEmpty) t.name.text = 'Tower ${_letter(i)}';
    }
  });

  void _setHouseCount(String raw) {
    final n = (int.tryParse(raw.trim()) ?? 0).clamp(0, _maxHouses);
    _changed(() {
      while (_houseNames.length > n) {
        _houseNames.removeLast().dispose();
      }
      while (_houseNames.length < n) {
        _houseNames.add(TextEditingController());
      }
    });
  }

  /// Convenience: fills blank house names with Villa 1, Villa 2 ... The admin can still edit them.
  void _suggestHouseNames() => _changed(() {
    for (var i = 0; i < _houseNames.length; i++) {
      if (_houseNames[i].text.trim().isEmpty) _houseNames[i].text = 'Villa ${i + 1}';
    }
  });

  void _addFlats(_TowerRow t) {
    if (t.flatInput.text.trim().isEmpty) return;
    _changed(t.addTyped);
  }

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
              _typeTile(PropertyKind.multifamily, 'Multifamily', 'Towers and their flats', Icons2.tower),
              const SizedBox(width: Tokens.space3),
              _typeTile(PropertyKind.singleFamily, 'Single family', 'Named houses / villas', Icons2.family),
            ],
          ),
        ),
        if (widget.lockType)
          Padding(
            padding: const EdgeInsets.only(top: Tokens.space2),
            child: Text('The property type cannot change once units exist. You can add towers and flats.', style: _muted),
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
                  Text('$totalUnits flats', style: _muted),
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
            // 1. Tower name
            TextField(
              controller: t.name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: 'Tower name', hintText: 'Tower $letter'),
              onChanged: (_) => _changed(() {}),
            ),
            const SizedBox(height: Tokens.space3),
            // 2. Flat names
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: t.flatInput,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Add flat names',
                      hintText: '$letter-101, $letter-102',
                      helperText: 'Separate with commas. A range like $letter-101 to $letter-110 adds every flat in it.',
                      helperMaxLines: 2,
                    ),
                    onSubmitted: (_) => _addFlats(t),
                  ),
                ),
                const SizedBox(width: Tokens.space2),
                Padding(
                  padding: const EdgeInsets.only(top: Tokens.space1),
                  child: IconButton.filledTonal(
                    tooltip: 'Add flats',
                    icon: const AppIcon(Icons2.add, size: IconSize.row),
                    onPressed: () => _addFlats(t),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space3),
            if (t.flats.isEmpty)
              Text('No flats added yet.', style: _muted)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${t.flats.length} ${t.flats.length == 1 ? 'flat' : 'flats'}',
                      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, fontWeight: FontWeight.w600, color: Tokens.ink),
                    ),
                  ),
                  if (t.expanded && t.flats.length > _collapsedFlats)
                    TextButton(
                      onPressed: () => setState(() => t.expanded = false),
                      child: const Text('Show less'),
                    ),
                  TextButton(
                    onPressed: () async {
                      final clear = await _confirmClear(context, t);
                      if (clear) _changed(t.flats.clear);
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: Tokens.space1),
              Wrap(
                spacing: Tokens.space2,
                runSpacing: Tokens.space2,
                children: [
                  for (final f in (t.expanded ? t.flats : t.flats.take(_collapsedFlats)))
                    InputChip(
                      label: Text(f),
                      visualDensity: VisualDensity.compact,
                      onDeleted: () => _changed(() => t.flats.remove(f)),
                    ),
                  if (!t.expanded && t.flats.length > _collapsedFlats)
                    ActionChip(
                      label: Text('+${t.flats.length - _collapsedFlats} more'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => t.expanded = true),
                    ),
                ],
              ),
            ],
            if (!ok && (t.name.text.isNotEmpty || t.flats.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: Tokens.space2),
                child: Text(problem ?? '', style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeXs, color: Tokens.warning)),
              ),
          ],
        ),
      ),
    );
  }

  /// How many flat chips a tower shows before "+N more".
  static const _collapsedFlats = 24;

  Future<bool> _confirmClear(BuildContext context, _TowerRow t) async {
    final label = t.name.text.trim().isEmpty ? 'this tower' : t.name.text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Tokens.surface,
        title: const Text('Remove all flats?'),
        content: Text('This removes all ${t.flats.length} flats from $label.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------------------------------------------- single family UI

  List<Widget> _single() {
    final total = _houseNames.length;
    final named = _houseNames.where((c) => c.text.trim().isNotEmpty).length;
    return [
      const SectionLabel('Houses / villas'),
      const SizedBox(height: Tokens.space2),
      TextField(
        controller: _houses,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Number of houses / villas',
          helperText: 'Enter a number and a name field appears for each one (up to $_maxHouses).',
        ),
        onChanged: _setHouseCount,
      ),
      if (total > 0) ...[
        const SizedBox(height: Tokens.space4),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$named of $total named',
                style: TextStyle(fontFamily: Tokens.fontFamily, fontWeight: FontWeight.w600, color: named == total ? Tokens.positive : Tokens.ink),
              ),
              const SizedBox(height: Tokens.space2),
              Text('Every house / villa needs a name before the society can be saved.', style: _muted),
              const SizedBox(height: Tokens.space2),
              ActionChip(label: const Text('Suggest names'), onPressed: _suggestHouseNames),
            ],
          ),
        ),
        const SizedBox(height: Tokens.space3),
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.space3),
            child: TextField(
              controller: _houseNames[i],
              textCapitalization: TextCapitalization.words,
              maxLength: _maxHouseName,
              decoration: InputDecoration(
                labelText: 'House / villa ${i + 1} name',
                hintText: 'Villa ${i + 1}',
                counterText: '',
              ),
              onChanged: (_) => _changed(() {}),
            ),
          ),
      ],
    ];
  }
}
