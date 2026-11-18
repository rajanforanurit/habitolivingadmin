/// Client-side checks that mirror the backend's rules, so a field is flagged
/// before the request is sent. The backend stays the authority.
class Validators {
  Validators._();

  static String? required(String? v, [int min = 2]) =>
      (v == null || v.trim().length < min) ? 'Required' : null;

  /// Same rule as the backend: optional `+`, then 9–17 digits, spaces or hyphens.
  static String? mobile(String? v) =>
      RegExp(r'^\+?[1-9][\d\s-]{8,16}$').hasMatch((v ?? '').trim())
      ? null
      : 'Enter a valid mobile number';

  static String? optionalEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Enter a valid email';
  }

  /// 8–72 characters with a lowercase letter, an uppercase letter and a digit.
  static String? password(String? v) {
    final t = v ?? '';
    if (t.length < 8) return 'At least 8 characters';
    if (t.length > 72) return 'At most 72 characters';
    if (!RegExp(r'[a-z]').hasMatch(t)) return 'Add a lowercase letter';
    if (!RegExp(r'[A-Z]').hasMatch(t)) return 'Add an uppercase letter';
    if (!RegExp(r'\d').hasMatch(t)) return 'Add a digit';
    return null;
  }
}
