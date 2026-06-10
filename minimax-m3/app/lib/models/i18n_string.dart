/// A bilingual (or N-language) display string.
///
/// Keys are language codes ('en', 'de'). We never throw if the requested
/// language is missing — we fall back to English, then to the first available
/// entry, then to an empty string.
class I18nString {
  final Map<String, String> values;

  const I18nString(this.values);

  factory I18nString.fromAny(Object? raw) {
    if (raw == null) return const I18nString({});
    if (raw is String) return I18nString({'en': raw, 'de': raw});
    if (raw is Map) {
      return I18nString(
        raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
      );
    }
    return const I18nString({});
  }

  String resolve(String lang) {
    final v = values[lang];
    if (v != null && v.isNotEmpty) return v;
    final en = values['en'];
    if (en != null && en.isNotEmpty) return en;
    if (values.isEmpty) return '';
    return values.values.first;
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);

  bool get isEmpty => values.isEmpty || values.values.every((v) => v.isEmpty);
}
