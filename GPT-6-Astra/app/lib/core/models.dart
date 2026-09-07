import 'dart:convert';

/// Every authored string can gain another language without a schema migration.
Map<String, String> localizedMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }
  return value == null ? {} : {'en': value.toString(), 'de': value.toString()};
}

String localized(Map<String, String> value, String lang) =>
    value[lang] ?? value['en'] ?? value.values.firstOrNull ?? '';

Set<String> stringSet(dynamic value) =>
    value is Iterable ? value.map((e) => e.toString()).toSet() : <String>{};

class Profile {
  String name;
  String lang;
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

  Profile({
    this.name = '',
    this.lang = 'en',
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    this.maxTimeMinutes = 60,
    this.calorieTarget = 600,
    this.calorieTolerance = 300,
    this.preferredEffort = 'easy',
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onboarded = false,
  }) : avoidFlags = avoidFlags ?? {},
       avoidIngredients = avoidIngredients ?? {},
       requiredAttributes = requiredAttributes ?? {};

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] as String? ?? '',
    lang: json['lang'] as String? ?? 'en',
    avoidFlags: stringSet(json['avoid_flags']),
    avoidIngredients: stringSet(json['avoid_ingredients']),
    requiredAttributes: stringSet(json['required_attributes']),
    maxTimeMinutes: (json['max_time_minutes'] as num?)?.toInt() ?? 60,
    calorieTarget: (json['calorie_target'] as num?)?.toInt() ?? 600,
    calorieTolerance: (json['calorie_tolerance'] as num?)?.toInt() ?? 300,
    preferredEffort: json['preferred_effort'] as String? ?? 'easy',
    showVariantTags: json['show_variant_tags'] as bool? ?? true,
    reduceMotion: (json['reduceMotion'] ?? json['reduce_motion']) as bool?,
    visualAlertEnabled:
        (json['visualAlertEnabled'] ?? json['visual_alert_enabled']) as bool? ??
        true,
    quickNextTapEnabled:
        (json['quickNextTapEnabled'] ?? json['quick_next_tap_enabled'])
            as bool? ??
        false,
    onboarded: json['onboarded'] as bool? ?? false,
  );

  Profile copy() => Profile.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'name': name,
    'lang': lang,
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
  final Map<String, String> name;
  final String? parentId;
  final Map<String, String> aisle;
  final Set<String> flags;

  const Ingredient({
    required this.id,
    required this.name,
    this.parentId,
    this.aisle = const {'en': 'Pantry', 'de': 'Vorrat'},
    this.flags = const {},
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: json['id'] as String,
    name: localizedMap(json['name']),
    parentId: (json['parent_id'] ?? json['parent']) as String?,
    aisle: localizedMap(json['aisle'] ?? {'en': 'Pantry', 'de': 'Vorrat'}),
    flags: stringSet(json['flags'] ?? json['contains']),
  );
}

class RecipeIngredient {
  final String id;
  final double quantity;
  final String unit;
  final Map<String, String> note;
  const RecipeIngredient({
    required this.id,
    required this.quantity,
    required this.unit,
    this.note = const {},
  });
  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: (json['id'] ?? json['ingredient_id']) as String,
        quantity: (json['quantity'] as num? ?? 0).toDouble(),
        unit: json['unit'] as String? ?? 'piece',
        note: localizedMap(json['note']),
      );
}

class RecipeStep {
  final Map<String, String> title;
  final Map<String, String> text;
  final int timerSeconds;
  const RecipeStep({
    this.title = const {},
    required this.text,
    this.timerSeconds = 0,
  });
  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    title: localizedMap(json['title']),
    text: localizedMap(
      json['text'] ?? json['instruction'] ?? json['description'],
    ),
    timerSeconds: (json['timer_seconds'] as num?)?.toInt() ?? 0,
  );
}

class Recipe {
  final String id;
  final String dishId;
  final Map<String, String> title;
  final Map<String, String> description;
  final String diet;
  final String effort;
  final String calorieLevel;
  final int timeMinutes;
  final int calories;
  final int servings;
  final Set<String> contains;
  final Set<String> attributes;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Map<String, dynamic> nutrition;
  final Map<String, String> extraDimensions;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    this.description = const {},
    this.diet = 'classic',
    this.effort = 'easy',
    this.calorieLevel = 'balanced',
    this.timeMinutes = 30,
    this.calories = 600,
    this.servings = 2,
    this.contains = const {},
    this.attributes = const {},
    this.tags = const [],
    this.ingredients = const [],
    this.steps = const [],
    this.nutrition = const {},
    this.extraDimensions = const {},
  });

  Set<String> get ingredientIds => ingredients.map((e) => e.id).toSet();
  int get caloriesPerServing => calories;
  Map<String, String> get dimensions => {
    'diet': diet,
    'effort': effort,
    'calorie_level': calorieLevel,
    ...extraDimensions,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] as String,
    dishId: json['dish_id'] as String,
    title: localizedMap(json['title'] ?? json['name']),
    description: localizedMap(json['description']),
    diet: json['diet'] as String? ?? 'classic',
    effort: json['effort'] as String? ?? 'easy',
    calorieLevel:
        (json['calorie_level'] ?? json['calorie_bucket'])?.toString() ??
        'balanced',
    timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 30,
    calories:
        ((json['calories_per_serving'] ?? json['calories']) as num?)?.round() ??
        600,
    servings: (json['servings'] as num?)?.toInt() ?? 2,
    contains: stringSet(json['contains']),
    attributes: stringSet(json['attributes']),
    tags: stringSet(json['tags']).toList(),
    ingredients: (json['ingredients'] as List? ?? [])
        .map(
          (e) => RecipeIngredient.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
    steps: (json['steps'] as List? ?? [])
        .map((e) => RecipeStep.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    nutrition: Map<String, dynamic>.from(json['nutrition'] as Map? ?? {}),
    extraDimensions: localizedMap(json['dimensions']),
  );
}

class Dish {
  final String id;
  final Map<String, String> name;
  final Map<String, String> subtitle;
  final Map<String, String> caption;
  final String color;
  final List<String> variants;
  final String? partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;

  const Dish({
    required this.id,
    required this.name,
    this.subtitle = const {},
    this.caption = const {},
    this.color = '#c89978',
    this.variants = const [],
    this.partitionId,
    this.secondaryPartitions = const [],
    this.cuisineTags = const [],
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    id: json['id'] as String,
    name: localizedMap(json['name'] ?? json['canonical_name']),
    subtitle: localizedMap(json['subtitle'] ?? json['hero_text']),
    caption: localizedMap(json['caption'] ?? json['cap_caption']),
    color: (json['color'] ?? json['stripe_color']) as String? ?? '#c89978',
    variants: stringSet(json['variants'] ?? json['variant_ids']).toList(),
    partitionId: json['partition_id'] as String?,
    secondaryPartitions: stringSet(json['secondary_partitions']).toList(),
    cuisineTags: stringSet(json['cuisine_tags']).toList(),
  );
}

class ShoppingItem {
  final String id;
  final String ingredientId;
  final double quantity;
  final String unit;
  final bool checked;
  final String? customName;

  const ShoppingItem({
    required this.id,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.checked = false,
    this.customName,
  });

  ShoppingItem copyWith({
    String? id,
    String? ingredientId,
    double? quantity,
    String? unit,
    bool? checked,
    String? customName,
  }) => ShoppingItem(
    id: id ?? this.id,
    ingredientId: ingredientId ?? this.ingredientId,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    checked: checked ?? this.checked,
    customName: customName ?? this.customName,
  );

  String label(dynamic repo, String lang) =>
      customName ??
      localized(
        repo.ingredientById(ingredientId)?.name ??
            <String, String>{'en': ingredientId},
        lang,
      );
  String aisle(dynamic repo, String lang) => localized(
    repo.ingredientById(ingredientId)?.aisle ??
        <String, String>{'en': 'Other', 'de': 'Sonstiges'},
    lang,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ingredient_id': ingredientId,
    'quantity': quantity,
    'unit': unit,
    'checked': checked,
    'custom_name': customName,
  };
  factory ShoppingItem.fromJson(Map<String, dynamic> json) => ShoppingItem(
    id: json['id'] as String,
    ingredientId: json['ingredient_id'] as String? ?? '',
    quantity: (json['quantity'] as num? ?? 1).toDouble(),
    unit: json['unit'] as String? ?? 'piece',
    checked: json['checked'] as bool? ?? false,
    customName: json['custom_name'] as String?,
  );
}

DateTime mondayOfWeek(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day - (date.weekday - DateTime.monday),
);

String weekKey(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  final thursday = utc.add(Duration(days: DateTime.thursday - utc.weekday));
  final first = DateTime.utc(thursday.year, 1, 1);
  final week = ((thursday.difference(first).inDays) / 7).floor() + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

Map<String, dynamic> jsonMapCopy(Map<String, dynamic> map) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(map)) as Map);
