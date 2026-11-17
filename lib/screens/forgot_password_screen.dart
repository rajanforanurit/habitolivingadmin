import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:habitoliving_shared/services/api_client.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import 'auth/login_screen.dart';

/// Forgot password: request a reset code.
///
/// Step one of two. The user enters their mobile, gets a code by SMS, and moves
/// to [ResetPasswordScreen] to choose a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobile = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _devOtp;
  String? _sentMessage;

  @override
  void dispose() {
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await AppServices.instance.auth.requestPasswordReset(
        _mobile.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _sentMessage = result.message;
        _devOtp = result.devOtp;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      appBar: AppBar(
        backgroundColor: Tokens.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const AppIcon(Icons2.back, size: IconSize.header),
        ),
        title: Text(
          'Reset password',
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeMd,
            fontWeight: FontWeight.w600,
            color: Tokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Tokens.gutter),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: Tokens.space4),
                Text(
                  'We will text a code to reset your password.',
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    height: 1.5,
                    color: Tokens.inkMuted,
                  ),
                ),
                SizedBox(height: Tokens.space6),
                if (_error != null) ...[
                  _ErrorBox(message: _error!),
                  const SizedBox(height: Tokens.space4),
                ],
                _Label(text: 'Mobile number'),
                TextFormField(
                  controller: _mobile,
                  keyboardType: TextInputType.phone,
                  autofillHints: [AutofillHints.telephoneNumber],
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeBase,
                    color: Tokens.ink,
                  ),
                  decoration: fieldDecoration(
                    hint: '+91 98765 43210',
                    icon: Icons2.phone,
                  ),
                  validator: (v) => (v == null || v.trim().length < 6)
                      ? 'Enter the mobile number on your account'
                      : null,
                ),
                if (_sentMessage != null) ...[
                  const SizedBox(height: Tokens.space4),
                  _SentBox(message: _sentMessage!, devOtp: _devOtp),
                ],
                SizedBox(height: Tokens.space6),
                SizedBox(
                  height: Tokens.controlHeight + 4,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Tokens.accent,
                      disabledBackgroundColor: Tokens.lineStrong,
                      foregroundColor: Tokens.accentOn,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      ),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Tokens.accentOn,
                            ),
                          )
                        : Text(
                            'Send reset code',
                            style: TextStyle(
                              fontFamily: Tokens.fontFamily,
                              fontSize: Tokens.typeBase,
                              fontWeight: FontWeight.w600,
                              color: Tokens.accentOn,
                            ),
                          ),
                  ),
                ),
                if (_sentMessage != null && _devOtp != null) ...[
                  SizedBox(height: Tokens.space3),
                  SizedBox(
                    height: Tokens.controlHeight + 4,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ResetPasswordScreen(
                            mobile: _mobile.text.trim(),
                            initialOtp: _devOtp,
                          ),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Tokens.ink,
                        side: BorderSide(color: Tokens.lineStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusSm),
                        ),
                      ),
                      child: const Text(
                        'Continue to new password',
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeBase,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Step two: choose a new password with the code from step one.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.mobile, this.initialOtp});

  final String mobile;
  final String? initialOtp;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _otp = TextEditingController(
    text: widget.initialOtp ?? '',
  );
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (_password.text != _confirm.text) {
      setState(() => _error = 'The two passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.instance.auth.resetPassword(
        mobile: widget.mobile,
        otp: _otp.text.trim(),
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(
        () => _done = 'Password updated. Sign in with your new password.',
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      appBar: AppBar(
        backgroundColor: Tokens.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const AppIcon(Icons2.back, size: IconSize.header),
        ),
        title: Text(
          'New password',
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeMd,
            fontWeight: FontWeight.w600,
            color: Tokens.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(Tokens.gutter),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: Tokens.space4),
                if (_error != null) ...[
                  _ErrorBox(message: _error!),
                  const SizedBox(height: Tokens.space4),
                ],
                if (_done != null) ...[
                  Container(
                    padding: EdgeInsets.all(Tokens.space3),
                    decoration: BoxDecoration(
                      color: Tokens.positiveTint,
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    ),
                    child: Row(
                      children: [
                        AppIcon(
                          Icons2.success,
                          size: IconSize.inline,
                          color: Tokens.positive,
                        ),
                        SizedBox(width: Tokens.space2),
                        Expanded(
                          child: Text(
                            _done!,
                            style: TextStyle(
                              fontFamily: Tokens.fontFamily,
                              fontSize: Tokens.typeSm,
                              height: 1.45,
                              color: Tokens.positive,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                ],
                _Label(text: 'Code from the text message'),
                TextFormField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeBase,
                    color: Tokens.ink,
                  ),
                  decoration: fieldDecoration(
                    hint: '••••••',
                    icon: Icons2.password,
                  ),
                  validator: (v) => (v == null || v.trim().length < 4)
                      ? 'Enter the code'
                      : null,
                ),
                SizedBox(height: Tokens.space4),
                _Label(text: 'New password'),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeBase,
                    color: Tokens.ink,
                  ),
                  decoration: fieldDecoration(
                    hint: 'At least 8 characters',
                    icon: Icons2.password,
                    suffix: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: AppIcon(
                        _obscure ? Icons2.visibilityOff : Icons2.visibility,
                        size: IconSize.row,
                      ),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 8)
                      ? 'Use at least 8 characters'
                      : null,
                ),
                SizedBox(height: Tokens.space4),
                _Label(text: 'Confirm new password'),
                TextFormField(
                  controller: _confirm,
                  obscureText: _obscure,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeBase,
                    color: Tokens.ink,
                  ),
                  decoration: fieldDecoration(
                    hint: 'Type it again',
                    icon: Icons2.password,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Confirm the password' : null,
                ),
                SizedBox(height: Tokens.space6),
                SizedBox(
                  height: Tokens.controlHeight + 4,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: Tokens.accent,
                      disabledBackgroundColor: Tokens.lineStrong,
                      foregroundColor: Tokens.accentOn,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      ),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Tokens.accentOn,
                            ),
                          )
                        : Text(
                            'Update password',
                            style: TextStyle(
                              fontFamily: Tokens.fontFamily,
                              fontSize: Tokens.typeBase,
                              fontWeight: FontWeight.w600,
                              color: Tokens.accentOn,
                            ),
                          ),
                  ),
                ),
                if (_done != null) ...[
                  SizedBox(height: Tokens.space3),
                  SizedBox(
                    height: Tokens.controlHeight + 4,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((r) => r.isFirst);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Tokens.ink,
                        side: BorderSide(color: Tokens.lineStrong),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Tokens.radiusSm),
                        ),
                      ),
                      child: const Text(
                        'Back to sign in',
                        style: TextStyle(
                          fontFamily: Tokens.fontFamily,
                          fontSize: Tokens.typeBase,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: Tokens.space2),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeSm,
          fontWeight: FontWeight.w500,
          color: Tokens.inkMuted,
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.dangerTint,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(Icons2.error, size: IconSize.inline, color: Tokens.danger),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeSm,
                height: 1.45,
                color: Tokens.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SentBox extends StatelessWidget {
  const _SentBox({required this.message, this.devOtp});
  final String message;
  final String? devOtp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(Tokens.space3),
      decoration: BoxDecoration(
        color: Tokens.infoTint,
        borderRadius: BorderRadius.circular(Tokens.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(Icons2.info, size: IconSize.inline, color: Tokens.info),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontFamily: Tokens.fontFamily,
                    fontSize: Tokens.typeSm,
                    height: 1.45,
                    color: Tokens.info,
                  ),
                ),
                if (devOtp != null) ...[
                  SizedBox(height: Tokens.space1),
                  Text(
                    'Development code: $devOtp',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeSm,
                      fontWeight: FontWeight.w600,
                      color: Tokens.info,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared input decoration for the auth forms.
InputDecoration fieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  return InputDecoration(
    filled: true,
    fillColor: Tokens.surface,
    hintText: hint,
    hintStyle: TextStyle(
      fontFamily: Tokens.fontFamily,
      fontSize: Tokens.typeBase,
      color: Tokens.inkFaint,
    ),
    prefixIcon: AppIcon(icon, size: IconSize.row),
    suffixIcon: suffix,
    contentPadding: EdgeInsets.symmetric(
      horizontal: Tokens.space4,
      vertical: Tokens.space4,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(color: Tokens.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(color: Tokens.accent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(color: Tokens.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(Tokens.radiusSm),
      borderSide: BorderSide(color: Tokens.danger, width: 1.5),
    ),
  );
}
