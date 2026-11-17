import 'package:flutter/material.dart';

import 'package:habitoliving_shared/models/admin.dart';
import 'package:habitoliving_shared/models/json.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/services/format.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import 'package:habitoliving_shared/ui/widgets/status.dart';

/// Vendors: the outside companies the society hires.
///
/// Distinct from staff, who are employed directly. A vendor is the agency —
/// security contractor, lift AMC, waste removal — and the person to call when
/// the lift is stuck at 11 PM.
class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});

  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  int _revision = 0;
  late Future<PageResult<Vendor>> _vendors = _load();

  Future<PageResult<Vendor>> _load() =>
      AppServices.instance.admin.vendors(limit: 50);

  void _reload() => setState(() {
    _vendors = _load();
    _revision++;
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Vendors',
      subtitle: 'Outside companies on contract',
      floatingAction: FloatingActionButton(
        onPressed: () async {
          final ok = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const VendorEditScreen()),
          );
          if (ok == true) _reload();
        },
        backgroundColor: Tokens.accent,
        foregroundColor: Tokens.accentOn,
        child: const AppIcon(Icons2.add, size: IconSize.hero),
      ),
      body: FutureBuilder<PageResult<Vendor>>(
        key: ValueKey(_revision),
        future: _vendors,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingList();
          }
          if (snapshot.hasError) {
            return ErrorState(message: '${snapshot.error}', onRetry: _reload);
          }
          final items = snapshot.data?.items ?? const <Vendor>[];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons2.vendors,
              title: 'No vendors yet',
              message:
                  'Keep the security contractor, the lift AMC and the waste '
                  'contract here, with the phone number to call when it breaks.',
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
                      vendor: items[i],
                      onTap: () async {
                        final ok = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => VendorEditScreen(vendor: items[i]),
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
  const _Card({required this.vendor, required this.onTap});

  final Vendor vendor;
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
                color: Tokens.accentTint,
                borderRadius: BorderRadius.circular(Tokens.radiusSm),
              ),
              child: Center(
                child: AppIcon(
                  Icons2.vendors,
                  size: IconSize.row,
                  color: Tokens.accent,
                ),
              ),
            ),
            SizedBox(width: Tokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.name,
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
                      vendor.category,
                      if (vendor.contactName != null) vendor.contactName!,
                      if (vendor.phone != null) vendor.phone!,
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
              vendor.status,
              domain: StatusDomain.generic,
              dot: false,
            ),
          ],
        ),
      ),
    );
  }
}

class VendorEditScreen extends StatefulWidget {
  const VendorEditScreen({super.key, this.vendor});

  final Vendor? vendor;

  @override
  State<VendorEditScreen> createState() => _VendorEditScreenState();
}

class _VendorEditScreenState extends State<VendorEditScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;

  String _category = 'SECURITY';
  bool _busy = false;
  String? _error;

  static final _categories = <(String, String)>[
    ('SECURITY', 'Security'),
    ('CLEANING', 'Cleaning'),
    ('ELECTRICAL', 'Electrical'),
    ('PLUMBING', 'Plumbing'),
    ('LIFT', 'Lift'),
    ('GARDEN', 'Garden'),
    ('WASTE', 'Waste'),
    ('PEST', 'Pest'),
    ('OTHER', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vendor;
    _name = TextEditingController(text: v?.name ?? '');
    _contact = TextEditingController(text: v?.contactName ?? '');
    _phone = TextEditingController(text: v?.phone ?? '');
    _email = TextEditingController(text: v?.email ?? '');
    if (v != null) {
      _category = v.category.toUpperCase().replaceAll(' ', '_');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
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
      if (widget.vendor == null) {
        await admin.createVendor(
          name: _name.text.trim(),
          category: _category,
          contactName: _contact.text.trim().isEmpty
              ? null
              : _contact.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        );
      } else {
        await admin.updateVendor(widget.vendor!.id, {
          'name': _name.text.trim(),
          'category': _category,
          'contactName': _contact.text.trim(),
          'phone': _phone.text.trim(),
          'email': _email.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final editing = widget.vendor != null;
    return AppScaffold(
      title: editing ? 'Edit vendor' : 'New vendor',
      subtitle: editing ? widget.vendor!.name : 'A company on contract',
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
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter the company name'
                    : null,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
            ),
            SizedBox(height: Tokens.space4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: TextFormField(
                controller: _contact,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Contact person (optional)',
                ),
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
            SizedBox(height: Tokens.space3),
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
            SizedBox(height: Tokens.space5),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Tokens.space4),
              child: Text(
                'Category',
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
                  for (final (value, label) in _categories)
                    _Choice(
                      label: label,
                      selected: value == _category,
                      onTap: () => setState(() => _category = value),
                    ),
                ],
              ),
            ),
            if (editing && widget.vendor!.contractUntil != null) ...[
              const SizedBox(height: Tokens.space4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.space4),
                child: ListRow(
                  title: 'Contract until',
                  subtitle: Fmt.dateFull(widget.vendor!.contractUntil),
                  icon: Icons2.calendar,
                ),
              ),
            ],
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
                    : Text(editing ? 'Save vendor' : 'Add vendor'),
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
