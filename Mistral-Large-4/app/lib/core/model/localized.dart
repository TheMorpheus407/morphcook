/// All user-visible data text is `Map<lang, String>` so adding a language is a
/// data addition, never a schema change.
class LocalizedText {
  final Map<String, String> _values;

  const LocalizedText(this._values);

  factory LocalizedText.fromJson(Map<String, dynamic> json) => LocalizedText(
        json.map((lang, value) => MapEntry(lang, value as String)),
      );

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_values);

  /// Resolve for [lang], falling back to English, then to any available value.
  String resolve(String lang) {
    final direct = _values[lang];
    if (direct != null && direct.isNotEmpty) return direct;
    final fallback = _values['en'];
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return _values.values.first;
  }

  Iterable<String> get values => _values.values;

  @override
  String toString() => resolve('en');
}
