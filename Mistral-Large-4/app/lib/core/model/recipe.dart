import 'localized.dart';

/// One line of an ingredient list: a dictionary ingredient plus an amount.
class IngredientLine {
  final String ingredientId;
  final double amount;
  final String unit;
  final LocalizedText? note;

  const IngredientLine({
    required this.ingredientId,
    required this.amount,
    required this.unit,
    this.note,
  });

  factory IngredientLine.fromJson(Map<String, dynamic> json) => IngredientLine(
        ingredientId: json['ingredient_id'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] == null ? null : LocalizedText.fromJson(json['note'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'amount': amount,
        'unit': unit,
        if (note != null) 'note': note!.toJson(),
      };
}

/// One step of the method. [timerMinutes] is optional — steps without a timer
/// simply have none.
class CookStep {
  final LocalizedText text;
  final int? timerMinutes;

  const CookStep({required this.text, this.timerMinutes});

  factory CookStep.fromJson(Map<String, dynamic> json) => CookStep(
        text: LocalizedText.fromJson(json['text'] as Map<String, dynamic>),
        timerMinutes: json['timer_minutes'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'text': text.toJson(),
        if (timerMinutes != null) 'timer_minutes': timerMinutes,
      };
}

/// Per-serving macros.
class Macros {
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const Macros({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
        kcal: json['kcal'] as int,
        proteinG: json['protein_g'] as int,
        carbsG: json['carbs_g'] as int,
        fatG: json['fat_g'] as int,
      );

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}

/// A recipe is one fully-authored variant of a dish concept. Siblings under the
/// same [dishId] are variants ("Classic Döner", "Vegan Döner", …) — never
/// substitutions, always complete recipes.
class Recipe {
  final String id;
  final String dishId;
  final LocalizedText title;
  final LocalizedText subtitle;

  /// Diet dimension value: classic | vegan | vegetarian | pescatarian | keto |
  /// halal | kosher | gluten-free | …
  final String diet;

  /// effort: easy | medium | hard
  final String effort;
  final int timeMinutes;
  final int caloriesPerServing;
  final int servings;

  /// What the recipe has: pork, dairy, gluten, peanuts, …
  final Set<String> contains;

  /// Positive descriptors: required attributes (halal…) and technique tags.
  final Set<String> attributes;

  /// Free-text search tags (ids, language-neutral).
  final List<String> tags;

  /// breakfast | lunch | dinner — drives time-aware ranking.
  final String mealType;

  final List<IngredientLine> ingredients;
  final List<CookStep> steps;
  final Macros macros;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.subtitle,
    required this.diet,
    required this.effort,
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.servings,
    required this.contains,
    required this.attributes,
    required this.tags,
    required this.mealType,
    required this.ingredients,
    required this.steps,
    required this.macros,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        dishId: json['dish_id'] as String,
        title: LocalizedText.fromJson(json['title'] as Map<String, dynamic>),
        subtitle: LocalizedText.fromJson(json['subtitle'] as Map<String, dynamic>),
        diet: json['diet'] as String,
        effort: json['effort'] as String,
        timeMinutes: json['time_minutes'] as int,
        caloriesPerServing: json['calories_per_serving'] as int,
        servings: json['servings'] as int,
        contains: (json['contains'] as List).cast<String>().toSet(),
        attributes: (json['attributes'] as List).cast<String>().toSet(),
        tags: (json['tags'] as List).cast<String>(),
        mealType: json['meal_type'] as String,
        ingredients: (json['ingredients'] as List)
            .map((i) => IngredientLine.fromJson(i as Map<String, dynamic>))
            .toList(),
        steps: (json['steps'] as List)
            .map((s) => CookStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        macros: Macros.fromJson(json['macros'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dish_id': dishId,
        'title': title.toJson(),
        'subtitle': subtitle.toJson(),
        'diet': diet,
        'effort': effort,
        'time_minutes': timeMinutes,
        'calories_per_serving': caloriesPerServing,
        'servings': servings,
        'contains': contains.toList(),
        'attributes': attributes.toList(),
        'tags': tags,
        'meal_type': mealType,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'macros': macros.toJson(),
      };

  /// Ids of all ingredients used, for specific-avoidance matching.
  Set<String> get ingredientIds => ingredients.map((i) => i.ingredientId).toSet();

  /// Scale an ingredient amount to [servings] (from the recipe's base).
  IngredientLine scaled(IngredientLine line, int targetServings) {
    final factor = targetServings / servings;
    return IngredientLine(
      ingredientId: line.ingredientId,
      amount: line.amount * factor,
      unit: line.unit,
      note: line.note,
    );
  }

  Recipe copyWith({int? servings}) => Recipe(
        id: id,
        dishId: dishId,
        title: title,
        subtitle: subtitle,
        diet: diet,
        effort: effort,
        timeMinutes: timeMinutes,
        caloriesPerServing: caloriesPerServing,
        servings: servings ?? this.servings,
        contains: contains,
        attributes: attributes,
        tags: tags,
        mealType: mealType,
        ingredients: ingredients,
        steps: steps,
        macros: macros,
      );
}
