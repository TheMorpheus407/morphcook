typedef LocalizedText = Map<String, String>;

extension LocalizedTextValue on LocalizedText {
  String value(String language) =>
      this[language] ?? this['en'] ?? (isEmpty ? '' : values.first);
}

LocalizedText localizedTextFromJson(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry('$key', '$item'));
}
