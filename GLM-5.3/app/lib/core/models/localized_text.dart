/// A localized text value: `Map<lang, String>` per the SPEC ("all user-visible
/// text is `Map<lang, String>` so adding a language is a data addition,
/// never a schema change").
typedef LocalizedText = Map<String, String>;

/// Reads a localized value with graceful fallback: requested language →
/// english → first available → `fallback`.
String lt(LocalizedText? text, String lang, [String fallback = '']) {
  if (text == null) return fallback;
  return text[lang] ?? text['en'] ?? (text.isEmpty ? fallback : text.values.first);
}

/// Parses a `Map<String, dynamic>` known to hold a `Map<String, String>`.
LocalizedText parseLocalized(dynamic raw) {
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  return <String, String>{};
}
