import '../../core/i18n/localized_text.dart';
import 'ontology.dart';

/// The slice of a recipe that matching, ranking and search need. Implemented by
/// the full [Recipe] and by the light search-index entries, so both can go
/// through the same pure functions.
abstract class RecipeMeta {
  String get id;
  String get dishId;
  Set<String> get contains;
  Set<String> get ingredientIds;
  Set<String> get attributes;
  int get timeMinutes;
  int get caloriesPerServing;
  String get effort;
  List<String> get meal;
}

class Macros {
  const Macros({required this.protein, required this.carbs, required this.fat});

  final double protein;
  final double carbs;
  final double fat;

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
    protein: (json['protein'] as num).toDouble(),
    carbs: (json['carbs'] as num).toDouble(),
    fat: (json['fat'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{'protein': protein, 'carbs': carbs, 'fat': fat};
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.unit,
    this.amount,
    this.note = LocalizedText.empty,
    this.group = LocalizedText.empty,
    this.optional = false,
  });

  /// Node id in `ingredients.json`.
  final String id;

  /// `null` for "to taste" style lines.
  final double? amount;
  final String unit;
  final LocalizedText note;

  /// Optional sub-heading ("for the sauce") the line belongs to.
  final LocalizedText group;
  final bool optional;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
    id: json['id'] as String,
    amount: (json['amount'] as num?)?.toDouble(),
    unit: (json['unit'] as String?) ?? 'piece',
    note: LocalizedText.fromJson(json['note']),
    group: LocalizedText.fromJson(json['group']),
    optional: (json['optional'] as bool?) ?? false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    if (amount != null) 'amount': amount,
    'unit': unit,
    if (note.isNotEmpty) 'note': note.toJson(),
    if (group.isNotEmpty) 'group': group.toJson(),
    if (optional) 'optional': true,
  };
}

class RecipeStep {
  const RecipeStep({required this.text, this.timerSeconds});

  final LocalizedText text;

  /// Explicit per-step timer. Timers are authored, never guessed from prose.
  final int? timerSeconds;

  factory RecipeStep.fromJson(Map<String, dynamic> json) =>
      RecipeStep(text: LocalizedText.fromJson(json['text']), timerSeconds: (json['timer_seconds'] as num?)?.toInt());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'text': text.toJson(),
    if (timerSeconds != null) 'timer_seconds': timerSeconds,
  };
}

/// One fully authored variant of a dish ("Vegan Döner", "Keto Döner Bowl").
class Recipe implements RecipeMeta {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.blurb,
    required this.tip,
    required this.diet,
    required this.effort,
    required this.timeMinutes,
    required this.servings,
    required this.caloriesPerServing,
    required this.macros,
    required this.meal,
    required this.techniques,
    required this.tags,
    required this.axes,
    required this.contains,
    required this.attributes,
    required this.ingredientIds,
    required this.timeBucket,
    required this.calorieBucket,
    required this.ingredients,
    required this.steps,
  });

  @override
  final String id;
  @override
  final String dishId;
  final LocalizedText title;
  final LocalizedText blurb;

  /// Handwritten margin note.
  final LocalizedText tip;

  /// Diet label of this variant (`classic`, `vegan`, `keto`, ...).
  final String diet;
  @override
  final String effort;
  @override
  final int timeMinutes;
  final int servings;
  @override
  final int caloriesPerServing;
  final Macros macros;
  @override
  final List<String> meal;
  final List<String> techniques;
  final List<String> tags;

  /// Values for future dimensions, keyed by dimension source (`axes.spice`).
  final Map<String, String> axes;
  @override
  final Set<String> contains;
  @override
  final Set<String> attributes;
  @override
  final Set<String> ingredientIds;
  final String timeBucket;
  final String calorieBucket;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  /// Value of this recipe on a switcher dimension.
  String? valueFor(DimensionDef dimension) {
    switch (dimension.source) {
      case 'diet':
        return diet;
      case 'effort':
        return effort;
      case 'calorie_bucket':
        return calorieBucket;
      case 'time_bucket':
        return timeBucket;
      default:
        if (dimension.source.startsWith('axes.')) return axes[dimension.source.substring(5)];
        return null;
    }
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    Set<String> strings(String key) => (json[key] as List? ?? const <Object?>[]).map((e) => e.toString()).toSet();
    final ingredients = [
      for (final i in (json['ingredients'] as List? ?? const <Object?>[]))
        RecipeIngredient.fromJson((i as Map).cast<String, dynamic>()),
    ];
    return Recipe(
      id: json['id'] as String,
      dishId: json['dish_id'] as String,
      title: LocalizedText.fromJson(json['title']),
      blurb: LocalizedText.fromJson(json['blurb']),
      tip: LocalizedText.fromJson(json['tip']),
      diet: (json['diet'] as String?) ?? 'classic',
      effort: (json['effort'] as String?) ?? 'medium',
      timeMinutes: (json['time_minutes'] as num).toInt(),
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      caloriesPerServing: (json['calories_per_serving'] as num).toInt(),
      macros: Macros.fromJson((json['macros'] as Map).cast<String, dynamic>()),
      meal: (json['meal'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
      techniques: (json['techniques'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
      tags: (json['tags'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
      axes: {
        for (final e in ((json['axes'] as Map?) ?? const <String, dynamic>{}).entries)
          e.key.toString(): e.value.toString(),
      },
      contains: strings('contains'),
      attributes: strings('attributes'),
      ingredientIds: json['ingredient_ids'] == null ? {for (final i in ingredients) i.id} : strings('ingredient_ids'),
      timeBucket: (json['time_bucket'] as String?) ?? '',
      calorieBucket: (json['calorie_bucket'] as String?) ?? '',
      ingredients: ingredients,
      steps: [
        for (final s in (json['steps'] as List? ?? const <Object?>[]))
          RecipeStep.fromJson((s as Map).cast<String, dynamic>()),
      ],
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'dish_id': dishId,
    'title': title.toJson(),
    'blurb': blurb.toJson(),
    if (tip.isNotEmpty) 'tip': tip.toJson(),
    'diet': diet,
    'effort': effort,
    'time_minutes': timeMinutes,
    'servings': servings,
    'calories_per_serving': caloriesPerServing,
    'macros': macros.toJson(),
    'meal': meal,
    'techniques': techniques,
    'tags': tags,
    if (axes.isNotEmpty) 'axes': axes,
    'contains': contains.toList()..sort(),
    'attributes': attributes.toList()..sort(),
    'ingredient_ids': ingredientIds.toList()..sort(),
    'time_bucket': timeBucket,
    'calorie_bucket': calorieBucket,
    'ingredients': [for (final i in ingredients) i.toJson()],
    'steps': [for (final s in steps) s.toJson()],
  };
}
