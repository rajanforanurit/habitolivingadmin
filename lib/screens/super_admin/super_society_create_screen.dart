import 'package:flutter/material.dart';

import '../../app.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/primitives.dart';
import '../widgets/future_body.dart';
import '../widgets/property_info_form.dart';
import '../widgets/validators.dart';

/// Onboard a society: its details, the society admin's sign-in credentials,
/// the property type and layout (towers and their flats, or houses) and hospitals.
///
/// The Super Admin owns the property and hospital data. Once saved, the
/// society admin can read it but not change or delete it.
class SuperSocietyCreateScreen extends StatefulWidget {
  const SuperSocietyCreateScreen({super.key});

  @override
  State<SuperSocietyCreateScreen> createState() => _SuperSocietyCreateScreenState();
}

class _SuperSocietyCreateScreenState extends State<SuperSocietyCreateScreen> {
  final _form = GlobalKey<FormState>();
  final _property = GlobalKey<PropertyInfoEditorState>();

  final _name = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _address = TextEditingController();
  final _adminName = TextEditingController();
  final _adminMobile = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPassword = TextEditingController();

  bool _showPassword = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _city, _state, _address, _adminName, _adminMobile, _adminEmail, _adminPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => Validators.required(v);

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final editor = _property.currentState;
    final propertyProblem = editor?.validate();
    if (editor == null || propertyProblem != null) {
      setState(() => _error = propertyProblem ?? 'Configure the property first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.superAdmin.createSociety(
        name: _name.text.trim(),
        propertyType: editor.propertyType!,
        city: _city.text.trim(),
        state: _state.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        adminName: _adminName.text.trim(),
        adminMobile: _adminMobile.text.trim(),
        adminEmail: _adminEmail.text.trim().isEmpty ? null : _adminEmail.text.trim(),
        adminPassword: _adminPassword.text,
        propertyDetails: editor.details,
        hospitals: editor.hospitals,
      );
      if (!mounted) return;
      showMessage(context, 'Society created. The administrator can sign in now.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _gap() => const SizedBox(height: Tokens.space3);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'New society',
      subtitle: 'Society, administrator and property',
      bottom: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Tokens.space5),
          child: FilledButton(
            // Stays disabled until every tower (or the house block) is fully configured.
            onPressed: (_busy || !(_property.currentState?.isLayoutComplete ?? false)) ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: Tokens.accent,
              foregroundColor: Tokens.accentOn,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create society'),
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel('Society'),
            const SizedBox(height: Tokens.space2),
            TextFormField(controller: _name, validator: _required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Society name')),
            _gap(),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _city, validator: _required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'City'))),
                const SizedBox(width: Tokens.space3),
                Expanded(child: TextFormField(controller: _state, validator: _required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'State'))),
              ],
            ),
            _gap(),
            TextFormField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address (optional)')),
            const SizedBox(height: Tokens.space6),
            const SectionLabel('Society administrator'),
            const SizedBox(height: Tokens.space2),
            Text(
              'These are the credentials the administrator signs in with. They can create guards, other administrators and helpdesk contacts afterwards.',
              style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.inkMuted, height: 1.4),
            ),
            _gap(),
            TextFormField(controller: _adminName, validator: _required, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name')),
            _gap(),
            TextFormField(
              controller: _adminMobile,
              keyboardType: TextInputType.phone,
              validator: Validators.mobile,
              decoration: const InputDecoration(labelText: 'Mobile number (login)'),
            ),
            _gap(),
            TextFormField(
              controller: _adminEmail,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.optionalEmail,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            _gap(),
            TextFormField(
              controller: _adminPassword,
              obscureText: !_showPassword,
              validator: Validators.password,
              decoration: InputDecoration(
                labelText: 'Initial password',
                helperText: 'Share it securely. The administrator can change it after signing in.',
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: Tokens.space6),
            PropertyInfoEditor(
              key: _property,
              initialPropertyName: null,
              onChanged: () => setState(() {}),
            ),
            if (!(_property.currentState?.isLayoutComplete ?? false)) ...[
              const SizedBox(height: Tokens.space3),
              Text(
                _property.currentState?.validate() ?? 'Choose a property type and configure it to continue.',
                style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.warning),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: Tokens.space4),
              Text(_error!, style: TextStyle(fontFamily: Tokens.fontFamily, fontSize: Tokens.typeSm, color: Tokens.danger)),
            ],
            const SizedBox(height: Tokens.space6),
          ],
        ),
      ),
    );
  }
}
