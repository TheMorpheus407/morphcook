typedef Localized = Map<String, String>;

Localized localized(dynamic value) => Map<String, String>.from(value as Map);
String translate(Localized value, String lang) =>
    value[lang] ?? value['en'] ?? value.values.firstOrNull ?? '';
Set<String> strings(dynamic value) =>
    (value as List? ?? []).map((e) => e.toString()).toSet();

class Profile {
  String name;
  String lang;
  String diet;
  Set<String> avoidFlags;
  Set<String> avoidIngredients;
  Set<String> requiredAttributes;
  int maxTimeMinutes;
  int calorieTarget;
  int calorieTolerance;
  String preferredEffort;
  bool showVariantTags;
  bool? reduceMotion;
  bool visualAlertEnabled;
  bool quickNextTapEnabled;
  bool onboarded;
  Map<String, dynamic> extra;

  Profile({
    this.name = '',
    this.lang = 'en',
    this.diet = 'classic',
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    this.maxTimeMinutes = 45,
    this.calorieTarget = 600,
    this.calorieTolerance = 250,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
    Map<String, dynamic>? extra,
  }) : avoidFlags = avoidFlags ?? {},
       avoidIngredients = avoidIngredients ?? {},
       requiredAttributes = requiredAttributes ?? {},
       extra = extra ?? {};

  factory Profile.fromJson(Map<String, dynamic> json) {
    final result = Profile(
      name: json['name'] as String? ?? '',
      lang: json['lang'] as String? ?? 'en',
      diet: json['diet'] as String? ?? 'classic',
      avoidFlags: strings(json['avoid_flags']),
      avoidIngredients: strings(json['avoid_ingredients']),
      requiredAttributes: strings(json['required_attributes']),
      maxTimeMinutes: (json['max_time_minutes'] as num? ?? 45).toInt(),
      calorieTarget: (json['calorie_target'] as num? ?? 600).toInt(),
      calorieTolerance: (json['calorie_tolerance'] as num? ?? 250).toInt(),
      preferredEffort: json['preferred_effort'] as String? ?? 'easy',
      showVariantTags: json['show_variant_tags'] as bool? ?? true,
      reduceMotion: json['reduceMotion'] as bool?,
      visualAlertEnabled: json['visualAlertEnabled'] as bool? ?? true,
      quickNextTapEnabled: json['quickNextTapEnabled'] as bool? ?? false,
      onboarded: json['onboarded'] as bool? ?? true,
    );
    result.extra = Map.of(json)
      ..removeWhere((k, _) => result.toJson().containsKey(k));
    return result;
  }

  Profile copy() => Profile.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    ...extra,
    'name': name,
    'lang': lang,
    'diet': diet,
    'avoid_flags': avoidFlags.toList()..sort(),
    'avoid_ingredients': avoidIngredients.toList()..sort(),
    'required_attributes': requiredAttributes.toList()..sort(),
    'max_time_minutes': maxTimeMinutes,
    'calorie_target': calorieTarget,
    'calorie_tolerance': calorieTolerance,
    'preferred_effort': preferredEffort,
    'show_variant_tags': showVariantTags,
    'reduceMotion': reduceMotion,
    'visualAlertEnabled': visualAlertEnabled,
    'quickNextTapEnabled': quickNextTapEnabled,
    'onboarded': onboarded,
  };
}

class Ingredient {
  final String id;
  final Localized name;
  final String? parent;
  final Set<String> flags;
  final String aisle;
  final bool volumeCompatible;
  final Map<String, double> nutrition;

  Ingredient.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = localized(json['name']),
      parent = json['parent'] as String?,
      flags = strings(json['flags']),
      aisle = json['aisle'] as String? ?? 'pantry',
      volumeCompatible = json['volume_compatible'] as bool? ?? false,
      nutrition = Map<String, double>.from(
        (json['nutrition_per_100g'] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      );
}

class RecipeIngredient {
  final String id;
  final double quantity;
  final String unit;
  final Localized note;

  RecipeIngredient.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      quantity = (json['quantity'] as num).toDouble(),
      unit = json['unit'] as String,
      note = localized(json['note'] ?? {'en': '', 'de': ''});

  Map<String, dynamic> toJson() => {
    'id': id,
    'quantity': quantity,
    'unit': unit,
    'note': note,
  };
}

class RecipeStep {
  final Localized title;
  final Localized text;
  final int timerSeconds;
  RecipeStep.fromJson(Map<String, dynamic> json)
    : title = localized(json['title']),
      text = localized(json['text']),
      timerSeconds = (json['timer_seconds'] as num? ?? 0).toInt();
}

class Recipe {
  final String id;
  final String dishId;
  final Localized title;
  final Localized description;
  final Set<String> contains;
  final Set<String> attributes;
  final Set<String> tags;
  final Map<String, String> dimensions;
  final int timeMinutes;
  final int servings;
  final double calories;
  final Map<String, double> macros;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Localized note;

  Recipe.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      dishId = json['dish_id'] as String,
      title = localized(json['title']),
      description = localized(json['description']),
      contains = strings(json['contains']),
      attributes = strings(json['attributes']),
      tags = strings(json['tags']),
      dimensions = Map<String, String>.from(json['dimensions'] as Map),
      timeMinutes = (json['time_minutes'] as num).toInt(),
      servings = (json['servings'] as num).toInt(),
      calories = (json['calories_per_serving'] as num).toDouble(),
      macros = (json['macros'] as Map).map(
        (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
      ),
      ingredients = (json['ingredients'] as List)
          .map(
            (e) =>
                RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      steps = (json['steps'] as List)
          .map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      note = localized(json['note'] ?? {'en': '', 'de': ''});

  String get effort => dimensions['effort'] ?? 'easy';
  Set<String> get ingredientIds => ingredients.map((i) => i.id).toSet();
}

class Dish {
  final String id;
  final Localized name;
  final Localized hero;
  final Localized caption;
  final String stripeColor;
  final List<String> recipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final Set<String> cuisineTags;
  final String frequencyTier;
  Dish.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      name = localized(json['canonical_name']),
      hero = localized(json['hero_text']),
      caption = localized(json['cap_caption']),
      stripeColor = json['stripe_color'] as String,
      recipeIds = (json['variant_recipe_ids'] as List).cast<String>(),
      partitionId = json['partition_id'] as String,
      secondaryPartitions = (json['secondary_partitions'] as List? ?? [])
          .cast<String>(),
      cuisineTags = strings(json['cuisine_tags']),
      frequencyTier = json['frequency_tier'] as String? ?? 'core';
}

class CookingRecord {
  final String recipeId;
  final DateTime cookedAt;
  final int servings;
  CookingRecord(this.recipeId, this.cookedAt, this.servings);
  CookingRecord.fromJson(Map<String, dynamic> json)
    : recipeId = json['recipe_id'] as String,
      cookedAt = DateTime.parse(json['cooked_at'] as String),
      servings = (json['servings'] as num? ?? 2).toInt();
  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toIso8601String(),
    'servings': servings,
  };
}

class ShoppingEvent {
  final DateTime addedAt;
  final Set<String> ingredientIds;
  ShoppingEvent(this.addedAt, this.ingredientIds);
  ShoppingEvent.fromJson(Map<String, dynamic> json)
    : addedAt = DateTime.parse(json['added_at'] as String),
      ingredientIds = strings(json['ingredient_ids']);
  Map<String, dynamic> toJson() => {
    'added_at': addedAt.toIso8601String(),
    'ingredient_ids': ingredientIds.toList(),
  };
}
