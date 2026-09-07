import 'ltext.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.amount,
    required this.unit,
    this.note = LText.empty,
    this.nameOverride,
  });

  final String id;

  /// Null only for "to taste" / "pinch" style entries.
  final double? amount;
  final String unit;
  final LText note;
  final LText? nameOverride;

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        id: j['id'] as String,
        amount: (j['amount'] as num?)?.toDouble(),
        unit: (j['unit'] as String?) ?? 'piece',
        note: LText.fromJson(j['note']),
        nameOverride: j['name'] == null ? null : LText.fromJson(j['name']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'unit': unit,
        if (note.isNotEmpty) 'note': note.toJson(),
        if (nameOverride != null) 'name': nameOverride!.toJson(),
      };

  RecipeIngredient scaled(double factor) =>
      RecipeIngredient(id: id, amount: amount == null ? null : amount! * factor, unit: unit, note: note, nameOverride: nameOverride);
}

class RecipeStep {
  const RecipeStep({required this.text, this.timerSeconds});
  final LText text;
  final int? timerSeconds;

  factory RecipeStep.fromJson(Map<String, dynamic> j) =>
      RecipeStep(text: LText.fromJson(j['text']), timerSeconds: (j['timer_seconds'] as num?)?.toInt());

  Map<String, dynamic> toJson() => {'text': text.toJson(), if (timerSeconds != null) 'timer_seconds': timerSeconds};
}

class Macros {
  const Macros({required this.proteinG, required this.carbsG, required this.fatG});
  final double proteinG;
  final double carbsG;
  final double fatG;

  factory Macros.fromJson(Map<String, dynamic>? j) => Macros(
        proteinG: ((j?['protein_g'] as num?) ?? 0).toDouble(),
        carbsG: ((j?['carbs_g'] as num?) ?? 0).toDouble(),
        fatG: ((j?['fat_g'] as num?) ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG};
}

/// One fully authored variant of a dish. Siblings share [dishId].
class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.marginNote,
    required this.intro,
    required this.variant,
    required this.contains,
    required this.attributes,
    required this.technique,
    required this.timeMinutes,
    required this.servings,
    required this.caloriesPerServing,
    required this.macros,
    required this.mealTypes,
    required this.tags,
    required this.ingredients,
    required this.steps,
    required this.partitionId,
  });

  final String id;
  final String dishId;
  final LText title;
  final LText marginNote;
  final LText intro;

  /// Dimension → value, e.g. {diet: vegan, effort: easy, calorie_level: balanced}.
  final Map<String, String> variant;
  final Set<String> contains;

  /// Positive descriptors: derived compounds (vegan, halal…), effort,
  /// buckets and authored extras (keto, high-protein…).
  final Set<String> attributes;
  final List<String> technique;
  final int timeMinutes;
  final int servings;
  final int caloriesPerServing;
  final Macros macros;
  final List<String> mealTypes;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final String partitionId;

  String get diet => variant['diet'] ?? 'classic';
  String get effort => variant['effort'] ?? 'medium';
  String get calorieLevel => variant['calorie_level'] ?? '';
  Set<String> get ingredientIds => {for (final i in ingredients) i.id};
  bool get isBreakfast => mealTypes.contains('breakfast');
  bool get isDinner => mealTypes.contains('dinner');

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        dishId: j['dish_id'] as String,
        title: LText.fromJson(j['title']),
        marginNote: LText.fromJson(j['margin_note']),
        intro: LText.fromJson(j['intro']),
        variant: ((j['variant'] as Map?) ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString())),
        contains: {...((j['contains'] as List?) ?? const []).cast<String>()},
        attributes: {...((j['attributes'] as List?) ?? const []).cast<String>()},
        technique: ((j['technique'] as List?) ?? const []).cast<String>(),
        timeMinutes: ((j['time_minutes'] as num?) ?? 0).toInt(),
        servings: ((j['servings'] as num?) ?? 2).toInt(),
        caloriesPerServing: ((j['calories_per_serving'] as num?) ?? 0).toInt(),
        macros: Macros.fromJson(j['macros'] as Map<String, dynamic>?),
        mealTypes: ((j['meal_types'] as List?) ?? const []).cast<String>(),
        tags: ((j['tags'] as List?) ?? const []).cast<String>(),
        ingredients: ((j['ingredients'] as List?) ?? const [])
            .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: ((j['steps'] as List?) ?? const []).map((e) => RecipeStep.fromJson(e as Map<String, dynamic>)).toList(),
        partitionId: (j['partition_id'] as String?) ?? 'core',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dish_id': dishId,
        'title': title.toJson(),
        'margin_note': marginNote.toJson(),
        'intro': intro.toJson(),
        'variant': variant,
        'contains': contains.toList()..sort(),
        'attributes': attributes.toList()..sort(),
        'technique': technique,
        'time_minutes': timeMinutes,
        'servings': servings,
        'calories_per_serving': caloriesPerServing,
        'macros': macros.toJson(),
        'meal_types': mealTypes,
        'tags': tags,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'partition_id': partitionId,
      };
}
