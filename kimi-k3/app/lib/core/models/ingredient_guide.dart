import 'local_text.dart';

/// Educational "kitchen reference" content for an ingredient.
class IngredientGuideEntry {
  final String id;
  final String ingredientId;
  final LocalText description;
  final LocalText usage;
  final LocalText storage;
  final LocalText whereToFind;

  const IngredientGuideEntry({
    required this.id,
    required this.ingredientId,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) =>
      IngredientGuideEntry(
        id: json['id'] as String,
        ingredientId: json['ingredient_id'] as String,
        description: parseLocalText(json['description']),
        usage: parseLocalText(json['usage']),
        storage: parseLocalText(json['storage']),
        whereToFind: parseLocalText(json['where_to_find']),
      );
}
