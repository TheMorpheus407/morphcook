import 'dart:ui';

class LocalizedText {
  const LocalizedText(this.values);

  factory LocalizedText.fromJson(Object? value) {
    if (value is String) return LocalizedText({'en': value, 'de': value});
    if (value is Map) {
      return LocalizedText(
        value.map(
          (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
        ),
      );
    }
    return const LocalizedText({'en': '', 'de': ''});
  }

  final Map<String, String> values;

  String of(Locale locale) {
    final language = locale.languageCode.toLowerCase();
    return values[language] ??
        values.entries
            .firstWhere(
              (entry) => entry.key.toLowerCase().split('-').first == language,
              orElse: () => values.entries.firstWhere(
                (entry) => entry.key == 'en',
                orElse: () => values.entries.first,
              ),
            )
            .value;
  }

  String operator [](String language) => of(Locale(language));

  Map<String, String> toJson() => values;
}

Map<String, String> stringMap(Object? value) =>
    LocalizedText.fromJson(value).values;

List<String> stringList(Object? value) =>
    value is List ? value.map((item) => item.toString()).toList() : const [];

Map<String, String> dimensionsFromJson(Object? value) => value is Map
    ? value.map((key, value) => MapEntry(key.toString(), value.toString()))
    : const {};
