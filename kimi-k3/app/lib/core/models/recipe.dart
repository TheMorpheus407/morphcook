import 'local_text.dart';

class Ingredient {
  final String id;
  final LocalText name;
  final double amount;
  final String unit; // g | ml | pcs | tbsp | tsp | cloves | pinch | cup
  final String aisle; // produce|protein|dairy|pantry|spices|bakery|frozen
  final LocalText note;

  const Ingredient({
    required this.id,
    required this.name,
    required this.amount,
    required this.unit,
    this.aisle = 'pantry',
    this.note = const {},
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) => Ingredient(
        id: json['id'] as String,
        name: parseLocalText(json['name']),
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String? ?? 'pcs',
        aisle: json['aisle'] as String? ?? 'pantry',
        note: parseLocalText(json['note']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'unit': unit,
        'aisle': aisle,
        'note': note,
      };
}

class RecipeStep {
  final LocalText text;
  final int? timerSeconds;

  const RecipeStep({required this.text, this.timerSeconds});

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        text: parseLocalText(json['text']),
        timerSeconds: json['timer_seconds'] as int?,
      );

  Map<String, dynamic> toJson() =>
      {'text': text, 'timer_seconds': timerSeconds};
}

class Macros {
  final double proteinG;
  final double carbsG;
  final double fatG;

  const Macros({required this.proteinG, required this.carbsG, required this.fatG});

  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
        proteinG: (json['protein_g'] as num).toDouble(),
        carbsG: (json['carbs_g'] as num).toDouble(),
        fatG: (json['fat_g'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG};
}

/// One fully-authored variant of a dish. The lattice coordinates live in
/// [dimensions] (diet / effort / calorie_level, extensible to future axes).
class Recipe {
  final String id;
  final String dishId;
  final LocalText title;
  final Map<String, String> dimensions;
  final Set<String> contains;
  final Set<String> attributes;
  final int timeMinutes;
  final int caloriesPerServing;
  final int servings;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final Macros macros;
  final List<String> tags;
  final List<String> mealTypes;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.dimensions,
    required this.contains,
    required this.attributes,
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.macros,
    this.tags = const [],
    this.mealTypes = const [],
  });

  String get diet => dimensions['diet'] ?? 'classic';
  String get effort => dimensions['effort'] ?? 'easy';
  String get calorieLevel => dimensions['calorie_level'] ?? 'hearty';

  Set<String> get ingredientIds => ingredients.map((i) => i.id).toSet();

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        dishId: json['dish_id'] as String,
        title: parseLocalText(json['title']),
        dimensions: (json['dimensions'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            const {},
        contains: (json['contains'] as List?)?.cast<String>().toSet() ?? {},
        attributes:
            (json['attributes'] as List?)?.cast<String>().toSet() ?? {},
        timeMinutes: json['time_minutes'] as int? ?? 30,
        caloriesPerServing: json['calories_per_serving'] as int? ?? 0,
        servings: json['servings'] as int? ?? 2,
        ingredients: (json['ingredients'] as List? ?? [])
            .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
            .toList(),
        steps: (json['steps'] as List? ?? [])
            .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
            .toList(),
        macros: json['macros'] != null
            ? Macros.fromJson(json['macros'] as Map<String, dynamic>)
            : const Macros(proteinG: 0, carbsG: 0, fatG: 0),
        tags: (json['tags'] as List?)?.cast<String>() ?? const [],
        mealTypes: (json['meal_types'] as List?)?.cast<String>() ?? const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dish_id': dishId,
        'title': title,
        'dimensions': dimensions,
        'contains': contains.toList(),
        'attributes': attributes.toList(),
        'time_minutes': timeMinutes,
        'calories_per_serving': caloriesPerServing,
        'servings': servings,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'macros': macros.toJson(),
        'tags': tags,
        'meal_types': mealTypes,
      };
}
