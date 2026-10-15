import 'localized_text.dart';

class IngredientGuideEntry {
  final String id;
  final LocalizedText title;
  final LocalizedText category;
  final LocalizedText description;
  final LocalizedText usageTips;
  final LocalizedText storageGuidance;
  final LocalizedText whereToFind;

  const IngredientGuideEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.usageTips,
    required this.storageGuidance,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) {
    return IngredientGuideEntry(
      id: json['id']?.toString() ?? '',
      title: LocalizedText.fromJson(json['title']),
      category: LocalizedText.fromJson(json['category']),
      description: LocalizedText.fromJson(json['description']),
      usageTips: LocalizedText.fromJson(json['usage_tips']),
      storageGuidance: LocalizedText.fromJson(json['storage_guidance']),
      whereToFind: LocalizedText.fromJson(json['where_to_find']),
    );
  }
}

class IngredientGuide {
  final int schemaVersion;
  final Map<String, IngredientGuideEntry> entries;

  const IngredientGuide({
    required this.schemaVersion,
    required this.entries,
  });

  factory IngredientGuide.empty() => const IngredientGuide(
        schemaVersion: 1,
        entries: {},
      );

  factory IngredientGuide.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'] as Map<String, dynamic>? ?? {};
    return IngredientGuide(
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      entries: raw.map(
        (key, value) => MapEntry(
          key,
          IngredientGuideEntry.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }

  IngredientGuideEntry? operator [](String ingredientId) => entries[ingredientId];

  bool hasGuide(String ingredientId) => entries.containsKey(ingredientId);
}
