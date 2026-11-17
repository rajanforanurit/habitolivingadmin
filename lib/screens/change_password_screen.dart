import 'package:flutter/material.dart';

import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/spacing.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'package:habitoliving_shared/ui/widgets/app_scaffold.dart';
import 'package:habitoliving_shared/ui/widgets/states.dart';
import '../app.dart';

/// Change password.
///
/// The backend verifies the current password before setting a new one, so the
/// app asks for it too — an unlocked phone is not proof of identity.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  bool _busy = false;
  bool _showCurrent = false;
  bool _showNext = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.auth.changePassword(
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      if (!mounted) return;
      showMessage(context, 'Password changed');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Change password',
      showBack: true,
      body: ListView(
        padding: const EdgeInsets.only(
          left: Tokens.gutter,
          right: Tokens.gutter,
          bottom: kScreenBottomPadding,
        ),
        children: [
          if (_error != null) ...[
            ErrorState(message: _error!, compact: true),
            const SizedBox(height: Tokens.space3),
          ],
          Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _current,
                  obscureText: !_showCurrent,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Current password',
                    suffixIcon: IconButton(
                      icon: AppIcon(
                        _showCurrent ? Icons2.visibilityOff : Icons2.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _showCurrent = !_showCurrent),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: Tokens.space3),
                TextFormField(
                  controller: _next,
                  obscureText: !_showNext,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: InputDecoration(
                    labelText: 'New password',
                    helperText: 'At least 8 characters',
                    suffixIcon: IconButton(
                      icon: AppIcon(
                        _showNext ? Icons2.visibilityOff : Icons2.visibility,
                      ),
                      onPressed: () => setState(() => _showNext = !_showNext),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    if (v == _current.text) {
                      return 'Choose a different password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: Tokens.space3),
                TextFormField(
                  controller: _confirm,
                  obscureText: !_showNext,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                  validator: (v) =>
                      v != _next.text ? 'Passwords do not match' : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: Tokens.space5),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Tokens.accent,
                foregroundColor: Tokens.accentOn,
              ),
              child: Text(_busy ? 'Saving…' : 'Change password'),
            ),
          ),
        ],
      ),
    );
  }
}
