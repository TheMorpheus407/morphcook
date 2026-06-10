/// A user-visible text in N languages. All display text in the corpus is one
/// of these, so adding a language is a data addition, never a schema change.
class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Map<String, dynamic> json) =>
      LocalizedText(json.map((k, v) => MapEntry(k, v as String)));

  static const empty = LocalizedText({});

  /// Resolves for [lang], falling back to English, then any value.
  String of(String lang) =>
      values[lang] ??
      values['en'] ??
      (values.isEmpty ? '' : values.values.first);

  bool get isEmpty => values.isEmpty;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(values);
}

/// Per-language string lists (e.g. tags).
class LocalizedList {
  final Map<String, List<String>> values;

  const LocalizedList(this.values);

  factory LocalizedList.fromJson(Map<String, dynamic> json) => LocalizedList(
      json.map((k, v) => MapEntry(k, List<String>.from(v as List))));

  static const empty = LocalizedList({});

  List<String> of(String lang) =>
      values[lang] ?? values['en'] ?? const <String>[];

  /// All values across languages (for search indexing).
  Iterable<String> get all => values.values.expand((v) => v);
}
