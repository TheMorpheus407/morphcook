import 'dart:math' as math;

typedef Localized = Map<String, String>;

String localized(Localized values, String lang) {
  return values[lang] ?? values['en'] ?? values.values.first;
}

enum AppTab { home, cookbook, plan, search, settings }

enum AppRoute {
  home,
  cookbook,
  plan,
  search,
  settings,
  recipe,
  cook,
  shopping,
  insights,
  help,
  profileEditor,
  backup,
  onboarding,
}

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    this.flags = const <String>{},
  });

  final String id;
  final Localized name;
  final double amount;
  final String unit;
  final String aisle;
  final Set<String> flags;

  String label(String lang) => localized(name, lang);

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'name': name,
    'amount': amount,
    'unit': unit,
    'aisle': aisle,
    'flags': flags.toList(),
  };
}

class CookingStep {
  const CookingStep({required this.text, this.timerSeconds});

  final Localized text;
  final int? timerSeconds;

  String label(String lang) => localized(text, lang);
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.subtitle,
    required this.diet,
    required this.effort,
    required this.calories,
    required this.timeMinutes,
    required this.contains,
    required this.ingredients,
    required this.steps,
    required this.tags,
    required this.mealTypes,
    required this.technique,
    required this.accent,
    required this.heroCaption,
    required this.description,
    this.servings = 2,
    this.isNew = false,
  });

  final String id;
  final String dishId;
  final Localized title;
  final Localized subtitle;
  final String diet;
  final String effort;
  final int calories;
  final int timeMinutes;
  final Set<String> contains;
  final List<Ingredient> ingredients;
  final List<CookingStep> steps;
  final List<String> tags;
  final List<String> mealTypes;
  final String technique;
  final int accent;
  final Localized heroCaption;
  final Localized description;
  final int servings;
  final bool isNew;

  List<String> get ingredientIds => ingredients.map((item) => item.id).toList();

  String name(String lang) => localized(title, lang);

  String subline(String lang) => localized(subtitle, lang);

  String blurb(String lang) => localized(description, lang);

  String caption(String lang) => localized(heroCaption, lang);

  String calorieBucket() {
    if (calories <= 400) return '≤400';
    if (calories <= 600) return '≤600';
    if (calories <= 800) return '≤800';
    return '>800';
  }

  String timeBucket() {
    if (timeMinutes <= 15) return '≤15';
    if (timeMinutes <= 30) return '≤30';
    if (timeMinutes <= 60) return '≤60';
    return '>60';
  }

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'dish_id': dishId,
    'title': title,
    'subtitle': subtitle,
    'diet': diet,
    'effort': effort,
    'calories_per_serving': calories,
    'time_minutes': timeMinutes,
    'contains': contains.toList(),
    'ingredients': ingredients.map((item) => item.toJson()).toList(),
    'steps': steps
        .map(
          (step) => <String, Object?>{
            'text': step.text,
            'timer_seconds': step.timerSeconds,
          },
        )
        .toList(),
    'tags': tags,
    'meal_types': mealTypes,
    'technique': technique,
  };
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.eyebrow,
    required this.description,
    required this.accent,
    required this.pattern,
    required this.recipeIds,
  });

  final String id;
  final Localized name;
  final Localized eyebrow;
  final Localized description;
  final int accent;
  final int pattern;
  final List<String> recipeIds;

  String title(String lang) => localized(name, lang);

  String kicker(String lang) => localized(eyebrow, lang);

  String blurb(String lang) => localized(description, lang);
}

class Profile {
  const Profile({
    required this.name,
    required this.lang,
    required this.dietPreference,
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

  final String name;
  final String lang;
  final String dietPreference;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final int maxTimeMinutes;
  final int calorieTarget;
  final String preferredEffort;
  final bool showVariantTags;
  final bool reduceMotion;
  final bool visualAlertEnabled;
  final bool quickNextTapEnabled;

  Profile copyWith({
    String? name,
    String? lang,
    String? dietPreference,
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    int? maxTimeMinutes,
    int? calorieTarget,
    String? preferredEffort,
    bool? showVariantTags,
    bool? reduceMotion,
    bool? visualAlertEnabled,
    bool? quickNextTapEnabled,
  }) {
    return Profile(
      name: name ?? this.name,
      lang: lang ?? this.lang,
      dietPreference: dietPreference ?? this.dietPreference,
      avoidFlags: avoidFlags ?? this.avoidFlags,
      avoidIngredients: avoidIngredients ?? this.avoidIngredients,
      requiredAttributes: requiredAttributes ?? this.requiredAttributes,
      maxTimeMinutes: maxTimeMinutes ?? this.maxTimeMinutes,
      calorieTarget: calorieTarget ?? this.calorieTarget,
      preferredEffort: preferredEffort ?? this.preferredEffort,
      showVariantTags: showVariantTags ?? this.showVariantTags,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      visualAlertEnabled: visualAlertEnabled ?? this.visualAlertEnabled,
      quickNextTapEnabled: quickNextTapEnabled ?? this.quickNextTapEnabled,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'name': name,
    'lang': lang,
    'diet_preference': dietPreference,
    'avoid_flags': avoidFlags.toList(),
    'avoid_ingredients': avoidIngredients.toList(),
    'required_attributes': requiredAttributes.toList(),
    'max_time_minutes': maxTimeMinutes,
    'calorie_target': calorieTarget,
    'preferred_effort': preferredEffort,
    'show_variant_tags': showVariantTags,
    'reduce_motion': reduceMotion,
    'visual_alert_enabled': visualAlertEnabled,
    'quick_next_tap_enabled': quickNextTapEnabled,
  };
}

class HistoryEntry {
  const HistoryEntry({required this.recipeId, required this.cookedAt});

  final String recipeId;
  final DateTime cookedAt;

  Map<String, Object> toJson() => <String, Object>{
    'recipe_id': recipeId,
    'cooked_at': cookedAt.toIso8601String(),
  };
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    required this.recipeCount,
    this.checked = false,
  });

  final String id;
  final String name;
  final double amount;
  final String unit;
  final String aisle;
  final int recipeCount;
  final bool checked;

  ShoppingItem copyWith({bool? checked}) {
    return ShoppingItem(
      id: id,
      name: name,
      amount: amount,
      unit: unit,
      aisle: aisle,
      recipeCount: recipeCount,
      checked: checked ?? this.checked,
    );
  }
}

Map<String, Set<String>> get compoundAvoidFlags => <String, Set<String>>{
  'vegan': <String>{
    'pork',
    'beef',
    'lamb',
    'poultry',
    'fish',
    'shellfish',
    'molluscs',
    'egg',
    'dairy',
    'honey',
    'gelatin-non-halal',
    'gelatin-non-kosher',
  },
  'vegetarian': <String>{
    'pork',
    'beef',
    'lamb',
    'poultry',
    'fish',
    'shellfish',
    'molluscs',
    'gelatin-non-halal',
    'gelatin-non-kosher',
  },
  'pescatarian': <String>{
    'pork',
    'beef',
    'lamb',
    'poultry',
    'gelatin-non-halal',
  },
  'halal': <String>{'pork', 'alcohol', 'gelatin-non-halal'},
  'kosher': <String>{
    'pork',
    'shellfish',
    'molluscs',
    'meat-dairy-combo',
    'gelatin-non-kosher',
  },
  'low-fodmap': <String>{'high-fodmap'},
  'sugar-free': <String>{'added-sugar'},
  'lactose-free': <String>{'dairy'},
  'nuts': <String>{'tree-nuts', 'peanuts', 'almonds', 'walnuts', 'pistachios'},
  'shellfish': <String>{'shellfish', 'molluscs'},
};

const Map<String, Set<String>> ingredientAncestors = <String, Set<String>>{
  'whole-milk': <String>{'cow-milk', 'dairy'},
  'skim-milk': <String>{'cow-milk', 'dairy'},
  'parmesan': <String>{'cheese', 'dairy'},
  'feta': <String>{'cheese', 'dairy'},
  'walnuts': <String>{'tree-nuts', 'nuts'},
  'almonds': <String>{'tree-nuts', 'nuts'},
  'pistachios': <String>{'tree-nuts', 'nuts'},
  'peanuts': <String>{'nuts'},
};

Set<String> expandedAvoidFlags(Iterable<String> flags) {
  final result = <String>{};
  for (final flag in flags) {
    result.add(flag);
    result.addAll(compoundAvoidFlags[flag] ?? const <String>{});
  }
  return result;
}

bool matchesProfile(
  Recipe recipe,
  Profile profile, {
  bool ignoreCalories = false,
}) {
  final avoided = expandedAvoidFlags(profile.avoidFlags);
  if (recipe.contains.intersection(avoided).isNotEmpty) return false;
  if (profile.avoidIngredients.any((avoid) {
    return recipe.ingredientIds.any((ingredientId) {
      return ingredientId == avoid ||
          (ingredientAncestors[ingredientId]?.contains(avoid) ?? false);
    });
  })) {
    return false;
  }
  if (!profile.requiredAttributes.every(recipe.tags.contains)) return false;
  if (recipe.timeMinutes > profile.maxTimeMinutes) return false;
  if (!ignoreCalories &&
      (recipe.calories - profile.calorieTarget).abs() > 180) {
    return false;
  }
  return true;
}

double recipeScore(Recipe recipe, Profile profile, {DateTime? now}) {
  final time = now ?? DateTime.now();
  var score = 0.0;
  if (recipe.effort == profile.preferredEffort) score += 45;
  score += math.max(
    0,
    30 - (recipe.timeMinutes - profile.maxTimeMinutes).abs(),
  );
  score += math.max(
    0,
    40 - (recipe.calories - profile.calorieTarget).abs() / 8,
  );
  if (time.hour >= 5 &&
      time.hour < 11 &&
      recipe.mealTypes.contains('breakfast')) {
    score += 200;
  }
  if (time.hour >= 17 &&
      time.hour < 21 &&
      recipe.mealTypes.contains('dinner')) {
    score += 90;
  }
  if (time.weekday >= DateTime.saturday && recipe.effort != 'easy') {
    score += 90;
  }
  return score;
}
