/// Bilingual (N-ready) user-visible text: {lang: string}.
typedef LocalText = Map<String, String>;

/// Picks the best string for [lang], falling back to English, then any value.
String localize(LocalText? text, String lang) {
  if (text == null || text.isEmpty) return '';
  return text[lang] ?? text['en'] ?? text.values.first;
}

LocalText parseLocalText(dynamic json) {
  if (json is Map) {
    return json.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
  return const {};
}
