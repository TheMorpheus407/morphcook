import 'dart:convert';

typedef LocalizedText = Map<String, String>;

LocalizedText localizedText(dynamic value) {
  if (value is Map) {
    return value.map((key, entry) => MapEntry('$key', '$entry'));
  }
  return {'en': '${value ?? ''}', 'de': '${value ?? ''}'};
}

String localize(LocalizedText text, String lang) =>
    text[lang] ?? text['en'] ?? text.values.firstOrNull ?? '';

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

Set<String> stringSet(dynamic value) => value is Iterable
    ? value.whereType<Object?>().map((item) => '$item').toSet()
    : <String>{};

List<String> stringList(dynamic value) => value is Iterable
    ? value.whereType<Object?>().map((item) => '$item').toList()
    : <String>[];

double asDouble(dynamic value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? fallback;
}

class Profile {
  const Profile({
    required this.name,
    required this.lang,
    required this.avoidFlags,
    required this.avoidIngredients,
    required this.requiredAttributes,
    required this.maxTimeMinutes,
    required this.calorieTarget,
    required this.preferredEffort,
    required this.showVariantTags,
    required this.reduceMotion,
    required this.visualAlertEnabled,
    required this.quickNextTapEnabled,
  });

  factory Profile.fresh() => const Profile(
    name: '',
    lang: 'en',
    avoidFlags: {},
    avoidIngredients: {},
    requiredAttributes: {},
    maxTimeMinutes: 45,
    calorieTarget: 600,
    preferredEffort: 'easy',
    showVariantTags: true,
    reduceMotion: null,
    visualAlertEnabled: true,
    quickNextTapEnabled: false,
  );

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: '${json['name'] ?? ''}',
    lang: '${json['lang'] ?? 'en'}',
    avoidFlags: stringSet(json['avoid_flags'] ?? json['avoidFlags']),
    avoidIngredients: stringSet(
      json['avoid_ingredients'] ?? json['avoidIngredients'],
    ),
    requiredAttributes: stringSet(
      json['required_attributes'] ?? json['requiredAttributes'],
    ),
    maxTimeMinutes: asInt(
      json['max_time_minutes'] ?? json['maxTimeMinutes'],
      45,
    ),
    calorieTarget: asInt(json['calorie_target'] ?? json['calorieTarget'], 600),
    preferredEffort:
        '${json['preferred_effort'] ?? json['preferredEffort'] ?? 'easy'}',
    showVariantTags:
        json['show_variant_tags'] ?? json['showVariantTags'] ?? true,
    reduceMotion: json['reduceMotion'] as bool?,
    visualAlertEnabled:
        json['visualAlertEnabled'] ?? json['visual_alert_enabled'] ?? true,
    quickNextTapEnabled:
        json['quickNextTapEnabled'] ?? json['quick_next_tap_enabled'] ?? false,
  );

  final String name;
  final String lang;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final int maxTimeMinutes;
  final int calorieTarget;
  final String preferredEffort;
  final bool showVariantTags;
  final bool? reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;

  Profile copyWith({
    String? name,
    String? lang,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool clearReduceMotion = false,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
  }) => Profile(
    name: name ?? this.name,
    lang: lang ?? this.lang,
    avoidFlags: avoidFlags ?? this.avoidFlags,
    avoidIngredients: avoidIngredients ?? this.avoidIngredients,
    requiredAttributes: requiredAttributes ?? this.requiredAttributes,
    maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
    calorieTarget: calorieTarget ?? this.calorieTarget,
    preferredEffort: preferredEffort ?? this.preferredEffort,
    showVariantTags: showVariantTags ?? this.showVariantTags,
    reduceMotion: clearReduceMotion ? null : reduceMotion ?? this.reduceMotion,
    visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
    quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'lang': lang,
    'avoid_flags': avoidFlags.toList()..sort(),
    'avoid_ingredients': avoidIngredients.toList()..sort(),
    'required_attributes': requiredAttributes.toList()..sort(),
    'max_time_minutes': maxTimeMinutes,
    'calorie_target': calorieTarget,
    'preferred_effort': preferredEffort,
    'show_variant_tags': showVariantTags,
    'reduceMotion': reduceMotion,
    'visualAlertEnabled': visualAlertEnabled,
    'quickNextTapEnabled': quickNextTapEnabled,
  };
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.amount,
    required this.unit,
    this.optional = false,
    this.note,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: '${json['id']}',
        amount: asDouble(json['amount']),
        unit: '${json['unit'] ?? ''}',
        optional: json['optional'] == true,
        note: json['note'] == null ? null : localizedText(json['note']),
      );

  final String id;
  final double amount;
  final String unit;
  final bool optional;
  final LocalizedText? note;

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'unit': unit,
    if (optional) 'optional': true,
    if (note != null) 'note': note,
  };
}

class RecipeStep {
  const RecipeStep({required this.text, this.timerSeconds});

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    text: localizedText(json['text']),
    timerSeconds: json['timer_seconds'] == null
        ? null
        : asInt(json['timer_seconds']),
  );

  final LocalizedText text;
  final int? timerSeconds;

  Map<String, dynamic> toJson() => {
    'text': text,
    if (timerSeconds != null) 'timer_seconds': timerSeconds,
  };
}

class Nutrition {
  const Nutrition({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
    calories: asInt(json['calories']),
    protein: asDouble(json['protein']),
    carbs: asDouble(json['carbs']),
    fat: asDouble(json['fat']),
  );

  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.contains,
    required this.attributes,
    required this.axes,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    required this.timeMinutes,
    required this.servings,
    required this.tags,
    required this.mealTypes,
    required this.stripeColor,
    required this.caption,
    required this.partitionId,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: '${json['id']}',
    dishId: '${json['dish_id']}',
    title: localizedText(json['title']),
    subtitle: localizedText(json['subtitle'] ?? ''),
    description: localizedText(json['description'] ?? ''),
    contains: stringSet(json['contains']),
    attributes: stringSet(json['attributes']),
    axes: (json['axes'] as Map? ?? const {}).map(
      (key, value) => MapEntry('$key', '$value'),
    ),
    ingredients:
        ((json['ingredients'] as List? ?? const []).whereType<Map>().map(
          (item) => RecipeIngredient.fromJson(
            item.map((key, value) => MapEntry('$key', value)),
          ),
        )).toList(),
    steps: ((json['steps'] as List? ?? const []).whereType<Map>().map(
      (item) => RecipeStep.fromJson(
        item.map((key, value) => MapEntry('$key', value)),
      ),
    )).toList(),
    nutrition: Nutrition.fromJson(
      (json['nutrition'] as Map? ?? const {}).map(
        (key, value) => MapEntry('$key', value),
      ),
    ),
    timeMinutes: asInt(json['time_minutes']),
    servings: asInt(json['servings'], 2),
    tags: stringSet(json['tags']),
    mealTypes: stringSet(json['meal_types']),
    stripeColor: '${json['stripe_color'] ?? '#bc8069'}',
    caption: localizedText(json['caption'] ?? ''),
    partitionId: '${json['partition_id'] ?? 'core'}',
  );

  final String id;
  final String dishId;
  final LocalizedText title;
  final LocalizedText subtitle;
  final LocalizedText description;
  final Set<String> contains;
  final Set<String> attributes;
  final Map<String, String> axes;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Nutrition nutrition;
  final int timeMinutes;
  final int servings;
  final Set<String> tags;
  final Set<String> mealTypes;
  final String stripeColor;
  final LocalizedText caption;
  final String partitionId;

  int get caloriesPerServing => nutrition.calories;
  Set<String> get ingredientIds => ingredients.map((item) => item.id).toSet();
  String titleFor(String lang) => localize(title, lang);
  String subtitleFor(String lang) => localize(subtitle, lang);
  String descriptionFor(String lang) => localize(description, lang);
  String captionFor(String lang) => localize(caption, lang);
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.heroText,
    required this.caption,
    required this.stripeColor,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
    id: '${json['id']}',
    name: localizedText(json['canonical_name'] ?? json['name']),
    heroText: localizedText(json['hero_text'] ?? ''),
    caption: localizedText(json['cap_caption'] ?? json['caption'] ?? ''),
    stripeColor: '${json['stripe_color'] ?? '#bc8069'}',
    variantIds: stringList(json['variant_recipe_ids']),
    partitionId: '${json['partition_id'] ?? 'core'}',
    secondaryPartitions: stringList(json['secondary_partitions']),
    cuisineTags: stringSet(json['cuisine_tags']),
    frequencyTier: '${json['frequency_tier'] ?? 'core'}',
  );

  final String id;
  final LocalizedText name;
  final LocalizedText heroText;
  final LocalizedText caption;
  final String stripeColor;
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final Set<String> cuisineTags;
  final String frequencyTier;

  String nameFor(String lang) => localize(name, lang);
  String heroFor(String lang) => localize(heroText, lang);
  String captionFor(String lang) => localize(caption, lang);
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.aisle,
    this.parentId,
    this.description = const {},
    this.usageTips = const {},
    this.storage = const {},
    this.whereToFind = const {},
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
    id: '${json['id']}',
    name: localizedText(json['name']),
    aisle: '${json['aisle'] ?? 'pantry'}',
    parentId: json['parent_id'] == null ? null : '${json['parent_id']}',
    description: localizedText(json['description'] ?? ''),
    usageTips: localizedText(json['usage_tips'] ?? ''),
    storage: localizedText(json['storage'] ?? ''),
    whereToFind: localizedText(json['where_to_find'] ?? ''),
  );

  final String id;
  final LocalizedText name;
  final String aisle;
  final String? parentId;
  final LocalizedText description;
  final LocalizedText usageTips;
  final LocalizedText storage;
  final LocalizedText whereToFind;

  String nameFor(String lang) => localize(name, lang);
}

class IngredientIndex {
  IngredientIndex(this.ingredients);

  final Map<String, Ingredient> ingredients;

  bool isDescendantOf(String candidateId, String possibleAncestorId) {
    var cursor = candidateId;
    final visited = <String>{};
    while (visited.add(cursor)) {
      if (cursor == possibleAncestorId) return true;
      final parent = ingredients[cursor]?.parentId;
      if (parent == null) return false;
      cursor = parent;
    }
    return false;
  }

  bool intersectsAvoided(
    Iterable<String> recipeIngredientIds,
    Set<String> avoidedIngredientIds,
  ) => recipeIngredientIds.any(
    (ingredientId) => avoidedIngredientIds.any(
      (avoidedId) => isDescendantOf(ingredientId, avoidedId),
    ),
  );

  List<Ingredient> search(String query, String lang) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return ingredients.values.take(12).toList();
    return ingredients.values
        .where(
          (ingredient) => ingredient.name.values.any(
            (name) => name.toLowerCase().contains(needle),
          ),
        )
        .toList()
      ..sort((a, b) => a.nameFor(lang).compareTo(b.nameFor(lang)));
  }
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.contexts = const [],
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
    id: '${json['id']}',
    category: '${json['category'] ?? 'general'}',
    question: localizedText(json['question']),
    answer: localizedText(json['answer']),
    contexts: stringList(json['contexts']),
  );

  final String id;
  final String category;
  final LocalizedText question;
  final LocalizedText answer;
  final List<String> contexts;
}

class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.cookedAt});

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    recipeId: '${json['recipe_id'] ?? json['recipeId']}',
    cookedAt:
        DateTime.tryParse('${json['cooked_at'] ?? json['cookedAt']}') ??
        DateTime.now(),
  );

  final String recipeId;
  final DateTime cookedAt;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toUtc().toIso8601String(),
  };
}

class ShoppingEvent {
  const ShoppingEvent({required this.ingredientIds, required this.createdAt});

  factory ShoppingEvent.fromJson(Map<String, dynamic> json) => ShoppingEvent(
    ingredientIds: stringList(json['ingredient_ids'] ?? json['ingredientIds']),
    createdAt:
        DateTime.tryParse('${json['created_at'] ?? json['createdAt']}') ??
        DateTime.now(),
  );

  final List<String> ingredientIds;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'ingredient_ids': ingredientIds,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

class CookProgress {
  const CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    required this.remainingSeconds,
    required this.isTimerRunning,
  });

  factory CookProgress.fromJson(Map<String, dynamic> json) => CookProgress(
    recipeId: '${json['recipe_id'] ?? json['recipeId']}',
    stepIndex: asInt(json['step_index'] ?? json['stepIndex']),
    servings: asInt(json['servings'], 2),
    remainingSeconds: asInt(
      json['remaining_seconds'] ?? json['remainingSeconds'],
    ),
    isTimerRunning: json['is_timer_running'] ?? json['isTimerRunning'] ?? false,
  );

  final String recipeId;
  final int stepIndex;
  final int servings;
  final int remainingSeconds;
  final bool isTimerRunning;

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'step_index': stepIndex,
    'servings': servings,
    'remaining_seconds': remainingSeconds,
    'is_timer_running': isTimerRunning,
  };
}

String encodeJson(Object value) => jsonEncode(value);
