/// A tiny N-language string bag.
///
/// Every user-visible string in the corpus is a `Map<lang, String>` so that
/// adding a language is a data addition and never a schema change. A bare
/// `String` is accepted as shorthand for "the same in every language".
class L10nText {
  const L10nText(this.values);

  const L10nText.same(String value)
      : values = const <String, String>{};

  factory L10nText.fromJson(Object? json) {
    if (json == null) return const L10nText(<String, String>{});
    if (json is String) return L10nText.same(json);
    if (json is Map) {
      final map = <String, String>{};
      json.forEach((key, value) {
        if (value is String) map['$key'] = value;
      });
      return L10nText(map);
    }
    return const L10nText(<String, String>{});
  }

  final Map<String, String> values;

  bool get isEmpty => values.isEmpty;

  /// Resolves [lang], falling back to English and then to any available
  /// translation so the UI never renders a blank line.
  String resolve(String lang) {
    if (values.isEmpty) return '';
    final direct = values[lang];
    if (direct != null && direct.isNotEmpty) return direct;
    final english = values['en'];
    if (english != null && english.isNotEmpty) return english;
    for (final entry in values.values) {
      if (entry.isNotEmpty) return entry;
    }
    return '';
  }

  String call(String lang) => resolve(lang);

  Map<String, dynamic> toJson() => <String, dynamic>{...values};

  @override
  String toString() => 'L10nText(${values.length})';
}
