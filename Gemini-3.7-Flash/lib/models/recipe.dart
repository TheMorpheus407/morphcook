import 'localized_string.dart';

class RecipeIngredient {
  final String id;
  final LocalizedString name;
  final double amount;
  final String unit;
  final String aisle;
  final String? guideId;

  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    this.guideId,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String,
      name: LocalizedString.fromJson(json['name']),
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'pieces',
      aisle: json['aisle'] as String? ?? 'Other',
      guideId: json['guide_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.toJson(),
    'amount': amount,
    'unit': unit,
    'aisle': aisle,
    if (guideId != null) 'guide_id': guideId,
  };

  RecipeIngredient scale(double factor) {
    return RecipeIngredient(
      id: id,
      name: name,
      amount: double.parse((amount * factor).toStringAsFixed(2)),
      unit: unit,
      aisle: aisle,
      guideId: guideId,
    );
  }
}

class RecipeStep {
  final int stepNumber;
  final LocalizedString instruction;
  final int? timerMinutes;
  final LocalizedString? tip;

  const RecipeStep({
    required this.stepNumber,
    required this.instruction,
    this.timerMinutes,
    this.tip,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepNumber: json['step_number'] as int? ?? 1,
      instruction: LocalizedString.fromJson(json['instruction']),
      timerMinutes: json['timer_minutes'] as int?,
      tip: json['tip'] != null ? LocalizedString.fromJson(json['tip']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'step_number': stepNumber,
    'instruction': instruction.toJson(),
    if (timerMinutes != null) 'timer_minutes': timerMinutes,
    if (tip != null) 'tip': tip!.toJson(),
  };
}

class RecipeMacros {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  const RecipeMacros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory RecipeMacros.fromJson(Map<String, dynamic> json) {
    return RecipeMacros(
      calories: json['calories'] as int? ?? 0,
      protein: json['protein'] as int? ?? 0,
      carbs: json['carbs'] as int? ?? 0,
      fat: json['fat'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

class Recipe {
  final String id;
  final String dishId;
  final LocalizedString title;
  final LocalizedString description;
  final Map<String, String> variantDimensionValues;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final int totalTimeMinutes;
  final int caloriesPerServing;
  final RecipeMacros macros;
  final List<String> contains;
  final List<String> ingredientIds;
  final List<String> attributes;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final LocalizedString? notes;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.description,
    required this.variantDimensionValues,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.totalTimeMinutes,
    required this.caloriesPerServing,
    required this.macros,
    required this.contains,
    required this.ingredientIds,
    required this.attributes,
    required this.ingredients,
    required this.steps,
    this.notes,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final dimMap = <String, String>{};
    if (json['variant_dimension_values'] is Map) {
      (json['variant_dimension_values'] as Map<String, dynamic>).forEach((k, v) {
        dimMap[k] = v.toString();
      });
    }

    final ingList = (json['ingredients'] as List<dynamic>? ?? [])
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();

    final stepList = (json['steps'] as List<dynamic>? ?? [])
        .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
        .toList();

    return Recipe(
      id: json['id'] as String,
      dishId: json['dish_id'] as String? ?? '',
      title: LocalizedString.fromJson(json['title']),
      description: LocalizedString.fromJson(json['description']),
      variantDimensionValues: dimMap,
      servings: json['servings'] as int? ?? 2,
      prepTimeMinutes: json['prep_time_minutes'] as int? ?? 10,
      cookTimeMinutes: json['cook_time_minutes'] as int? ?? 15,
      totalTimeMinutes: json['total_time_minutes'] as int? ?? 25,
      caloriesPerServing: json['calories_per_serving'] as int? ?? 500,
      macros: json['macros'] != null
          ? RecipeMacros.fromJson(json['macros'] as Map<String, dynamic>)
          : const RecipeMacros(calories: 500, protein: 20, carbs: 50, fat: 15),
      contains: (json['contains'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      ingredientIds: (json['ingredient_ids'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      attributes: (json['attributes'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      ingredients: ingList,
      steps: stepList,
      notes: json['notes'] != null ? LocalizedString.fromJson(json['notes']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dish_id': dishId,
    'title': title.toJson(),
    'description': description.toJson(),
    'variant_dimension_values': variantDimensionValues,
    'servings': servings,
    'prep_time_minutes': prepTimeMinutes,
    'cook_time_minutes': cookTimeMinutes,
    'total_time_minutes': totalTimeMinutes,
    'calories_per_serving': caloriesPerServing,
    'macros': macros.toJson(),
    'contains': contains,
    'ingredient_ids': ingredientIds,
    'attributes': attributes,
    'ingredients': ingredients.map((e) => e.toJson()).toList(),
    'steps': steps.map((e) => e.toJson()).toList(),
    if (notes != null) 'notes': notes!.toJson(),
  };

  /// Return scaled ingredients for a custom target servings count
  List<RecipeIngredient> getScaledIngredients(int targetServings) {
    if (servings <= 0 || targetServings == servings) return ingredients;
    final factor = targetServings / servings;
    return ingredients.map((i) => i.scale(factor)).toList();
  }
}
