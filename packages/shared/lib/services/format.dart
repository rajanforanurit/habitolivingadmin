import 'package:intl/intl.dart';

/// Display formatting for dates, money, phones and counts.
///
/// All user-visible formatting goes through here so the app reads consistently:
/// Indian digit grouping for money, relative dates for anything recent, and a
/// single phone format.
class Fmt {
  Fmt._();

  static final _inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  static final _inrPaise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  // ------------------------------------------------------------------ money

  /// Whole rupees, e.g. "₹12,500". Use for invoices, charges, prices.
  static String money(num? amount) {
    if (amount == null) return '—';
    if (amount == amount.roundToDouble()) return _inr.format(amount);
    return _inrPaise.format(amount);
  }

  /// Rupees without the symbol, for places the symbol is already in the label.
  static String amount(num? amount) {
    if (amount == null) return '—';
    return NumberFormat('#,##0', 'en_IN').format(amount.round());
  }

  /// Compact money for dashboards, e.g. "₹1.2L" for one lakh twenty thousand.
  static String moneyCompact(num? amount) {
    if (amount == null) return '—';
    final v = amount.toDouble();
    final abs = v.abs();
    if (abs >= 1e7) return '₹${(v / 1e7).toStringAsFixed(1)}Cr';
    if (abs >= 1e5) return '₹${(v / 1e5).toStringAsFixed(1)}L';
    if (abs >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)}k';
    return '₹${v.round()}';
  }

  // ------------------------------------------------------------------ dates

  static final _dayMonth = DateFormat('d MMM');
  static final _dayMonthYear = DateFormat('d MMM yyyy');
  static final _weekdayDayMonth = DateFormat('EEE, d MMM');
  static final _monthYear = DateFormat('MMM yyyy');
  static final _time = DateFormat('h:mm a');
  static final _dayMonthTime = DateFormat('d MMM, h:mm a');

  /// "12 Nov" for this year, "12 Nov 2024" otherwise.
  static String date(DateTime? value) {
    if (value == null) return '—';
    final now = DateTime.now();
    if (value.year == now.year) return _dayMonth.format(value);
    return _dayMonthYear.format(value);
  }

  /// Full date with year, for detail rows.
  static String dateFull(DateTime? value) =>
      value == null ? '—' : _dayMonthYear.format(value);

  /// "Wed, 12 Nov" for schedules and booking slots.
  static String weekdayDate(DateTime? value) =>
      value == null ? '—' : _weekdayDayMonth.format(value);

  /// "Nov 2026" for billing periods.
  static String monthYear(DateTime? value) =>
      value == null ? '—' : _monthYear.format(value);

  /// "3:45 PM" for gate logs and attendance.
  static String time(DateTime? value) =>
      value == null ? '—' : _time.format(value);

  /// "12 Nov, 3:45 PM" for anything that needs both.
  static String dateTime(DateTime? value) =>
      value == null ? '—' : _dayMonthTime.format(value);

  /// Relative time for feeds and notifications: "just now", "12m ago",
  /// "3h ago", "Yesterday", then a date.
  static String relative(DateTime? value) {
    if (value == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && now.day == value.day) {
      return '${diff.inHours}h ago';
    }
    if (now.day == value.day) return '${diff.inHours}h ago';
    final yesterday = now.subtract(const Duration(days: 1));
    if (value.year == yesterday.year &&
        value.month == yesterday.month &&
        value.day == yesterday.day) {
      return 'yesterday';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(value);
  }

  /// The date portion as an ISO day string, for query params the backend
  /// expects as YYYY-MM-DD.
  static String isoDay(DateTime? value) {
    if (value == null) return '';
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '${value.year}-$m-$d';
  }

  // ------------------------------------------------------------------ other

  /// Indian mobile format: "+91 98765 43210" for a 10-digit number, the
  /// original string otherwise.
  static String phone(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 10 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length > 10 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return value;
  }

  /// Uppercases a plate: "mh12ab1234" -> "MH12 AB 1234".
  static String plate(String? value) {
    if (value == null || value.trim().isEmpty) return '—';
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    if (cleaned.length >= 10) {
      return '${cleaned.substring(0, 2)} ${cleaned.substring(2, 5)} ${cleaned.substring(5, 8)} ${cleaned.substring(8)}';
    }
    return cleaned;
  }

  /// File size from bytes.
  static String fileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '—';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// A count with a singular/plural noun, e.g. "1 resident", "4 residents".
  static String count(int value, String noun) =>
      value == 1 ? '1 $noun' : '$value ${noun}s';

  /// Short initials from a name, for avatars and placeholders.
  static String initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
