import 'ltext.dart';

/// Educational "kitchen reference" entry for an ingredient.
class GuideEntry {
  const GuideEntry({
    required this.ingredientId,
    required this.description,
    required this.usageTips,
    required this.storage,
    required this.whereToFind,
  });
  final String ingredientId;
  final LText description;
  final LText usageTips;
  final LText storage;
  final LText whereToFind;

  factory GuideEntry.fromJson(Map<String, dynamic> j) => GuideEntry(
        ingredientId: j['ingredient_id'] as String,
        description: LText.fromJson(j['description']),
        usageTips: LText.fromJson(j['usage_tips']),
        storage: LText.fromJson(j['storage']),
        whereToFind: LText.fromJson(j['where_to_find']),
      );
}

class IngredientGuide {
  IngredientGuide(List<GuideEntry> entries) : byIngredient = {for (final e in entries) e.ingredientId: e};
  final Map<String, GuideEntry> byIngredient;

  factory IngredientGuide.fromJson(Map<String, dynamic> j) => IngredientGuide(
        (j['entries'] as List).map((e) => GuideEntry.fromJson(e as Map<String, dynamic>)).toList(),
      );

  GuideEntry? operator [](String ingredientId) => byIngredient[ingredientId];
}
