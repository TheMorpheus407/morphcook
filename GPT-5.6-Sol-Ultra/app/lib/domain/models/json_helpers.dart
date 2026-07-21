int jsonInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double jsonDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool jsonBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  switch (value?.toString().trim().toLowerCase()) {
    case 'true':
    case 'yes':
    case '1':
      return true;
    case 'false':
    case 'no':
    case '0':
      return false;
    default:
      return fallback;
  }
}

String jsonString(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;

List<Object?> jsonList(Object? value) =>
    value is List ? List<Object?>.from(value) : const [];

Map<String, Object?> jsonMap(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) '${entry.key}': entry.value};
}

Set<String> jsonStringSet(Object? value) =>
    jsonList(value).map((item) => item.toString()).toSet();

List<String> jsonStringList(Object? value) =>
    jsonList(value).map((item) => item.toString()).toList();

DateTime? jsonDateTimeOrNull(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString())?.toUtc();
}

DateTime jsonDateTime(Object? value, {DateTime? fallback}) =>
    jsonDateTimeOrNull(value) ??
    fallback ??
    DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
