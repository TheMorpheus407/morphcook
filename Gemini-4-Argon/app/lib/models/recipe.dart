import 'localized_text.dart';

class RecipeMacros {
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;

  const RecipeMacros({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.fiberG = 0,
  });

  factory RecipeMacros.fromJson(Map<String, dynamic>? json, {int fallbackCal = 500}) {
    if (json == null) {
      return RecipeMacros(
        calories: fallbackCal,
        proteinG: 20,
        carbsG: 50,
        fatG: 20,
        fiberG: 5,
      );
    }
    return RecipeMacros(
      calories: (json['calories'] as num?)?.toInt() ?? fallbackCal,
      proteinG: (json['protein_g'] as num?)?.toInt() ?? 20,
      carbsG: (json['carbs_g'] as num?)?.toInt() ?? 50,
      fatG: (json['fat_g'] as num?)?.toInt() ?? 20,
      fiberG: (json['fiber_g'] as num?)?.toInt() ?? 5,
    );
  }

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
        'fiber_g': fiberG,
      };
}

class RecipeIngredient {
  final String id;
  final LocalizedText name;
  final double amount;
  final String unit;
  final String aisle;
  final LocalizedText? note;

  const RecipeIngredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    required this.aisle,
    this.note,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id']?.toString() ?? '',
      name: LocalizedText.fromJson(json['name']),
      amount: (json['amount'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit']?.toString() ?? 'pcs',
      aisle: json['aisle']?.toString() ?? 'pantry',
      note: json['note'] != null ? LocalizedText.fromJson(json['note']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name.toJson(),
        'amount': amount,
        'unit': unit,
        'aisle': aisle,
        if (note != null) 'note': note!.toJson(),
      };

  RecipeIngredient scaled(double factor) {
    return RecipeIngredient(
      id: id,
      name: name,
      amount: amount * factor,
      unit: unit,
      aisle: aisle,
      note: note,
    );
  }

  String formattedAmount([double scaleFactor = 1.0]) {
    final val = amount * scaleFactor;
    if ((val - val.roundToDouble()).abs() < 0.05) {
      return val.round().toString();
    }
    return val.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }
}

class RecipeStep {
  final int stepNumber;
  final LocalizedText title;
  final LocalizedText instruction;
  final int? timerSeconds;
  final LocalizedText? tip;

  const RecipeStep({
    required this.stepNumber,
    required this.title,
    required this.instruction,
    this.timerSeconds,
    this.tip,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      stepNumber: (json['step_number'] as num?)?.toInt() ?? 1,
      title: LocalizedText.fromJson(json['title']),
      instruction: LocalizedText.fromJson(json['instruction']),
      timerSeconds: (json['timer_seconds'] as num?)?.toInt(),
      tip: json['tip'] != null ? LocalizedText.fromJson(json['tip']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'step_number': stepNumber,
        'title': title.toJson(),
        'instruction': instruction.toJson(),
        if (timerSeconds != null) 'timer_seconds': timerSeconds,
        if (tip != null) 'tip': tip!.toJson(),
      };
}

class Recipe {
  final String id;
  final String dishId;
  final LocalizedText title;
  final LocalizedText subtitle;
  final String dietDimension;
  final String effort; // 'easy' | 'medium' | 'hard'
  final int timeMinutes;
  final String timeBucket; // '≤15' | '≤30' | '≤60' | '>60'
  final int servings;
  final int caloriesPerServing;
  final String calorieBucket; // '≤400' | '≤600' | '≤800' | '>800'
  final RecipeMacros macros;
  final Set<String> contains;
  final Set<String> attributes;
  final List<String> techniques;
  final Set<String> ingredientIds;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Map<String, List<String>> tags;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.subtitle,
    required this.dietDimension,
    required this.effort,
    required this.timeMinutes,
    required this.timeBucket,
    required this.servings,
    required this.caloriesPerServing,
    required this.calorieBucket,
    required this.macros,
    required this.contains,
    required this.attributes,
    required this.techniques,
    required this.ingredientIds,
    required this.ingredients,
    required this.steps,
    required this.tags,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final cals = (json['calories_per_serving'] as num?)?.toInt() ?? 500;
    final rawIngredients = (json['ingredients'] as List<dynamic>? ?? const [])
        .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
        .toList();
    final rawIngredientIds = (json['ingredient_ids'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toSet() ??
        rawIngredients.map((i) => i.id).toSet();

    final rawTags = json['tags'] as Map<String, dynamic>? ?? {};
    final parsedTags = <String, List<String>>{};
    for (final entry in rawTags.entries) {
      parsedTags[entry.key] = (entry.value as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList();
    }

    return Recipe(
      id: json['id']?.toString() ?? '',
      dishId: json['dish_id']?.toString() ?? '',
      title: LocalizedText.fromJson(json['title']),
      subtitle: LocalizedText.fromJson(json['subtitle'] ?? json['description']),
      dietDimension: json['diet_dimension']?.toString() ?? 'classic',
      effort: json['effort']?.toString() ?? 'easy',
      timeMinutes: (json['time_minutes'] as num?)?.toInt() ?? 30,
      timeBucket: json['time_bucket']?.toString() ?? '≤30',
      servings: (json['servings'] as num?)?.toInt() ?? 2,
      caloriesPerServing: cals,
      calorieBucket: json['calorie_bucket']?.toString() ?? _deriveCalorieBucket(cals),
      macros: RecipeMacros.fromJson(
        json['macros'] as Map<String, dynamic>?,
        fallbackCal: cals,
      ),
      contains: ((json['contains'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      attributes: ((json['attributes'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
      techniques: ((json['techniques'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      ingredientIds: rawIngredientIds,
      ingredients: rawIngredients,
      steps: ((json['steps'] as List<dynamic>?) ?? const [])
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: parsedTags,
    );
  }

  static String _deriveCalorieBucket(int cals) {
    if (cals <= 400) return '≤400';
    if (cals <= 600) return '≤600';
    if (cals <= 800) return '≤800';
    return '>800';
  }

  bool get isBreakfast => attributes.contains('breakfast');
  bool get isDinner => attributes.contains('dinner');
  bool get isLunch => attributes.contains('lunch');
}
