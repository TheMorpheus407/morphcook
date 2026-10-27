import 'localized_text.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.amount,
    required this.unit,
    required this.name,
    required this.aisle,
    required this.preparation,
  });

  final String id;
  final double? amount;
  final String unit;
  final LocalizedText name;
  final String aisle;
  final LocalizedText preparation;

  factory RecipeIngredient.fromJson(Map json) => RecipeIngredient(
    id: json['id'].toString(),
    amount: json['amount'] is num ? (json['amount'] as num).toDouble() : null,
    unit: json['unit']?.toString() ?? 'piece',
    name: LocalizedText.fromJson(json['name']),
    aisle: json['aisle']?.toString() ?? 'pantry',
    preparation: LocalizedText.fromJson(json['preparation']),
  );
}

class RecipeStep {
  const RecipeStep({required this.text, this.timerSeconds});

  final LocalizedText text;
  final int? timerSeconds;

  factory RecipeStep.fromJson(Map json) => RecipeStep(
    text: LocalizedText.fromJson(json['text']),
    timerSeconds: json['timer_seconds'] is num
        ? (json['timer_seconds'] as num).toInt()
        : null,
  );
}

class Macros {
  const Macros({required this.protein, required this.carbs, required this.fat});

  final double protein;
  final double carbs;
  final double fat;

  factory Macros.fromJson(Object? json) {
    final map = json is Map ? json : const {};
    double value(String key) =>
        map[key] is num ? (map[key] as num).toDouble() : 0;
    return Macros(
      protein: value('protein_g'),
      carbs: value('carbs_g'),
      fat: value('fat_g'),
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.summary,
    required this.contains,
    required this.attributes,
    required this.dimensions,
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.servings,
    required this.macros,
    required this.ingredients,
    required this.ingredientIds,
    required this.steps,
    required this.tags,
    this.partitionId = 'core',
  });

  final String id;
  final String dishId;
  final LocalizedText title;
  final LocalizedText summary;
  final Set<String> contains;
  final Set<String> attributes;
  final Map<String, String> dimensions;
  final int timeMinutes;
  final int caloriesPerServing;
  final int servings;
  final Macros macros;
  final List<RecipeIngredient> ingredients;
  final Set<String> ingredientIds;
  final List<RecipeStep> steps;
  final Set<String> tags;
  final String partitionId;

  String get diet => dimensions['diet'] ?? 'classic';
  String get effort => dimensions['effort'] ?? 'easy';
  String get calorieLevel => dimensions['calorie'] ?? 'regular';

  factory Recipe.fromJson(Map json, {String partitionId = 'core'}) => Recipe(
    id: json['id'].toString(),
    dishId: json['dish_id'].toString(),
    title: LocalizedText.fromJson(json['title']),
    summary: LocalizedText.fromJson(json['summary']),
    contains: stringList(json['contains']).toSet(),
    attributes: stringList(json['attributes']).toSet(),
    dimensions: dimensionsFromJson(json['dimensions']),
    timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 0,
    caloriesPerServing: (json['calories_per_serving'] as num?)?.toInt() ?? 0,
    servings: (json['servings'] as num?)?.toInt() ?? 2,
    macros: Macros.fromJson(json['macros']),
    ingredients: json['ingredients'] is List
        ? (json['ingredients'] as List)
              .map((item) => RecipeIngredient.fromJson(item as Map))
              .toList()
        : const [],
    ingredientIds: stringList(json['ingredient_ids']).toSet(),
    steps: json['steps'] is List
        ? (json['steps'] as List)
              .map((item) => RecipeStep.fromJson(item as Map))
              .toList()
        : const [],
    tags: stringList(json['tags']).toSet(),
    partitionId: json['partition_id']?.toString() ?? partitionId,
  );
}

class Dish {
  const Dish({
    required this.id,
    required this.canonicalName,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    required this.tags,
  });

  final String id;
  final LocalizedText canonicalName;
  final LocalizedText heroText;
  final LocalizedText capCaption;
  final String stripeColor;
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;
  final List<String> tags;

  factory Dish.fromJson(Map json) => Dish(
    id: json['id'].toString(),
    canonicalName: LocalizedText.fromJson(json['canonical_name']),
    heroText: LocalizedText.fromJson(json['hero_text']),
    capCaption: LocalizedText.fromJson(json['cap_caption']),
    stripeColor: json['stripe_color']?.toString() ?? '#8A9B8E',
    variantIds: stringList(json['variant_ids']),
    partitionId: json['partition_id']?.toString() ?? 'core',
    secondaryPartitions: stringList(json['secondary_partitions']),
    cuisineTags: stringList(json['cuisine_tags']),
    frequencyTier: json['frequency_tier']?.toString() ?? 'core',
    tags: stringList(json['tags']),
  );
}
