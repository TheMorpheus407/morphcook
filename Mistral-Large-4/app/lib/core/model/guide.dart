import 'localized.dart';

/// Educational ingredient content (the "kitchen reference"): descriptions,
/// usage tips, storage guidance, and where-to-find information. Bilingual.
class IngredientGuideEntry {
  final String ingredientId;
  final LocalizedText name;
  final LocalizedText description;
  final LocalizedText usageTips;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  const IngredientGuideEntry({
    required this.ingredientId,
    required this.name,
    required this.description,
    required this.usageTips,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) => IngredientGuideEntry(
        ingredientId: json['ingredient_id'] as String,
        name: LocalizedText.fromJson(json['name'] as Map<String, dynamic>),
        description: LocalizedText.fromJson(json['description'] as Map<String, dynamic>),
        usageTips: LocalizedText.fromJson(json['usage_tips'] as Map<String, dynamic>),
        storage: LocalizedText.fromJson(json['storage'] as Map<String, dynamic>),
        whereToFind: LocalizedText.fromJson(json['where_to_find'] as Map<String, dynamic>),
      );
}
