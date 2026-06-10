/// All user-visible text is `Map<lang, String>` per spec: N-language-ready.
/// Adding a language is a data addition, never a schema change.
class Localized {
  final Map<String, String> values;
  const Localized(this.values);

  factory Localized.fromJson(dynamic raw) {
    if (raw == null) return const Localized({});
    if (raw is String) return Localized({'en': raw, 'de': raw});
    final m = (raw as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
    return Localized(m);
  }

  String get(String lang, {String fallback = 'en'}) {
    if (values.containsKey(lang)) return values[lang]!;
    if (values.containsKey(fallback)) return values[fallback]!;
    if (values.isNotEmpty) return values.values.first;
    return '';
  }

  Map<String, dynamic> toJson() => values;
}
