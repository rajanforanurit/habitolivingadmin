import 'package:flutter/material.dart';

import '../../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Staff: the people the society employs or contracts.
///
/// Separate from guards (they have their own gate screens) and from residents
/// (they don't live here). This is the list a manager opens when someone calls
/// in sick.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  int _revision = 0;
  late Future<PageResult<Staff>> _staff = _load();

  Future<PageResult<Staff>> _load() =>
      AppServices.instance.admin.staff(limit: 50);

  void _reload() => setState(() {
    _staff = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Staff',
      subtitle: 'Who the society employs',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const StaffEditScreen()),
          );
          if (ok == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<PageResult<Staff>>(
        key: ValueKey(_revision),
        future: _staff,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data?.items ?? const <Staff>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.staff,
              title: 'No staff yet',
              message:
                  'Add the people who work here — housekeeping, maintenance, '
                  'gardening — so assignments and attendance have someone to '
                  'attach to.',
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
                      person: items[i],
                      onTap: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => StaffEditScreen(person: items[i]),
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
  const _Card({required this.person, required this.onTap});

  final Staff person;
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
            InitialsAvatar(name: person.name, size: 44),
            SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    [
                      person.type,
                      if (person.shift != null) person.shift!,
                      if (person.vendorName != null) person.vendorName!,
                    ].join(' · '),
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
            StatusBadge.forStatus(
              person.status,
              domain: StatusDomain.generic,
              dot: false,
            ),
          ],
        ),
      ),
    );
  }
}

class StaffEditScreen extends StatefulWidget {
  const StaffEditScreen({super.key, this.person});

  final Staff? person;

  @override
  State<StaffEditScreen> createState() => _StaffEditScreenState();
}

class _StaffEditScreenState extends State<StaffEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  String _type = 'HOUSEKEEPING';
  String _shift = 'DAY';
  bool _busy = false;
  String? _error;

  static final _types = <(String, String)>[
    ('HOUSEKEEPING', 'Housekeeping'),
    ('MAINTENANCE', 'Maintenance'),
    ('GARDENER', 'Gardener'),
    ('ELECTRICIAN', 'Electrician'),
    ('PLUMBER', 'Plumber'),
    ('SECURITY', 'Security'),
    ('OFFICE', 'Office'),
    ('OTHER', 'Other'),
  ];

  static final _shifts = <(String, String)>[
    ('DAY', 'Day'),
    ('NIGHT', 'Night'),
    ('ROTATING', 'Rotating'),
    ('ON_CALL', 'On call'),
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _name = TextEditingController(text: p?.name ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
    if (p != null) {
      _type = p.type.toUpperCase().replaceAll(' ', '_');
      _shift = (p.shift ?? 'DAY').toUpperCase().replaceAll(' ', '_');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final admin = AppServices.instance.admin;
      if (widget.person == null) {
        await admin.createStaff(
          name: _name.text.trim(),
          type: _type,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          shift: _shift,
        );
      } else {
        await admin.updateStaff(widget.person!.id, {
          'name': _name.text.trim(),
          'type': _type,
          'shift': _shift,
          if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        });
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

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${widget.person!.name}?',
      message:
          'Attendance history is kept. The person stops being assignable to '
          'tasks immediately.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.admin.deleteStaff(widget.person!.id);
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
    final editing = widget.person != null;
    return AppScaffold(
      title: editing ? 'Edit staff' : 'New staff member',
      subtitle: editing ? widget.person!.name : 'Someone the society employs',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _name,
                autofocus: !editing,
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Enter a name' : null,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
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
                'Shift',
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
                  for (final (value, label) in _shifts)
                    _Choice(
                      label: label,
                      selected: value == _shift,
                      onTap: () => setState(() => _shift = value),
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
                    : Text(editing ? 'Save' : 'Add staff member'),
              ),
            ),
            if (editing) ...[
              SizedBox(height: Tokens.space2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: OutlinedButton(
                  onPressed: _busy ? null : _remove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Tokens.danger,
                    side: BorderSide(color: Tokens.danger),
                    minimumSize: const Size.fromHeight(Tokens.controlHeight),
                  ),
                  child: const Text('Remove from society'),
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
