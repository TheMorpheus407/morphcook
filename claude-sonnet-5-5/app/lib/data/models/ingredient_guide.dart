import '../../core/i18n/localized_text.dart';

/// Educational "kitchen reference" text for one ingredient.
class IngredientGuideEntry {
  const IngredientGuideEntry({
    required this.ingredientId,
    required this.description,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  final String ingredientId;
  final LocalizedText description;
  final LocalizedText usage;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> json) => IngredientGuideEntry(
    ingredientId: json['ingredient_id'] as String,
    description: LocalizedText.fromJson(json['description']),
    usage: LocalizedText.fromJson(json['usage_tips']),
    storage: LocalizedText.fromJson(json['storage']),
    whereToFind: LocalizedText.fromJson(json['where_to_find']),
  );
}

/// `assets/ingredient-guide.json`, reached through "Learn more" in ingredient lists.
class IngredientGuide {
  IngredientGuide(Iterable<IngredientGuideEntry> entries)
    : _byIngredient = {for (final e in entries) e.ingredientId: e};

  factory IngredientGuide.fromJson(Map<String, dynamic> json) {
    return IngredientGuide([
      for (final e in (json['entries'] as List)) IngredientGuideEntry.fromJson((e as Map).cast<String, dynamic>()),
    ]);
  }

  final Map<String, IngredientGuideEntry> _byIngredient;

  Iterable<IngredientGuideEntry> get entries => _byIngredient.values;
  bool has(String ingredientId) => _byIngredient.containsKey(ingredientId);
  IngredientGuideEntry? forIngredient(String ingredientId) => _byIngredient[ingredientId];
}
