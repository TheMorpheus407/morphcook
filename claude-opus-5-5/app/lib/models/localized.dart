/// All user-visible corpus text is a `Map<lang, String>`, so adding a
/// language is a data change, never a schema change.
class LText {
  const LText(this.values);

  factory LText.fromJson(Object? json) {
    if (json is Map) {
      return LText({for (final e in json.entries) e.key.toString(): e.value.toString()});
    }
    if (json is String) return LText({'en': json});
    return const LText({});
  }

  static const empty = LText({});

  final Map<String, String> values;

  /// Resolves [lang], falling back to English, then to any language.
  String of(String lang) => values[lang] ?? values['en'] ?? (values.isEmpty ? '' : values.values.first);

  bool get isEmpty => values.isEmpty;

  Map<String, String> toJson() => values;

  @override
  String toString() => of('en');
}
