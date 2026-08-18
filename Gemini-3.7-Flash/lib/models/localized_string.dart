class LocalizedString {
  final Map<String, String> values;

  const LocalizedString(this.values);

  factory LocalizedString.fromJson(dynamic json) {
    if (json is Map) {
      return LocalizedString(
        json.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    } else if (json is String) {
      return LocalizedString({'en': json, 'de': json});
    }
    return const LocalizedString({});
  }

  Map<String, dynamic> toJson() => values;

  String get(String lang) {
    return values[lang] ?? values['en'] ?? values['de'] ?? (values.isNotEmpty ? values.values.first : '');
  }

  String en() => get('en');
  String de() => get('de');

  @override
  String toString() => values['en'] ?? (values.isNotEmpty ? values.values.first : '');
}
