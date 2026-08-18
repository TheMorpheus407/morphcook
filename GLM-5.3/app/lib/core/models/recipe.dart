import 'localized_text.dart';

/// One ingredient line of a recipe: dictionary id + quantity + unit.
class RecipeIngredient {
  RecipeIngredient({required this.id, required this.qty, required this.unit});

  final String id;
  final double qty;
  final String unit;

  static RecipeIngredient fromMap(Map<String, dynamic> map) => RecipeIngredient(
        id: map['id'] as String,
        qty: (map['q'] as num).toDouble(),
        unit: map['u'] as String,
      );
}

/// One method step with bilingual prose and an optional timer in seconds.
class RecipeStep {
  RecipeStep({required this.text, this.timerSeconds});

  final LocalizedText text;
  final int? timerSeconds;

  static RecipeStep fromMap(Map<String, dynamic> map) => RecipeStep(
        text: parseLocalized(map['t']),
        timerSeconds: map['s'] == null ? null : (map['s'] as num).toInt(),
      );
}

/// A fully-authored recipe. Each variant of a dish is its own recipe.
class Recipe {
  Recipe({
    required this.id,
    required this.dish,
    required this.title,
    required this.diet,
    required this.effort,
    required this.timeMinutes,
    required this.cal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servings,
    required this.contains,
    required this.attr,
    required this.tech,
    required this.ingredients,
    required this.steps,
  });

  final String id;
  final String dish;
  final LocalizedText title;
  final String diet; // classic | vegetarian | vegan | pescatarian | halal | keto | gluten-free
  final String effort; // easy | medium | hard
  final int timeMinutes;
  final int cal;
  final int protein;
  final int carbs;
  final int fat;
  final int servings;
  final List<String> contains;
  final List<String> attr;
  final List<String> tech;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  static Recipe fromMap(Map<String, dynamic> map) => Recipe(
        id: map['id'] as String,
        dish: map['dish'] as String,
        title: parseLocalized(map['title']),
        diet: map['diet'] as String,
        effort: map['effort'] as String,
        timeMinutes: (map['time'] as num).toInt(),
        cal: (map['cal'] as num).toInt(),
        protein: (map['p'] as num).toInt(),
        carbs: (map['c'] as num).toInt(),
        fat: (map['f'] as num).toInt(),
        servings: (map['servings'] as num).toInt(),
        contains: (map['contains'] as List).map((e) => e.toString()).toList(),
        attr: ((map['attr'] as List?) ?? const []).map((e) => e.toString()).toList(),
        tech: (map['tech'] as List).map((e) => e.toString()).toList(),
        ingredients: (map['ing'] as List)
            .map((e) => RecipeIngredient.fromMap(e as Map<String, dynamic>))
            .toList(),
        steps: (map['steps'] as List)
            .map((e) => RecipeStep.fromMap(e as Map<String, dynamic>))
            .toList(),
      );

  /// Derived time bucket: `le15 | le30 | le60 | gt60`.
  String get timeBucket {
    if (timeMinutes <= 15) return 'le15';
    if (timeMinutes <= 30) return 'le30';
    if (timeMinutes <= 60) return 'le60';
    return 'gt60';
  }

  /// Derived calorie bucket: `le400 | le600 | le800 | gt800`.
  String get calorieBucket {
    if (cal <= 400) return 'le400';
    if (cal <= 600) return 'le600';
    if (cal <= 800) return 'le800';
    return 'gt800';
  }

  /// The set of attributes this recipe satisfies — used for the
  /// `required_attributes ⊆ recipe.attributes` clause of the matcher.
  Set<String> get attributeSet => {diet, effort, timeBucket, calorieBucket, ...attr, ...tech};

  /// Dictionary ids of all ingredients in this recipe.
  Set<String> get ingredientIds => ingredients.map((i) => i.id).toSet();

  /// Localized step text helper.
  String stepText(int index, String lang) => lt(steps[index].text, lang);

  /// Scaled quantity for the cook-mode servings scaler.
  double scaleFactorFor(int wantedServings) => wantedServings / servings;
}
