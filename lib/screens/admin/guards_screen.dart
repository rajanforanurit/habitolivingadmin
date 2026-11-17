import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Guards posted at the society's gates.
///
/// A guard account is created here with a mobile and gate assignment; the
/// guard signs in with that mobile and a password you set. Deactivating
/// revokes their sessions immediately and unassigns the gate.
class GuardsScreen extends StatefulWidget {
  const GuardsScreen({super.key});

  @override
  State<GuardsScreen> createState() => _GuardsScreenState();
}

class _GuardsScreenState extends State<GuardsScreen> {
  int _revision = 0;
  late Future<List<Guard>> _guards = _load();

  Future<List<Guard>> _load() => AppServices.instance.admin.guards();

  void _reload() => setState(() {
    _guards = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Guards',
      subtitle: 'Who watches the gates',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const GuardCreateScreen()),
          );
          if (created == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<List<Guard>>(
        key: ValueKey(_revision),
        future: _guards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data ?? const <Guard>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.guard,
              title: 'No guards registered',
              message:
                  'Register the people on gate duty. Each guard signs in with '
                  'their mobile and a password you set here.',
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
                    child: _Card(guard: items[i], onChanged: _reload),
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
  const _Card({required this.guard, required this.onChanged});

  final Guard guard;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final inactive = guard.status.toUpperCase() != 'ACTIVE';
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: guard.name, size: 44),
          SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guard.name,
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
                    if (guard.phone != null) guard.phone!,
                    if (guard.gate != null) guard.gate!,
                    if (guard.shift != null) guard.shift!,
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
          if (guard.onDuty)
            Padding(
              padding: EdgeInsets.only(right: Tokens.space2),
              child: MetaTag('On duty'),
            ),
          IconButton(
            tooltip: inactive ? 'Remove' : 'Deactivate',
            icon: AppIcon(
              Icons2.delete,
              size: IconSize.row,
              color: Tokens.inkFaint,
            ),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: inactive
                    ? 'Remove ${guard.name}?'
                    : 'Deactivate ${guard.name}?',
                message: inactive
                    ? 'They are already inactive. Removing deletes their gate assignment.'
                    : 'Their sessions are revoked immediately and the gate assignment is cleared.',
                confirmLabel: inactive ? 'Remove' : 'Deactivate',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              try {
                await AppServices.instance.admin.deactivateGuard(guard.id);
                onChanged();
                if (context.mounted) {
                  showMessage(
                    context,
                    inactive ? 'Guard removed.' : 'Guard deactivated.',
                  );
                }
              } catch (e) {
                if (context.mounted) showMessage(context, '$e', error: true);
              }
            },
          ),
        ],
      ),
    );
  }
}

class GuardCreateScreen extends StatefulWidget {
  const GuardCreateScreen({super.key});

  @override
  State<GuardCreateScreen> createState() => _GuardCreateScreenState();
}

class _GuardCreateScreenState extends State<GuardCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();

  List<Gate>? _gates;
  String? _gateId;
  String _shift = 'DAY';
  bool _busy = false;
  String? _error;

  static final _shifts = <(String, String)>[
    ('DAY', 'Day'),
    ('NIGHT', 'Night'),
    ('ROTATING', 'Rotating'),
  ];

  @override
  void initState() {
    super.initState();
    AppServices.instance.admin
        .gates()
        .then((gates) {
          if (!mounted) return;
          setState(() {
            _gates = gates;
            _gateId = gates.isNotEmpty ? gates.first.id : null;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _gates = const <Gate>[]);
        });
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.createGuard(
        name: _name.text.trim(),
        mobile: _mobile.text.trim(),
        gateId: _gateId,
        shift: _shift,
      );
      if (!mounted) return;
      showMessage(context, 'Guard registered. They can sign in now.');
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
    return AppScaffold(
      title: 'Register a guard',
      subtitle: 'Gate duty starts with these details',
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.only(bottom: Tokens.space8),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter their name'
                    : null,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'A reachable mobile number'
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Mobile',
                  helperText: '+91 90000 00000',
                ),
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Gate',
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
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: _gates == null
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Tokens.surfaceSunken,
                      color: Tokens.accent,
                    )
                  : _gates!.isEmpty
                  ? Text(
                      'No gates defined yet. Add one under More → Society setup → Gates.',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        color: Tokens.inkMuted,
                      ),
                    )
                  : Wrap(
                      spacing: Tokens.space2,
                      runSpacing: Tokens.space2,
                      children: [
                        for (final gate in _gates!)
                          _Choice(
                            label: gate.name,
                            selected: gate.id == _gateId,
                            onTap: () => setState(() => _gateId = gate.id),
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
                onPressed: _busy ? null : _create,
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
                    : const Text('Register guard'),
              ),
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
