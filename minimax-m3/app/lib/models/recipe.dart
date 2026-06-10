import 'i18n_string.dart';

class RecipeIngredient {
  final String id;
  final double qty;
  final String unit;
  final I18nString name;

  const RecipeIngredient({
    required this.id,
    required this.qty,
    required this.unit,
    required this.name,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        name: I18nString.fromAny(json['name']),
      );

  RecipeIngredient scaled(double factor) => RecipeIngredient(
        id: id,
        qty: qty * factor,
        unit: unit,
        name: name,
      );
}

class RecipeStep {
  final I18nString text;
  final int? timeMinutes;

  const RecipeStep({required this.text, this.timeMinutes});

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        text: I18nString.fromAny(json['text']),
        timeMinutes: (json['time_minutes'] as num?)?.toInt(),
      );
}

class Recipe {
  final String id;
  final String dishId;
  final I18nString name;
  final I18nString variantLabel;
  final String dietLabel;
  final I18nString summary;
  final List<String> contains;
  final List<String> attributes;
  final List<String> techniqueTags;
  final int timeMinutes;
  final int? activeMinutes;
  final String effort; // easy | medium | hard
  final int servings;
  final int caloriesPerServing;
  final num proteinG;
  final num carbsG;
  final num fatG;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.variantLabel,
    required this.dietLabel,
    required this.summary,
    required this.contains,
    required this.attributes,
    required this.techniqueTags,
    required this.timeMinutes,
    required this.activeMinutes,
    required this.effort,
    required this.servings,
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.ingredients,
    required this.steps,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        dishId: json['dish_id'] as String,
        name: I18nString.fromAny(json['name']),
        variantLabel: I18nString.fromAny(json['variant_label']),
        dietLabel: json['diet_label'] as String? ?? 'omnivore',
        summary: I18nString.fromAny(json['summary']),
        contains: ((json['contains'] as List?) ?? []).cast<String>(),
        attributes: ((json['attributes'] as List?) ?? []).cast<String>(),
        techniqueTags: ((json['technique_tags'] as List?) ?? []).cast<String>(),
        timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 30,
        activeMinutes: (json['active_minutes'] as num?)?.toInt(),
        effort: json['effort'] as String? ?? 'medium',
        servings: (json['servings'] as num?)?.toInt() ?? 2,
        caloriesPerServing: (json['calories_per_serving'] as num?)?.toInt() ?? 500,
        proteinG: (json['protein_g'] as num?) ?? 0,
        carbsG: (json['carbs_g'] as num?) ?? 0,
        fatG: (json['fat_g'] as num?) ?? 0,
        ingredients: ((json['ingredients'] as List?) ?? [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: ((json['steps'] as List?) ?? [])
            .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Set<String> get ingredientIds => ingredients.map((e) => e.id).toSet();

  String get timeBucket {
    if (timeMinutes <= 15) return '≤15';
    if (timeMinutes <= 30) return '≤30';
    if (timeMinutes <= 60) return '≤60';
    return '>60';
  }

  String get calorieBucket {
    if (caloriesPerServing <= 400) return '≤400';
    if (caloriesPerServing <= 600) return '≤600';
    if (caloriesPerServing <= 800) return '≤800';
    return '>800';
  }
}
