import 'localized.dart';

class Ingredient {
  final String id;
  final Localized name;
  final double amount;
  final String unit;
  final String? aisle;

  const Ingredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.aisle,
  });

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'] as String,
        name: Localized.fromJson(j['name']),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        unit: j['unit'] as String? ?? '',
        aisle: j['aisle'] as String?,
      );
}

class RecipeStep {
  final Localized text;
  final int timerSeconds;
  const RecipeStep({required this.text, this.timerSeconds = 0});

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
        text: Localized.fromJson(j['text']),
        timerSeconds: (j['timer_seconds'] as num?)?.toInt() ?? 0,
      );
}

class Recipe {
  final String id;
  final String dishId;
  final Localized name;
  final Localized description;
  final Localized variantTag;          // "vegan", "klassisch" etc.
  final List<String> contains;         // contains-flags
  final List<String> attributes;       // technique etc.
  final String effort;                 // easy | medium | hard
  final int timeMinutes;
  final int caloriesPerServing;
  final int servings;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> cuisineTags;
  final String partitionId;
  final List<String> secondaryPartitions;
  final int frequencyTier;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  /// Cached set of ingredient ids, with hierarchical parents resolved
  /// (filled by [withResolvedIngredients] at load time).
  final Set<String> ingredientIds;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.description,
    required this.variantTag,
    required this.contains,
    required this.attributes,
    required this.effort,
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.cuisineTags,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.frequencyTier,
    required this.ingredientIds,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  String timeBucket() {
    if (timeMinutes <= 15) return 'le15';
    if (timeMinutes <= 30) return 'le30';
    if (timeMinutes <= 60) return 'le60';
    return 'gt60';
  }

  String calorieBucket() {
    if (caloriesPerServing <= 400) return 'le400';
    if (caloriesPerServing <= 600) return 'le600';
    if (caloriesPerServing <= 800) return 'le800';
    return 'gt800';
  }

  bool get isBreakfast => attributes.contains('breakfast');
  bool get isDinner => attributes.contains('dinner');
  bool get isLunch => attributes.contains('lunch');

  factory Recipe.fromJson(Map<String, dynamic> j) {
    final ingredients = (j['ingredients'] as List?)
            ?.map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [];
    return Recipe(
      id: j['id'] as String,
      dishId: j['dish_id'] as String,
      name: Localized.fromJson(j['name']),
      description: Localized.fromJson(j['description']),
      variantTag: Localized.fromJson(j['variant_tag']),
      contains: (j['contains'] as List?)?.cast<String>() ?? const [],
      attributes: (j['attributes'] as List?)?.cast<String>() ?? const [],
      effort: j['effort'] as String? ?? 'medium',
      timeMinutes: (j['time_minutes'] as num?)?.toInt() ?? 30,
      caloriesPerServing:
          (j['calories_per_serving'] as num?)?.toInt() ?? 500,
      servings: (j['servings'] as num?)?.toInt() ?? 2,
      ingredients: ingredients,
      steps: (j['steps'] as List?)
              ?.map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cuisineTags: (j['cuisine_tags'] as List?)?.cast<String>() ?? const [],
      partitionId: j['partition_id'] as String? ?? 'core',
      secondaryPartitions:
          (j['secondary_partitions'] as List?)?.cast<String>() ?? const [],
      frequencyTier: (j['frequency_tier'] as num?)?.toInt() ?? 2,
      proteinG: (j['protein_g'] as num?)?.toDouble(),
      carbsG: (j['carbs_g'] as num?)?.toDouble(),
      fatG: (j['fat_g'] as num?)?.toDouble(),
      ingredientIds: ingredients.map((i) => i.id).toSet(),
    );
  }
}
