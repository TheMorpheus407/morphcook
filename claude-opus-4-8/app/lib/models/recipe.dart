import '../core/localized.dart';

/// A single recipe variant. Each variant is its own full recipe, linked to a
/// dish concept by [dishId]. This is the one load-bearing idea of the app.
class Recipe {
  Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.blurb,
    required this.mealType,
    required this.servings,
    required this.timeMinutes,
    required this.contains,
    required this.attributes,
    required this.variantAxes,
    required this.macros,
    required this.ingredients,
    required this.steps,
    required this.stepTimers,
  });

  final String id;
  final String dishId;
  final LocalizedText name;
  final LocalizedText blurb;
  final String mealType; // breakfast | lunch | dinner
  final int servings;
  final int timeMinutes;

  /// What the recipe HAS — matched against the profile's avoid-flags.
  final Set<String> contains;

  /// Positive descriptors: effort, time_bucket, calorie_bucket, techniques.
  final Set<String> attributes;

  /// Per-dimension variant value, e.g. `{ diet: vegan, effort: easy }`.
  final Map<String, String> variantAxes;

  final Macros macros;
  final List<RecipeIngredient> ingredients;

  /// Steps per language: `{ en: [...], de: [...] }`.
  final Map<String, List<String>> steps;

  /// Optional per-step timer in seconds, parallel to the steps list.
  final List<int?> stepTimers;

  Set<String> get ingredientIds => ingredients.map((i) => i.ingredientId).toSet();

  int get calories => macros.calories;

  List<String> stepsFor(AppLang lang) =>
      steps[lang.code] ?? steps['en'] ?? const [];

  /// All searchable tokens across languages: title, ingredient names.
  Iterable<String> get searchTokens sync* {
    yield* name.allValues;
    for (final i in ingredients) {
      yield* i.name.allValues;
    }
    yield* attributes;
  }

  factory Recipe.fromJson(Map<String, dynamic> j) {
    final stepsRaw = (j['steps'] as Map).map(
      (k, v) => MapEntry(k as String, (v as List).cast<String>()),
    );
    return Recipe(
      id: j['id'] as String,
      dishId: j['dish_id'] as String,
      name: LocalizedText.fromJson(j['name']),
      blurb: LocalizedText.fromJson(j['blurb']),
      mealType: j['meal_type'] as String? ?? 'lunch',
      servings: (j['servings'] as num?)?.toInt() ?? 1,
      timeMinutes: (j['time_minutes'] as num).toInt(),
      contains: (j['contains'] as List? ?? []).cast<String>().toSet(),
      attributes: (j['attributes'] as List? ?? []).cast<String>().toSet(),
      variantAxes: Map<String, String>.from(j['variant_axes'] as Map? ?? {}),
      macros: Macros.fromJson(j['macros'] as Map<String, dynamic>? ?? const {}),
      ingredients: (j['ingredients'] as List? ?? [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: stepsRaw,
      stepTimers: (j['step_timers'] as List? ?? [])
          .map((e) => e == null ? null : (e as num).toInt())
          .toList(),
    );
  }
}

class Macros {
  const Macros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  factory Macros.fromJson(Map<String, dynamic> j) => Macros(
        calories: (j['calories'] as num?)?.toInt() ?? 0,
        protein: (j['protein'] as num?)?.toInt() ?? 0,
        carbs: (j['carbs'] as num?)?.toInt() ?? 0,
        fat: (j['fat'] as num?)?.toInt() ?? 0,
      );
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredientId,
    required this.qty,
    required this.unit,
    required this.name,
  });
  final String ingredientId;
  final double qty;
  final String unit;
  final LocalizedText name;
  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        ingredientId: j['ingredient_id'] as String,
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
        unit: j['unit'] as String? ?? '',
        name: LocalizedText.fromJson(j['name']),
      );
}
