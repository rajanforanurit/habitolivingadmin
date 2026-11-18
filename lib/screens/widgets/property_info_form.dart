import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/ops.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/media_service.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'file_preview.dart';
import 'future_body.dart';
import 'property_layout_editor.dart';

/// Editor for a society's property details (floor plans) and hospitals.
///
/// Used by the Super Admin when creating a society, approving a registration
/// and editing later. Society admins never see this editor: the backend
/// rejects their writes to these fields as well.
///
/// Read the result through the state: `key.currentState!.details`,
/// `.hospitals` and `.validate()`.
class PropertyInfoEditor extends StatefulWidget {
  const PropertyInfoEditor({
    super.key,
    this.initialDetails = PropertyDetails.empty,
    this.initialHospitals = const [],
    this.initialPropertyName,
    this.initialPropertyType,
    this.layoutRequired = true,
    this.lockType = false,
    this.onChanged,
  });

  /// `MULTIFAMILY` / `SINGLE_FAMILY`, or null when none has been chosen yet.
  final String? initialPropertyType;

  /// Create and approve need a complete layout. When editing an older society that
  /// has none, this is false so floor plans and hospitals can still be saved alone.
  final bool layoutRequired;

  /// The type is fixed once units exist.
  final bool lockType;

  /// Called after layout edits so the parent can enable or disable its save button.
  final VoidCallback? onChanged;

  final PropertyDetails initialDetails;
  final List<Hospital> initialHospitals;

  /// Pre-fills the property name (the society name, usually).
  final String? initialPropertyName;

  @override
  State<PropertyInfoEditor> createState() => PropertyInfoEditorState();
}

class _PlanRow {
  _PlanRow(FloorPlan p)
    : title = TextEditingController(text: p.title),
      description = TextEditingController(text: p.description ?? ''),
      fileId = p.fileId;
  final TextEditingController title;
  final TextEditingController description;
  String? fileId;
  bool uploading = false;

  void dispose() {
    title.dispose();
    description.dispose();
  }
}

class _HospitalRow {
  _HospitalRow(Hospital h)
    : name = TextEditingController(text: h.name),
      phone = TextEditingController(text: h.phone),
      address = TextEditingController(text: h.address ?? ''),
      distance = TextEditingController(
        text: h.distanceKm == null ? '' : '${h.distanceKm}',
      ),
      open24x7 = h.open24x7;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController address;
  final TextEditingController distance;
  bool open24x7;

  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    distance.dispose();
  }
}

class PropertyInfoEditorState extends State<PropertyInfoEditor> {
  late final _propertyName = TextEditingController(
    text: widget.initialDetails.propertyName ?? widget.initialPropertyName ?? '',
  );
  late final _description = TextEditingController(text: widget.initialDetails.description ?? '');
  final _layout = GlobalKey<PropertyLayoutEditorState>();
  late final _parking = TextEditingController(text: widget.initialDetails.parkingInfo ?? '');
  late final _notes = TextEditingController(text: widget.initialDetails.notes ?? '');
  late final List<_PlanRow> _plans = widget.initialDetails.floorPlans.map(_PlanRow.new).toList();
  late final List<_HospitalRow> _hospitals = widget.initialHospitals.map(_HospitalRow.new).toList();

  @override
  void dispose() {
    for (final c in [_propertyName, _description, _parking, _notes]) {
      c.dispose();
    }
    for (final p in _plans) {
      p.dispose();
    }
    for (final h in _hospitals) {
      h.dispose();
    }
    super.dispose();
  }

  /// The chosen property type (null until one is selected).
  String? get propertyType => _layout.currentState?.propertyType ?? widget.initialPropertyType;

  /// True when the layout (every tower, or the house block) is fully configured.
  bool get isLayoutComplete => _layout.currentState?.isComplete ?? false;

  /// Whether the parent should treat the layout as part of what is being saved.
  bool get _layoutInPlay => widget.layoutRequired || _layout.currentState?.propertyType != null;

  /// The details as entered. Blank floor plan rows are dropped.
  PropertyDetails get details => PropertyDetails(
    propertyName: _propertyName.text,
    description: _description.text,
    towers: _layoutInPlay && propertyType == PropertyKind.multifamily
        ? (_layout.currentState?.towers ?? const [])
        : const [],
    singleFamily: _layoutInPlay && propertyType == PropertyKind.singleFamily
        ? _layout.currentState?.singleFamily
        : null,
    parkingInfo: _parking.text,
    notes: _notes.text,
    floorPlans: [
      for (final p in _plans)
        if (p.title.text.trim().isNotEmpty)
          FloorPlan(
            title: p.title.text,
            description: p.description.text,
            fileId: p.fileId,
          ),
    ],
  );

  List<Hospital> get hospitals => [
    for (final h in _hospitals)
      if (h.name.text.trim().isNotEmpty || h.phone.text.trim().isNotEmpty)
        Hospital(
          name: h.name.text,
          phone: h.phone.text,
          address: h.address.text,
          distanceKm: double.tryParse(h.distance.text.trim()),
          open24x7: h.open24x7,
        ),
  ];

  /// Returns a message for the first problem, or null when the data is valid.
  String? validate() {
    for (final h in _hospitals) {
      final hasAny = h.name.text.trim().isNotEmpty || h.phone.text.trim().isNotEmpty;
      if (!hasAny) continue;
      if (h.name.text.trim().length < 2) return 'Each hospital needs a name.';
      if (h.phone.text.trim().length < 3) return 'Each hospital needs a phone number.';
    }
    for (final p in _plans) {
      if (p.uploading) return 'Wait for the floor plan upload to finish.';
    }
    final name = _propertyName.text.trim();
    if (name.isNotEmpty && name.length < 2) return 'Property name is too short.';
    // The layout must be complete before the society can be created or approved.
    final layoutState = _layout.currentState;
    if (widget.layoutRequired || layoutState?.propertyType != null) {
      if (layoutState == null) return 'Choose a property type: Multifamily or Single family.';
      final problem = layoutState.validate();
      if (problem != null) return problem;
    }
    return null;
  }

  Future<void> _attach(_PlanRow row) async {
    final media = AppServices.instance.media;
    setState(() => row.uploading = true);
    try {
      final picked = await media.document();
      if (picked == null) return;
      final id = await media.upload(picked, purpose: UploadPurpose.document);
      if (mounted) setState(() => row.fileId = id);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => row.uploading = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? type,
    int maxLines = 1,
    String? hint,
    TextCapitalization caps = TextCapitalization.sentences,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.space3),
    child: TextField(
      controller: c,
      keyboardType: type,
      maxLines: maxLines,
      textCapitalization: caps,
      decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: maxLines > 1),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Property details'),
        const SizedBox(height: Tokens.space2),
        _field(_propertyName, 'Property name', caps: TextCapitalization.words),
        _field(_description, 'Description', maxLines: 3),
        PropertyLayoutEditor(
          key: _layout,
          initialType: widget.initialPropertyType,
          initialTowers: widget.initialDetails.towers,
          initialSingleFamily: widget.initialDetails.singleFamily,
          lockType: widget.lockType,
          onChanged: widget.onChanged,
        ),
        const SizedBox(height: Tokens.space5),
        _field(_parking, 'Parking information', maxLines: 2),
        _field(_notes, 'Notes for residents', maxLines: 2),
        const SizedBox(height: Tokens.space4),
        SectionLabel(
          'Floor plans',
          trailing: TextButton.icon(
            onPressed: () => setState(() => _plans.add(_PlanRow(const FloorPlan(title: '')))),
            icon: const AppIcon(Icons2.add, size: IconSize.inline),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        if (_plans.isEmpty)
          const _Hint('No floor plans yet. Add one per tower or block, with an image or PDF.'),
        for (var i = 0; i < _plans.length; i++) _planCard(i),
        const SizedBox(height: Tokens.space4),
        SectionLabel(
          'Hospitals',
          trailing: TextButton.icon(
            onPressed: () => setState(
              () => _hospitals.add(_HospitalRow(const Hospital(name: '', phone: ''))),
            ),
            icon: const AppIcon(Icons2.add, size: IconSize.inline),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: Tokens.space2),
        if (_hospitals.isEmpty)
          const _Hint('Residents and guards see these under emergency numbers.'),
        for (var i = 0; i < _hospitals.length; i++) _hospitalCard(i),
      ],
    );
  }

  Widget _planCard(int i) {
    final row = _plans[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.title,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Title', hintText: 'Tower A, ground floor'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove floor plan',
                  icon: AppIcon(Icons2.delete, size: IconSize.row, color: Tokens.inkFaint),
                  onPressed: () => setState(() => _plans.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            TextField(
              controller: row.description,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: Tokens.space3),
            if (row.fileId != null) ...[
              FilePreview(fileId: row.fileId!, height: 160),
              const SizedBox(height: Tokens.space2),
            ],
            OutlinedButton.icon(
              onPressed: row.uploading ? null : () => _attach(row),
              icon: row.uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const AppIcon(Icons2.upload, size: IconSize.inline),
              label: Text(row.fileId == null ? 'Attach image or PDF' : 'Replace file'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hospitalCard(int i) {
    final row = _hospitals[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.space3),
      child: Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Hospital name'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove hospital',
                  icon: AppIcon(Icons2.delete, size: IconSize.row, color: Tokens.inkFaint),
                  onPressed: () => setState(() => _hospitals.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: Tokens.space2),
            TextField(
              controller: row.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: Tokens.space2),
            TextField(
              controller: row.address,
              decoration: const InputDecoration(labelText: 'Address (optional)'),
            ),
            const SizedBox(height: Tokens.space2),
            TextField(
              controller: row.distance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Distance in km (optional)'),
            ),
            const SizedBox(height: Tokens.space2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Open 24×7',
                    style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.ink),
                  ),
                ),
                AppSwitch(
                  value: row.open24x7,
                  onChanged: (v) => setState(() => row.open24x7 = v),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.space3),
    child: Text(
      text,
      style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkFaint),
    ),
  );
}
