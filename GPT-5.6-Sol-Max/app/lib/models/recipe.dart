import 'localized_text.dart';

class IngredientAmount {
  const IngredientAmount({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.aisle,
    this.note = const {},
    this.volumeConvertible = false,
  });

  final String id;
  final LocalizedText name;
  final double quantity;
  final String unit;
  final String aisle;
  final LocalizedText note;
  final bool volumeConvertible;

  factory IngredientAmount.fromJson(Map<String, dynamic> json) =>
      IngredientAmount(
        id: json['id'] as String,
        name: localizedTextFromJson(json['name']),
        quantity: (json['quantity'] as num).toDouble(),
        unit: json['unit'] as String? ?? '',
        aisle: json['aisle'] as String? ?? 'other',
        note: localizedTextFromJson(json['note']),
        volumeConvertible: json['volume_convertible'] as bool? ?? false,
      );
}

class RecipeStep {
  const RecipeStep({
    required this.text,
    this.timerSeconds,
    this.tip = const {},
  });

  final LocalizedText text;
  final int? timerSeconds;
  final LocalizedText tip;

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    text: localizedTextFromJson(json['text']),
    timerSeconds: (json['timer_seconds'] as num?)?.round(),
    tip: localizedTextFromJson(json['tip']),
  );
}

class Nutrition {
  const Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
    calories: (json['calories'] as num).round(),
    protein: (json['protein'] as num).toDouble(),
    carbs: (json['carbs'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
  );
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.subtitle,
    required this.diet,
    required this.effort,
    required this.calorieLevel,
    required this.contains,
    required this.attributes,
    required this.timeMinutes,
    required this.servings,
    required this.nutrition,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.mealTypes,
    required this.cuisine,
    required this.season,
    this.reviewed = true,
  });

  final String id;
  final String dishId;
  final LocalizedText title;
  final LocalizedText subtitle;
  final String diet;
  final String effort;
  final String calorieLevel;
  final Set<String> contains;
  final Set<String> attributes;
  final int timeMinutes;
  final int servings;
  final Nutrition nutrition;
  final List<IngredientAmount> ingredients;
  final List<RecipeStep> steps;
  final Set<String> tags;
  final Set<String> mealTypes;
  final String cuisine;
  final String season;
  final bool reviewed;

  Set<String> get ingredientIds => ingredients.map((item) => item.id).toSet();

  Map<String, String> get dimensions => {
    'diet': diet,
    'effort': effort,
    'calorie': calorieLevel,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] as String,
    dishId: json['dish_id'] as String,
    title: localizedTextFromJson(json['title']),
    subtitle: localizedTextFromJson(json['subtitle']),
    diet: json['diet'] as String,
    effort: json['effort'] as String,
    calorieLevel: json['calorie_level'] as String,
    contains: _strings(json['contains']),
    attributes: _strings(json['attributes']),
    timeMinutes: (json['time_minutes'] as num).round(),
    servings: (json['servings'] as num?)?.round() ?? 2,
    nutrition: Nutrition.fromJson(
      Map<String, dynamic>.from(json['nutrition'] as Map),
    ),
    ingredients: (json['ingredients'] as List)
        .map(
          (item) =>
              IngredientAmount.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    steps: (json['steps'] as List)
        .map(
          (item) => RecipeStep.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false),
    tags: _strings(json['tags']),
    mealTypes: _strings(json['meal_types']),
    cuisine: json['cuisine'] as String? ?? 'global',
    season: json['season'] as String? ?? 'all',
    reviewed: json['reviewed'] as bool? ?? true,
  );

  static Set<String> _strings(Object? value) =>
      value is List ? value.map((item) => '$item').toSet() : <String>{};
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.caption,
    required this.stripeColor,
    required this.recipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText hero;
  final LocalizedText caption;
  final int stripeColor;
  final List<String> recipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    id: json['id'] as String,
    name: localizedTextFromJson(json['name']),
    hero: localizedTextFromJson(json['hero']),
    caption: localizedTextFromJson(json['caption']),
    stripeColor: _hex(json['stripe_color'] as String? ?? '#D96C5F'),
    recipeIds: _list(json['recipe_ids']),
    partitionId: json['partition_id'] as String? ?? 'core',
    secondaryPartitions: _list(json['secondary_partitions']),
    cuisineTags: _list(json['cuisine_tags']),
    frequencyTier: json['frequency_tier'] as String? ?? 'core',
  );

  static List<String> _list(Object? value) =>
      value is List ? value.map((item) => '$item').toList() : const [];

  static int _hex(String value) =>
      int.parse(value.replaceFirst('#', 'FF'), radix: 16);
}
