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

/// Roles: named, reusable sets of permissions.
///
/// A role is the answer to "what will this person do here" — helpdesk,
/// accountant, security. System roles ship with the platform and cannot be
/// renamed; only their permissions can change.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  int _revision = 0;
  late Future<List<Role>> _roles = AppServices.instance.admin.roles();

  void _reload() {
    setState(() {
      _roles = AppServices.instance.admin.roles();
      _revision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Roles',
      subtitle: 'Who can do what',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const RoleEditScreen()),
          );
          if (ok == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<List<Role>>(
        key: ValueKey(_revision),
        future: _roles,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final roles = snapshot.data ?? const <Role>[];
          if (roles.isEmpty) {
            return const EmptyState(
              icon: Icons2.roles,
              title: 'No roles yet',
              message:
                  'Create a role to give staff and volunteers a named set of '
                  'permissions instead of assigning them one by one.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: Tokens.space8),
            children: [
              for (var i = 0; i < roles.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space4,
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == roles.length - 1 ? 0 : Tokens.space2,
                    ),
                    child: _Card(
                      role: roles[i],
                      onTap: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => RoleEditScreen(role: roles[i]),
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
  const _Card({required this.role, required this.onTap});

  final Role role;
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: role.isSystem ? Tokens.surfaceSunken : Tokens.accentTint,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Center(
                child: AppIcon(
                  role.isSystem ? Icons2.setup : Icons2.roles,
                  size: IconSize.row,
                  color: role.isSystem ? Tokens.inkMuted : Tokens.accent,
                ),
              ),
            ),
            SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          role.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: Tokens.fontFamily,
                            fontSize: Tokens.typeSm,
                            fontWeight: FontWeight.w600,
                            color: Tokens.ink,
                          ),
                        ),
                      ),
                      if (role.isSystem) ...[
                        const SizedBox(width: Tokens.space2),
                        const MetaTag('System'),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${role.permissions.length} permissions'
                    '${role.memberCount > 0 ? ' · ${role.memberCount} people' : ''}'
                    '${role.description != null ? '\n${role.description}' : ''}',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      height: 1.4,
                      color: Tokens.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon(Icons2.forward, size: IconSize.row, color: Tokens.inkFaint),
          ],
        ),
      ),
    );
  }
}

/// Create or edit a role. The permission catalogue is fetched from the backend
/// so new permissions appear here without an app update.
class RoleEditScreen extends StatefulWidget {
  const RoleEditScreen({super.key, this.role});

  final Role? role;

  @override
  State<RoleEditScreen> createState() => _RoleEditScreenState();
}

class _RoleEditScreenState extends State<RoleEditScreen> {
  late final _key = TextEditingController(
    text: widget.role == null ? '' : _keyOf(widget.role!.name),
  );
  late final _name = TextEditingController(text: widget.role?.name ?? '');
  late final _description = TextEditingController(
    text: widget.role?.description ?? '',
  );
  final Set<String> _selected = <String>{};

  List<Map<String, dynamic>>? _catalog;
  String? _catalogError;
  bool _busy = false;
  String? _error;

  static String _keyOf(String name) =>
      'ROLE_${name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '')}';

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.role?.permissions ?? const <String>[]);
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final rows = await AppServices.instance.admin.permissions();
      if (!mounted) return;
      setState(() => _catalog = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogError = '$e');
    }
  }

  @override
  void dispose() {
    _key.dispose();
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final key = _key.text.trim().toUpperCase();
    if (name.length < 2) {
      setState(() => _error = 'Name the role.');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Pick at least one permission.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final admin = AppServices.instance.admin;
      if (widget.role == null) {
        if (!RegExp(r'^[A-Z_]{3,30}$').hasMatch(key)) {
          setState(() {
            _busy = false;
            _error = 'Key must be 3–30 characters, A–Z and underscores.';
          });
          return;
        }
        await admin.createRole(
          name: name,
          key: key,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          permissions: _selected.toList()..sort(),
        );
      } else {
        await admin.updateRole(widget.role!.id, {
          'name': name,
          'description': _description.text.trim(),
          'permissions': _selected.toList()..sort(),
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

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${widget.role!.name}?',
      message:
          'People holding this role lose the permissions it granted. Only an '
          'unused role can be removed.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await AppServices.instance.admin.deleteRole(widget.role!.id);
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
    final editing = widget.role != null;
    final system = widget.role?.isSystem ?? false;
    return AppScaffold(
      title: editing ? 'Edit role' : 'New role',
      subtitle: system
          ? 'System role — name is fixed'
          : 'Permissions and identity',
      body: ListView(
        padding: EdgeInsets.only(bottom: Tokens.space8),
        children: [
          if (!editing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextField(
                controller: _key,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Key',
                  helperText: 'Internal identifier, e.g. HELPDESK_LEAD',
                ),
              ),
            ),
            const SizedBox(height: Tokens.space4),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: TextField(
              controller: _name,
              enabled: !system,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ),
          SizedBox(height: Tokens.space4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true,
              ),
            ),
          ),

          SizedBox(height: Tokens.space6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Permissions',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.ink,
                    ),
                  ),
                ),
                Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeXs,
                    color: Tokens.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Tokens.space3),
          _PermissionGroups(
            catalog: _catalog,
            error: _catalogError,
            selected: _selected,
            onToggle: (key, on) => setState(() {
              if (on) {
                _selected.add(key);
              } else {
                _selected.remove(key);
              }
            }),
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
                  : Text(editing ? 'Save role' : 'Create role'),
            ),
          ),
          if (editing && !system) ...[
            SizedBox(height: Tokens.space2),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: OutlinedButton(
                onPressed: _busy ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Tokens.danger,
                  side: BorderSide(color: Tokens.danger),
                  minimumSize: const Size.fromHeight(Tokens.controlHeight),
                ),
                child: const Text('Delete this role'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionGroups extends StatelessWidget {
  const _PermissionGroups({
    required this.catalog,
    required this.error,
    required this.selected,
    required this.onToggle,
  });

  final List<Map<String, dynamic>>? catalog;
  final String? error;
  final Set<String> selected;
  final void Function(String key, bool on) onToggle;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: Panel(child: ErrorState(compact: true, message: error!)),
      );
    }
    final rows = catalog;
    if (rows == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
        child: Panel(child: LoadingList(rows: 4)),
      );
    }

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final resource = asString(row['resource']);
      groups.putIfAbsent(resource, () => []).add(row);
    }

    final names = groups.keys.toList()..sort();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
      child: Panel(
        child: Column(
          children: [
            for (var gi = 0; gi < names.length; gi++) ...[
              if (gi > 0) Hairline(),
              Padding(
                padding: EdgeInsets.symmetric(vertical: Tokens.space2),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    names[gi].toUpperCase(),
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Tokens.inkFaint,
                    ),
                  ),
                ),
              ),
              for (final row in groups[names[gi]]!)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected.contains(asString(row['key'])),
                  onChanged: (v) => onToggle(asString(row['key']), v ?? false),
                  title: Text(
                    asString(row['key']),
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      color: Tokens.ink,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
