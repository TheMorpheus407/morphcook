/// Language support. The data model is N-language-ready: every user-visible
/// string is a `Map<lang, String>`. Adding a language is a data addition.
enum AppLang {
  en,
  de;

  String get code => name;

  static AppLang fromCode(String? code) {
    switch (code) {
      case 'de':
        return AppLang.de;
      case 'en':
      default:
        return AppLang.en;
    }
  }
}

/// A localized string: `{ "en": "...", "de": "..." }`. Falls back across
/// languages so a missing translation never renders blank.
class LocalizedText {
  const LocalizedText(this._values);

  final Map<String, String> _values;

  factory LocalizedText.fromJson(dynamic json) {
    if (json == null) return const LocalizedText({});
    if (json is String) return LocalizedText({'en': json, 'de': json});
    return LocalizedText(Map<String, String>.from(json as Map));
  }

  /// Resolve for [lang], falling back to EN, then any available value.
  String resolve(AppLang lang) {
    final v = _values[lang.code];
    if (v != null && v.isNotEmpty) return v;
    final en = _values['en'];
    if (en != null && en.isNotEmpty) return en;
    return _values.values.isNotEmpty ? _values.values.first : '';
  }

  String? maybe(AppLang lang) => _values[lang.code];

  Map<String, String> toJson() => _values;

  bool get isEmpty => _values.isEmpty;

  /// All values lowercased — used to build the search index across languages.
  Iterable<String> get allValues => _values.values;
}
