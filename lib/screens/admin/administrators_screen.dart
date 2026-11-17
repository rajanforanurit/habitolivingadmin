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

/// Administrators of this society: who else can do what you can.
///
/// Creating an admin sends them an account (mobile + temporary password) that
/// they must rotate at first sign-in. Deactivating revokes their sessions
/// immediately; it does not delete their history.
class AdministratorsScreen extends StatefulWidget {
  const AdministratorsScreen({super.key});

  @override
  State<AdministratorsScreen> createState() => _AdministratorsScreenState();
}

class _AdministratorsScreenState extends State<AdministratorsScreen> {
  int _revision = 0;
  late Future<List<AdminUser>> _admins = _load();

  Future<List<AdminUser>> _load() => AppServices.instance.admin.admins();

  void _reload() => setState(() {
    _admins = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Administrators',
      subtitle: 'Who else can run the society',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const AdminCreateScreen()),
          );
          if (created == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<List<AdminUser>>(
        key: ValueKey(_revision),
        future: _admins,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data ?? const <AdminUser>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.administrators,
              title: 'No administrators yet',
              message:
                  'Add the people who share this workload — the treasurer, the '
                  'facility manager, the security lead.',
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
                    child: _Card(admin: items[i], onChanged: _reload),
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
  const _Card({required this.admin, required this.onChanged});

  final AdminUser admin;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final inactive = admin.status.toUpperCase() != 'ACTIVE';
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      child: Row(
        children: [
          InitialsAvatar(name: admin.name, size: 44),
          SizedBox(width: Tokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin.name,
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
                    admin.mobile,
                    if (admin.roleName != null) admin.roleName!,
                    if (admin.email != null) admin.email!,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusBadge.forStatus(
                admin.status,
                domain: StatusDomain.generic,
                dot: false,
              ),
              SizedBox(height: Tokens.space1),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                icon: AppIcon(
                  Icons2.more,
                  size: IconSize.row,
                  color: Tokens.inkMuted,
                ),
                onSelected: (value) async {
                  switch (value) {
                    case 'deactivate':
                      await _deactivate(context, inactive);
                    case 'reset':
                      await _reset(context);
                  }
                  onChanged();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset access'),
                  ),
                  PopupMenuItem(
                    value: 'deactivate',
                    child: Text(
                      inactive ? 'Reactivate not available' : 'Deactivate',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, bool alreadyInactive) async {
    if (alreadyInactive) {
      showMessage(
        context,
        'This admin is already inactive. Contact the platform team to restore.',
      );
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Deactivate ${admin.name}?',
      message:
          'Their sessions are revoked immediately and they cannot sign in as an '
          'administrator until you re-activate them.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await AppServices.instance.admin.deactivateAdmin(admin.id);
      if (context.mounted) showMessage(context, 'Admin deactivated.');
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }

  Future<void> _reset(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Reset access for ${admin.name}?',
      message:
          'A temporary password is generated and every session is revoked. '
          'They must change the password at next sign-in.',
      confirmLabel: 'Reset access',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      final result = await AppServices.instance.admin.resetAdminAccess(
        admin.id,
      );
      if (!context.mounted) return;
      final temp = result['temporaryPassword'] as String?;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Tokens.surface,
          title: Text('Temporary password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                temp == null || temp.isEmpty
                    ? 'The password was rotated.'
                    : temp,
                style: const TextStyle(
                  fontFamily: Tokens.fontMono,
                  fontSize: Tokens.typeMd,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: Tokens.space3),
              Text(
                'Pass it to the admin over a channel you trust. It works once.',
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeXs,
                  height: 1.4,
                  color: Tokens.inkMuted,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(backgroundColor: Tokens.accent),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', error: true);
    }
  }
}

class AdminCreateScreen extends StatefulWidget {
  const AdminCreateScreen({super.key});

  @override
  State<AdminCreateScreen> createState() => _AdminCreateScreenState();
}

class _AdminCreateScreenState extends State<AdminCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _designation = TextEditingController();

  List<Role>? _roles;
  Role? _role;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    AppServices.instance.admin
        .roles()
        .then((roles) {
          if (!mounted) return;
          setState(() {
            _roles = roles;
            _role = roles.isNotEmpty ? roles.first : null;
          });
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _roles = const <Role>[]);
        });
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _designation.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.admin.createAdmin(
        name: _name.text.trim(),
        mobile: _mobile.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        roleId: _role!.id,
        designation: _designation.text.trim().isEmpty
            ? null
            : _designation.text.trim(),
      );
      if (!mounted) return;
      showMessage(
        context,
        'Administrator created. A temporary password has been set.',
      );
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
      title: 'New administrator',
      subtitle: 'Creates an account with a temporary password',
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
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                ),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _designation,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Designation (optional)',
                  hintText: 'Facility manager',
                ),
              ),
            ),
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Role',
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
              child: _roles == null
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Tokens.surfaceSunken,
                      color: Tokens.accent,
                    )
                  : _roles!.isEmpty
                  ? Text(
                      'No roles defined yet. Create a role first under '
                      'More → Roles and permissions.',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeXs,
                        height: 1.5,
                        color: Tokens.inkMuted,
                      ),
                    )
                  : Wrap(
                      spacing: Tokens.space2,
                      runSpacing: Tokens.space2,
                      children: [
                        for (final role in _roles!)
                          _Choice(
                            label: role.name,
                            selected: role.id == _role?.id,
                            onTap: () => setState(() => _role = role),
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
                onPressed: _busy || _roles == null || _roles!.isEmpty
                    ? null
                    : _create,
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
                    : const Text('Create administrator'),
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
