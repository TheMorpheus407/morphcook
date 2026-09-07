/// Localised text: every user-visible string in the corpus is a map of
/// language code → text. Adding a language is a data addition, never a
/// schema change.
class LText {
  const LText(this.values) : _single = null;

  const LText.single(String text) : values = const {}, _single = text;

  final Map<String, String> values;
  final String? _single;

  static const LText empty = LText({});

  factory LText.fromJson(Object? json) {
    if (json == null) return empty;
    if (json is String) return LText({'en': json});
    if (json is Map) {
      return LText(json.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')));
    }
    return empty;
  }

  /// Text for [lang], falling back to English, then to any available value.
  String of(String lang) {
    if (_single != null) return _single;
    final direct = values[lang];
    if (direct != null && direct.isNotEmpty) return direct;
    final en = values['en'];
    if (en != null && en.isNotEmpty) return en;
    for (final v in values.values) {
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  bool get isEmpty => _single == null && values.values.every((v) => v.isEmpty);
  bool get isNotEmpty => !isEmpty;

  Iterable<String> get languages => values.keys;

  Map<String, String> toJson() =>
      _single != null ? {'en': _single} : Map<String, String>.from(values);

  @override
  String toString() => of('en');
}
