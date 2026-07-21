import 'package:collection/collection.dart';

/// Language-neutral user-visible copy.
///
/// Locale keys are normalized to their primary, lower-case language subtag so
/// both `de-DE` and `de_DE` resolve to `de` without changing the corpus schema.
class LocalizedText {
  LocalizedText(Map<String, String> values)
    : values = UnmodifiableMapView({
        for (final entry in values.entries)
          normalizeLanguageCode(entry.key): entry.value,
      });

  factory LocalizedText.fromJson(Object? json) {
    if (json is String) return LocalizedText({'en': json});
    if (json is! Map) return LocalizedText(const {});
    return LocalizedText({
      for (final entry in json.entries)
        entry.key.toString(): entry.value?.toString() ?? '',
    });
  }

  static const fallbackLanguage = 'en';

  final Map<String, String> values;

  bool get isEmpty => values.values.every((value) => value.trim().isEmpty);

  String resolve(String languageCode, {String fallback = fallbackLanguage}) {
    final normalized = normalizeLanguageCode(languageCode);
    final fallbackCode = normalizeLanguageCode(fallback);
    return values[normalized] ??
        values[fallbackCode] ??
        values.values.firstOrNull ??
        '';
  }

  String operator [](String languageCode) => resolve(languageCode);

  Map<String, dynamic> toJson() => Map<String, String>.from(values);

  LocalizedText merge(LocalizedText other) =>
      LocalizedText({...values, ...other.values});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText &&
          const MapEquality<String, String>().equals(values, other.values);

  @override
  int get hashCode => const MapEquality<String, String>().hash(values);

  @override
  String toString() => values.toString();
}

String normalizeLanguageCode(String code) =>
    code.trim().toLowerCase().replaceAll('_', '-').split('-').first;
