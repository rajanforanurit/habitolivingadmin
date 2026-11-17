/// Shared helpers for reading JSON from the backend.
///
/// The backend is written in TypeScript with Zod schemas, so most payloads are
/// strict. These helpers keep the parsing honest: a missing required field
/// throws a descriptive error instead of silently becoming null, while optional
/// fields degrade to a default. Where the backend is genuinely loose (records,
/// dynamic maps), [asMap] / [asList] return empty containers.
library;

/// Thrown when a payload does not match what the app expects.
class ModelParseException implements Exception {
  ModelParseException(this.field, this.reason, [this.cause]);

  final String field;
  final String reason;
  final Object? cause;

  @override
  String toString() =>
      'ModelParseException($field): $reason${cause == null ? '' : ' ($cause)'}';
}

Never _fail(String field, String reason, [Object? cause]) =>
    throw ModelParseException(field, reason, cause);

String asString(dynamic v, {String field = 'value', String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  if (v is num) return v.toString();
  _fail(field, 'expected a string, got ${v.runtimeType}');
}

String? asStringOrNull(dynamic v, {String field = 'value'}) {
  if (v == null) return null;
  if (v is String) return v;
  if (v is num) return v.toString();
  _fail(field, 'expected a string or null, got ${v.runtimeType}');
}

int asInt(dynamic v, {String field = 'value', int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final parsed = int.tryParse(v);
    return parsed ?? fallback;
  }
  _fail(field, 'expected an integer, got ${v.runtimeType}');
}

int? asIntOrNull(dynamic v, {String field = 'value'}) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double asDouble(dynamic v, {String field = 'value', double fallback = 0}) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  _fail(field, 'expected a number, got ${v.runtimeType}');
}

bool asBool(dynamic v, {String field = 'value', bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

DateTime asDate(dynamic v, {String field = 'value', DateTime? fallback}) {
  if (v == null) return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  if (v is DateTime) return v;
  if (v is String) {
    final parsed = DateTime.tryParse(v);
    if (parsed != null) return parsed;
  }
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v > 9999999999 ? v : v * 1000);
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? asDateOrNull(dynamic v, {String field = 'value'}) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v > 9999999999 ? v : v * 1000);
  }
  return null;
}

Map<String, dynamic> asMap(dynamic v, {String field = 'value'}) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val));
  }
  return const <String, dynamic>{};
}

Map<String, dynamic>? asMapOrNull(dynamic v, {String field = 'value'}) {
  if (v == null) return null;
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return null;
}

List<dynamic> asList(dynamic v, {String field = 'value'}) {
  if (v is List) return v;
  return const <dynamic>[];
}

List<Map<String, dynamic>> asMapList(dynamic v, {String field = 'value'}) {
  if (v is List) {
    return v
        .whereType<Map<dynamic, dynamic>>()
        .map((e) => e.map((k, val) => MapEntry(k.toString(), val)))
        .toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

/// A nested object that must exist.
Map<String, dynamic> reqMap(dynamic v, {required String field}) {
  final m = asMapOrNull(v);
  if (m == null) _fail(field, 'expected an object, got ${v.runtimeType}');
  return m;
}

String reqString(dynamic v, {required String field}) {
  final s = asStringOrNull(v);
  if (s == null) _fail(field, 'missing required string');
  return s;
}

/// Reads a value that may be present under more than one key.
///
/// The backend occasionally nests an entity as `{userId: "...", user: {...}}`.
/// This keeps call sites readable instead of scattering `??` chains.
T pick<T>(
  Map<String, dynamic> json,
  List<String> keys,
  T Function(dynamic) read,
) {
  for (final k in keys) {
    if (json.containsKey(k) && json[k] != null) return read(json[k]);
  }
  return read(null);
}

String pickString(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  return pick(json, keys, (v) => asString(v, fallback: fallback));
}

String? pickStringOrNull(Map<String, dynamic> json, List<String> keys) {
  return pick(json, keys, asStringOrNull);
}

int pickInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  return pick(json, keys, (v) => asInt(v, fallback: fallback));
}

double pickDouble(
  Map<String, dynamic> json,
  List<String> keys, {
  double fallback = 0,
}) {
  return pick(json, keys, (v) => asDouble(v, fallback: fallback));
}

bool pickBool(
  Map<String, dynamic> json,
  List<String> keys, {
  bool fallback = false,
}) {
  return pick(json, keys, (v) => asBool(v, fallback: fallback));
}

/// A paginated payload. The backend returns
/// `{ success, data: [...], meta: { page, limit, total, totalPages } }`.
class PageResult<T> {
  const PageResult({
    required this.items,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  final List<T> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  bool get hasMore => page < totalPages;

  /// The next page number, or null when there is nothing more to load.
  int? get nextPage => hasMore ? page + 1 : null;

  factory PageResult.from(
    dynamic data,
    dynamic meta,
    T Function(Map<String, dynamic>) parse,
  ) {
    final m = asMap(meta);
    return PageResult<T>(
      items: asMapList(data).map(parse).toList(growable: false),
      page: asInt(m['page'], fallback: 1),
      limit: asInt(m['limit'], fallback: 20),
      total: asInt(m['total']),
      totalPages: asInt(m['totalPages']),
    );
  }

  static PageResult<T> empty<T>() => PageResult<T>(items: const []);
}

/// Converts a status-ish string to a readable label.
String humanize(String value) {
  if (value.isEmpty) return '';
  final words = value
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((w) => w.isNotEmpty);
  return words
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

/// Builds a display name from a first/last pair when the backend has no single
/// name field.
String joinName(String? first, String? last) {
  final parts = [first, last].where((p) => p != null && p.trim().isNotEmpty);
  return parts.join(' ').trim();
}

/// Reads a key from a value that may be null or not a map.
///
/// Use this for optional nested objects (`address`, `actor`, `role`) so call
/// sites stay readable: `at(json['address'], 'city')`.
dynamic at(dynamic map, String key) {
  if (map is Map) return map[key];
  return null;
}

/// Reads a nested map that may be absent.
Map<String, dynamic> sub(dynamic map) =>
    asMapOrNull(map) ?? const <String, dynamic>{};

/// Reads a numeric value that may be absent.
double? asDoubleOrNull(dynamic v, {String field = 'value'}) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}
