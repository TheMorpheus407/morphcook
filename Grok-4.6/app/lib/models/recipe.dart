import 'localized.dart';

class RecipeIngredient {
  final String ingredientId;
  final double qty;
  final String unit;
  final LocalizedText? note;

  const RecipeIngredient({
    required this.ingredientId,
    required this.qty,
    required this.unit,
    this.note,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        ingredientId: json['ingredient_id'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] == null
            ? null
            : LocalizedText.fromJson(json['note'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'qty': qty,
        'unit': unit,
        if (note != null) 'note': note!.toJson(),
      };
}

class RecipeStep {
  final LocalizedText text;
  final int? timerMinutes;

  const RecipeStep({required this.text, this.timerMinutes});

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        text: LocalizedText.fromJson(json['text'] as Map<String, dynamic>),
        timerMinutes: json['timer_minutes'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'text': text.toJson(),
        if (timerMinutes != null) 'timer_minutes': timerMinutes,
      };
}

class Macros {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;

  const Macros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
        calories: (json['calories'] as num).round(),
        proteinG: (json['protein_g'] as num).round(),
        carbsG: (json['carbs_g'] as num).round(),
        fatG: (json['fat_g'] as num).round(),
      );

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };
}

class VariantCoords {
  final String diet;
  final String effort;
  final String calorie;

  const VariantCoords({
    required this.diet,
    required this.effort,
    required this.calorie,
  });

  factory VariantCoords.fromJson(Map<String, dynamic> json) => VariantCoords(
        diet: json['diet'] as String,
        effort: json['effort'] as String,
        calorie: json['calorie'] as String,
      );

  String operator [](String dimension) => switch (dimension) {
        'diet' => diet,
        'effort' => effort,
        'calorie' => calorie,
        _ => throw ArgumentError('unknown dimension $dimension'),
      };

  VariantCoords copyWith({String? diet, String? effort, String? calorie}) =>
      VariantCoords(
        diet: diet ?? this.diet,
        effort: effort ?? this.effort,
        calorie: calorie ?? this.calorie,
      );

  Map<String, dynamic> toJson() => {
        'diet': diet,
        'effort': effort,
        'calorie': calorie,
      };

  @override
  bool operator ==(Object other) =>
      other is VariantCoords &&
      other.diet == diet &&
      other.effort == effort &&
      other.calorie == calorie;

  @override
  int get hashCode => Object.hash(diet, effort, calorie);
}

class Recipe {
  final String id;
  final String dishId;
  final LocalizedText title;
  final LocalizedText caption;
  final LocalizedText intro;
  final VariantCoords variant;
  final Set<String> contains;
  final Set<String> attributes;
  final List<String> meal;
  final int timeMinutes;
  final int servings;
  final int caloriesPerServing;
  final Macros macros;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final LocalizedList tags;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.caption,
    required this.intro,
    required this.variant,
    required this.contains,
    required this.attributes,
    required this.meal,
    required this.timeMinutes,
    required this.servings,
    required this.caloriesPerServing,
    required this.macros,
    required this.ingredients,
    required this.steps,
    required this.tags,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final macros = json['macros'] == null
        ? const Macros(calories: 0, proteinG: 0, carbsG: 0, fatG: 0)
        : Macros.fromJson(json['macros'] as Map<String, dynamic>);
    return Recipe(
      id: json['id'] as String,
      dishId: json['dish_id'] as String,
      title: LocalizedText.fromJson(json['title'] as Map<String, dynamic>),
      caption: json['caption'] == null
          ? LocalizedText.empty
          : LocalizedText.fromJson(json['caption'] as Map<String, dynamic>),
      intro: json['intro'] == null
          ? LocalizedText.empty
          : LocalizedText.fromJson(json['intro'] as Map<String, dynamic>),
      variant: VariantCoords.fromJson(json['variant'] as Map<String, dynamic>),
      contains: Set<String>.from(json['contains'] as List? ?? const []),
      attributes: Set<String>.from(json['attributes'] as List? ?? const []),
      meal: List<String>.from(json['meal'] as List? ?? const []),
      timeMinutes: (json['time_minutes'] as num?)?.round() ?? 0,
      servings: (json['servings'] as num?)?.round() ?? 1,
      caloriesPerServing: (json['calories_per_serving'] as num?)?.round() ??
          macros.calories,
      macros: macros,
      ingredients: (json['ingredients'] as List? ?? const [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List? ?? const [])
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: json['tags'] == null
          ? LocalizedList.empty
          : LocalizedList.fromJson(json['tags'] as Map<String, dynamic>),
    );
  }

  Set<String> get ingredientIds =>
      ingredients.map((i) => i.ingredientId).toSet();

  String timeBucket() {
    if (timeMinutes <= 15) return 'le15';
    if (timeMinutes <= 30) return 'le30';
    if (timeMinutes <= 60) return 'le60';
    return 'gt60';
  }
}
