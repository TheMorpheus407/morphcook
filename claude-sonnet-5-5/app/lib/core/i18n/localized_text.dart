/// User-visible text as `Map<lang, String>`.
///
/// Every string in the bundled corpus is stored this way so that adding a
/// language is a data addition and never a schema change.
class LocalizedText {
  const LocalizedText(this.values);

  static const LocalizedText empty = LocalizedText(<String, String>{});

  final Map<String, String> values;

  /// Accepts `{"en": "...", "de": "..."}`, a bare string (treated as English)
  /// or `null`.
  factory LocalizedText.fromJson(Object? json) {
    if (json == null) return empty;
    if (json is String) return LocalizedText(<String, String>{'en': json});
    if (json is Map) {
      return LocalizedText(<String, String>{
        for (final entry in json.entries) entry.key.toString(): entry.value.toString(),
      });
    }
    throw FormatException('Cannot read localized text from ${json.runtimeType}');
  }

  /// Resolves [lang], then [fallbackLang], then the first non-empty value.
  String resolve(String lang, {String fallbackLang = 'en'}) {
    final direct = values[lang];
    if (direct != null && direct.isNotEmpty) return direct;
    final fallback = values[fallbackLang];
    if (fallback != null && fallback.isNotEmpty) return fallback;
    for (final value in values.values) {
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String operator [](String lang) => resolve(lang);

  bool get isEmpty => values.values.every((v) => v.isEmpty);
  bool get isNotEmpty => !isEmpty;

  Iterable<String> get languages => values.keys;

  bool hasLanguage(String lang) => (values[lang] ?? '').isNotEmpty;

  Map<String, String> toJson() => Map<String, String>.of(values);

  @override
  bool operator ==(Object other) {
    if (other is! LocalizedText) return false;
    if (other.values.length != values.length) return false;
    for (final entry in values.entries) {
      if (other.values[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(values.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => 'LocalizedText($values)';
}
