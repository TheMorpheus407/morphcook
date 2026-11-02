import 'localized_text.dart';

/// One ingredient line inside a recipe.
class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredientId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.note,
    this.optional = false,
    this.preparation,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      ingredientId: '${json['ingredient_id'] ?? ''}',
      name: L10nText.fromJson(json['name']),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: '${json['unit'] ?? ''}',
      note: json['note'] == null ? null : L10nText.fromJson(json['note']),
      preparation: json['preparation'] == null
          ? null
          : L10nText.fromJson(json['preparation']),
      optional: json['optional'] == true,
    );
  }

  final String ingredientId;
  final L10nText name;
  final double quantity;
  final String unit;
  final L10nText? note;
  final L10nText? preparation;
  final bool optional;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'ingredient_id': ingredientId,
        'name': name.toJson(),
        'quantity': quantity,
        'unit': unit,
        if (note != null) 'note': note!.toJson(),
        if (preparation != null) 'preparation': preparation!.toJson(),
        'optional': optional,
      };
}

/// One step of the method.
class RecipeStep {
  const RecipeStep({
    required this.instruction,
    this.timerSeconds,
    this.title,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      instruction: L10nText.fromJson(json['instruction']),
      timerSeconds: (json['timer_seconds'] as num?)?.toInt(),
      title: json['title'] == null ? null : L10nText.fromJson(json['title']),
    );
  }

  final L10nText instruction;

  /// Optional timer, in seconds, for this step.
  final int? timerSeconds;

  final L10nText? title;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'instruction': instruction.toJson(),
        if (timerSeconds != null) 'timer_seconds': timerSeconds,
        if (title != null) 'title': title!.toJson(),
      };
}

/// Per-serving macros.
class Nutrition {
  const Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) {
    return Nutrition(
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      protein: (json['protein_g'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs_g'] as num?)?.toDouble() ?? 0,
      fat: (json['fat_g'] as num?)?.toDouble() ?? 0,
    );
  }

  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'calories': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
      };
}

/// A complete, self-contained recipe.
///
/// A variant *is* a recipe — there is no overlay tree and no substitution
/// engine. Variants are linked to a [dishId], and everything the app knows
/// about a recipe lives here.
class Recipe {
  Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.ingredients,
    required this.steps,
    required this.contains,
    required this.attributes,
    required this.diet,
    required this.timeMinutes,
    required this.calories,
    required this.macros,
    required this.servings,
    required this.tags,
    required this.mealSlots,
    required this.partitionId,
    this.extraDimensions = const <String, String>{},
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawAttributes = (json['attributes'] as Map<String, dynamic>? ??
        <String, dynamic>{});
    final attributes = <String, List<String>>{};
    rawAttributes.forEach((key, value) {
      if (value is List) {
        attributes[key] = value.map((entry) => '$entry').toList(growable: false);
      } else {
        attributes[key] = <String>['$value'];
      }
    });

    final macros = Nutrition.fromJson(
      (json['macros'] as Map<String, dynamic>? ?? <String, dynamic>{}),
    );

    return Recipe(
      id: '${json['id']}',
      dishId: '${json['dish_id']}',
      title: L10nText.fromJson(json['title']),
      heroText: L10nText.fromJson(json['hero_text']),
      capCaption: L10nText.fromJson(json['cap_caption']),
      stripeColor: '${json['stripe_color'] ?? '#C4694D'}',
      ingredients: (json['ingredients'] as List<dynamic>? ?? <dynamic>[])
          .map((entry) => RecipeIngredient.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      steps: (json['steps'] as List<dynamic>? ?? <dynamic>[])
          .map((entry) => RecipeStep.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      contains: (json['contains'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toSet(),
      attributes: attributes,
      diet: '${json['diet'] ?? 'classic'}',
      timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 0,
      calories: (json['calories_per_serving'] as num?)?.toInt() ?? macros.calories,
      macros: macros,
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      tags: L10nText.fromJson(json['tags']),
      mealSlots: (json['meal_slots'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      partitionId: '${json['partition_id'] ?? 'core'}',
      extraDimensions:
          (json['dimensions'] as Map<String, dynamic>? ?? <String, dynamic>{})
              .map((key, value) => MapEntry(key, '$value')),
    );
  }

  final String id;
  final String dishId;
  final L10nText title;
  final L10nText heroText;
  final L10nText capCaption;
  final String stripeColor;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  /// Primitive flags this recipe contains.
  final Set<String> contains;

  /// Attribute axes → values. `certifications` holds positive markers such as
  /// `halal` or `kosher`.
  final Map<String, List<String>> attributes;

  /// The diet axis value (`classic`, `vegan`, `halal`, …).
  final String diet;

  final int timeMinutes;
  final int calories;
  final Nutrition macros;
  final int servings;
  final L10nText tags;
  final List<String> mealSlots;
  final String partitionId;

  /// Any future dimension axis, kept as plain strings.
  final Map<String, String> extraDimensions;

  String get effort => attributes['effort']?.firstOrNull ?? 'easy';

  String get timeBucket => attributes['time_bucket']?.firstOrNull ?? '≤30';

  String get calorieBucket => attributes['calorie_bucket']?.firstOrNull ?? '≤600';

  List<String> get techniques => attributes['technique'] ?? const <String>[];

  List<String> get certifications =>
      attributes['certifications'] ?? const <String>[];

  /// The flat attribute-token set used by `required_attributes` matching.
  Set<String> get attributeTokens {
    final tokens = <String>{};
    attributes.forEach((axis, values) {
      for (final value in values) {
        tokens.add('$axis:$value');
      }
    });
    for (final certification in certifications) {
      tokens.add(certification);
    }
    return tokens;
  }

  /// The dimension map the variant switcher works with.
  Map<String, String> get dimensions => <String, String>{
        'diet': diet,
        'effort': effort,
        'calorie_level': calorieBucket,
        ...extraDimensions,
      };

  /// Ingredient ids, used for specific-avoidance matching.
  Set<String> get ingredientIds =>
      ingredients.map((ingredient) => ingredient.ingredientId).toSet();

  bool get isBreakfast => mealSlots.contains('breakfast');

  bool get isDinner => mealSlots.contains('dinner');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'dish_id': dishId,
        'title': title.toJson(),
        'hero_text': heroText.toJson(),
        'cap_caption': capCaption.toJson(),
        'stripe_color': stripeColor,
        'ingredients':
            ingredients.map((ingredient) => ingredient.toJson()).toList(),
        'steps': steps.map((step) => step.toJson()).toList(),
        'contains': contains.toList(),
        'attributes': attributes,
        'diet': diet,
        'time_minutes': timeMinutes,
        'calories_per_serving': calories,
        'macros': macros.toJson(),
        'servings': servings,
        'tags': tags.toJson(),
        'meal_slots': mealSlots,
        'partition_id': partitionId,
        if (extraDimensions.isNotEmpty) 'dimensions': extraDimensions,
      };
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
