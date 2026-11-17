import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:habitoliving_shared/services/api_client.dart';
import 'package:habitoliving_shared/services/app_services.dart';
import 'package:habitoliving_shared/ui/icons.dart';
import 'package:habitoliving_shared/ui/tokens.dart';
import '../forgot_password_screen.dart';

/// Sign in.
///
/// Two methods, one screen: password and OTP. The layout keeps a single column
/// so a phone keyboard never has to fight for space, and the brand sits at the
/// top as a wordmark rather than a stock icon.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();

  bool _useOtp = false;
  bool _otpSent = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;
  String? _devOtp;

  @override
  void initState() {
    super.initState();
    // If the stored session could not be validated because the backend was
    // unreachable, say so instead of leaving a silent login form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final err = AppServices.instance.auth.startupConnectivityError;
      if (err != null) setState(() => _error = err);
    });
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _otp.dispose();
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
      if (_useOtp) {
        await _otpFlow();
      } else {
        await AppServices.instance.auth.loginWithPassword(
          _identifier.text.trim(),
          _password.text,
        );
      }
      if (!mounted) return;
      AppServices.instance.attachSession();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Could not reach the server.\n'
              'Start the backend, then run:\nadb reverse tcp:4000 tcp:4000',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _otpFlow() async {
    if (!_otpSent) {
      final result = await AppServices.instance.auth.requestOtp(
        _identifier.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _devOtp = result.devOtp;
        if (result.hasDevOtp) _otp.text = result.devOtp!;
      });
      return;
    }
    await AppServices.instance.auth.loginWithOtp(
      _identifier.text.trim(),
      _otp.text.trim(),
    );
  }

  void _sendOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _otpFlow();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchMethod() {
    setState(() {
      _useOtp = !_useOtp;
      _otpSent = false;
      _otp.text = '';
      _devOtp = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: Tokens.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: Tokens.gutter,
              right: Tokens.gutter,
              top: Tokens.space7,
              bottom: Tokens.space7 + keyboard,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Brand(),
                    SizedBox(height: Tokens.space7),
                    Text(
                      _useOtp ? 'Sign in with a code' : 'Welcome back',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamilyFigure,
                        fontSize: Tokens.typeXl,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                        color: Tokens.ink,
                      ),
                    ),
                    SizedBox(height: Tokens.space2),
                    Text(
                      _useOtp
                          ? 'We will text a six-digit code to your mobile.'
                          : 'Sign in to see your society, visitors and dues.',
                      style: TextStyle(
                        fontFamily: Tokens.fontFamily,
                        fontSize: Tokens.typeSm,
                        height: 1.5,
                        color: Tokens.inkMuted,
                      ),
                    ),
                    SizedBox(height: Tokens.space6),

                    if (_error != null) ...[
                      _InlineError(message: _error!),
                      const SizedBox(height: Tokens.space4),
                    ],

                    _FieldLabel(text: 'Mobile or email'),
                    _TextField(
                      controller: _identifier,
                      hint: '+91 98765 43210',
                      icon: Icons2.phone,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter the mobile number or email you signed up with'
                          : null,
                    ),
                    SizedBox(height: Tokens.space4),

                    if (_useOtp) ...[
                      if (_otpSent) ...[
                        _FieldLabel(text: 'Six-digit code'),
                        _TextField(
                          controller: _otp,
                          hint: '••••••',
                          icon: Icons2.password,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          onSubmitted: (_) => _submit(),
                          validator: (v) => (v == null || v.trim().length < 4)
                              ? 'Enter the code from the text message'
                              : null,
                        ),
                        if (_devOtp != null) ...[
                          const SizedBox(height: Tokens.space2),
                          const _DevHint(),
                        ],
                      ],
                    ] else ...[
                      Row(
                        children: [
                          _FieldLabel(text: 'Password'),
                          Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                fontFamily: Tokens.fontFamily,
                                fontSize: Tokens.typeSm,
                                fontWeight: FontWeight.w500,
                                color: Tokens.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      _TextField(
                        controller: _password,
                        hint: 'Your password',
                        icon: Icons2.password,
                        obscure: _obscure,
                        onToggleObscure: () =>
                            setState(() => _obscure = !_obscure),
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _submit(),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Enter your password'
                            : null,
                      ),
                    ],

                    const SizedBox(height: Tokens.space6),
                    _PrimaryButton(
                      label: _useOtp
                          ? (_otpSent ? 'Verify and sign in' : 'Send code')
                          : 'Sign in',
                      busy: _busy,
                      onPressed: _useOtp && !_otpSent ? _sendOtp : _submit,
                    ),

                    const SizedBox(height: Tokens.space4),
                    _SwitchRow(
                      label: _useOtp
                          ? 'Use a password instead'
                          : 'Email me a code instead',
                      onTap: _busy ? null : _switchMethod,
                    ),
                    const SizedBox(height: Tokens.space2),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Tokens.accent,
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
          alignment: Alignment.center,
          child: Text(
            'H',
            style: TextStyle(
              fontFamily: Tokens.fontFamilyFigure,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Tokens.accentOn,
            ),
          ),
        ),
        SizedBox(width: Tokens.space3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Habito Living',
              style: TextStyle(
                fontFamily: Tokens.fontFamilyFigure,
                fontSize: Tokens.typeMd,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: Tokens.ink,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Society living, organised',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                color: Tokens.inkFaint,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(
        fontFamily: Tokens.fontFamily,
        fontSize: Tokens.typeBase,
        color: Tokens.ink,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Tokens.surface,
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: Tokens.fontFamily,
          fontSize: Tokens.typeBase,
          color: Tokens.inkFaint,
        ),
        prefixIcon: AppIcon(icon, size: IconSize.row),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: AppIcon(
                  obscure ? Icons2.visibilityOff : Icons2.visibility,
                  size: IconSize.row,
                ),
              ),
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
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Tokens.controlHeight + 4,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Tokens.accent,
          disabledBackgroundColor: Tokens.lineStrong,
          foregroundColor: Tokens.accentOn,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusSm),
          ),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.accentOn,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontFamily: Tokens.fontFamily,
                  fontSize: Tokens.typeBase,
                  fontWeight: FontWeight.w600,
                  color: Tokens.accentOn,
                ),
              ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Tokens.inkMuted,
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.space2,
            vertical: Tokens.space2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Tokens.fontFamily,
            fontSize: Tokens.typeSm,
            fontWeight: FontWeight.w500,
            color: Tokens.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
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

class _DevHint extends StatelessWidget {
  const _DevHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Tokens.space3,
        vertical: Tokens.space2,
      ),
      decoration: BoxDecoration(
        color: Tokens.infoTint,
        borderRadius: BorderRadius.circular(Tokens.radiusXs),
      ),
      child: Row(
        children: [
          AppIcon(Icons2.info, size: IconSize.inline, color: Tokens.info),
          SizedBox(width: Tokens.space2),
          Expanded(
            child: Text(
              'Development build: the code is filled in for you.',
              style: TextStyle(
                fontFamily: Tokens.fontFamily,
                fontSize: Tokens.typeXs,
                color: Tokens.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
