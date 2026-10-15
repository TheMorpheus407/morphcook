import 'package:flutter/foundation.dart';

/// Represents user-visible text stored as `Map<lang, String>` so adding a new
/// language is purely a data addition, never a schema change.
@immutable
class LocalizedText {
  final Map<String, String> values;

  const LocalizedText(this.values);

  factory LocalizedText.fromJson(dynamic json) {
    if (json is Map) {
      return LocalizedText(
        json.map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')),
      );
    }
    if (json is String) {
      return LocalizedText({'en': json, 'de': json});
    }
    return const LocalizedText({});
  }

  Map<String, String> toJson() => Map<String, String>.from(values);

  /// Resolves the text for [lang] (e.g. 'de' or 'en'), falling back to 'en'
  /// or the first available entry.
  String resolve(String lang) {
    final normalized = lang.toLowerCase();
    if (values.containsKey(normalized) && values[normalized]!.isNotEmpty) {
      return values[normalized]!;
    }
    if (values.containsKey('en') && values['en']!.isNotEmpty) {
      return values['en']!;
    }
    if (values.isNotEmpty) {
      return values.values.first;
    }
    return '';
  }

  String operator [](String lang) => resolve(lang);

  Iterable<String> get allTranslations => values.values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText && mapEquals(values, other.values);

  @override
  int get hashCode =>
      Object.hashAll(values.entries.map((e) => Object.hash(e.key, e.value)));

  @override
  String toString() => resolve('en');
}
