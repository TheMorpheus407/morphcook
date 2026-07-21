import 'package:collection/collection.dart';

import 'json_helpers.dart';
import 'localized_text.dart';

class Nutrition {
  const Nutrition({
    required this.calories,
    required this.proteinGrams,
    required this.carbohydrateGrams,
    required this.fatGrams,
    this.fiberGrams,
  });

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
    calories: jsonInt(json['calories']),
    proteinGrams: jsonDouble(json['protein_g'] ?? json['protein_grams']),
    carbohydrateGrams: jsonDouble(
      json['carbs_g'] ?? json['carbohydrate_grams'],
    ),
    fatGrams: jsonDouble(json['fat_g'] ?? json['fat_grams']),
    fiberGrams: json['fiber_g'] == null
        ? null
        : jsonDouble(json['fiber_g'] ?? json['fiber_grams']),
  );

  final int calories;
  final double proteinGrams;
  final double carbohydrateGrams;
  final double fatGrams;
  final double? fiberGrams;

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein_g': proteinGrams,
    'carbs_g': carbohydrateGrams,
    'fat_g': fatGrams,
    if (fiberGrams != null) 'fiber_g': fiberGrams,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Nutrition &&
          calories == other.calories &&
          proteinGrams == other.proteinGrams &&
          carbohydrateGrams == other.carbohydrateGrams &&
          fatGrams == other.fatGrams &&
          fiberGrams == other.fiberGrams;

  @override
  int get hashCode => Object.hash(
    calories,
    proteinGrams,
    carbohydrateGrams,
    fatGrams,
    fiberGrams,
  );
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredientId,
    required this.quantity,
    required this.unit,
    this.preparation,
    this.optional = false,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        ingredientId: jsonString(json['ingredient_id'] ?? json['id']),
        quantity: jsonDouble(json['quantity'] ?? json['amount']),
        unit: jsonString(json['unit'], 'piece'),
        preparation: json['preparation'] == null
            ? null
            : LocalizedText.fromJson(json['preparation']),
        optional: jsonBool(json['optional']),
      );

  final String ingredientId;
  final double quantity;
  final String unit;
  final LocalizedText? preparation;
  final bool optional;

  RecipeIngredient scaled(double factor) => RecipeIngredient(
    ingredientId: ingredientId,
    quantity: quantity * factor,
    unit: unit,
    preparation: preparation,
    optional: optional,
  );

  Map<String, dynamic> toJson() => {
    'ingredient_id': ingredientId,
    'quantity': quantity,
    'unit': unit,
    if (preparation != null) 'preparation': preparation!.toJson(),
    if (optional) 'optional': true,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeIngredient &&
          ingredientId == other.ingredientId &&
          quantity == other.quantity &&
          unit == other.unit &&
          preparation == other.preparation &&
          optional == other.optional;

  @override
  int get hashCode =>
      Object.hash(ingredientId, quantity, unit, preparation, optional);
}

class RecipeStep {
  const RecipeStep({
    required this.id,
    required this.text,
    this.timerSeconds,
    this.tip,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json, {int? index}) =>
      RecipeStep(
        id: jsonString(json['id'], index == null ? '' : 'step-${index + 1}'),
        text: LocalizedText.fromJson(json['text'] ?? json['instruction']),
        timerSeconds: json['timer_seconds'] == null
            ? null
            : jsonInt(json['timer_seconds']),
        tip: json['tip'] == null ? null : LocalizedText.fromJson(json['tip']),
      );

  final String id;
  final LocalizedText text;
  final int? timerSeconds;
  final LocalizedText? tip;

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text.toJson(),
    if (timerSeconds != null) 'timer_seconds': timerSeconds,
    if (tip != null) 'tip': tip!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeStep &&
          id == other.id &&
          text == other.text &&
          timerSeconds == other.timerSeconds &&
          tip == other.tip;

  @override
  int get hashCode => Object.hash(id, text, timerSeconds, tip);
}

/// A fully-authored recipe variant belonging to a [Dish].
class Recipe {
  Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.description,
    Map<String, String> variantDimensions = const {},
    Set<String> contains = const {},
    Set<String> attributes = const {},
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.servings,
    required this.nutrition,
    List<RecipeIngredient> ingredients = const [],
    List<RecipeStep> steps = const [],
    Set<String> tags = const {},
    Map<String, List<String>> searchTerms = const {},
    Set<String> mealTypes = const {},
    Set<String> cuisineTags = const {},
    required this.partitionId,
  }) : variantDimensions = UnmodifiableMapView(Map.of(variantDimensions)),
       contains = UnmodifiableSetView(Set.of(contains)),
       attributes = UnmodifiableSetView(Set.of(attributes)),
       ingredients = UnmodifiableListView(List.of(ingredients)),
       steps = UnmodifiableListView(List.of(steps)),
       tags = UnmodifiableSetView(Set.of(tags)),
       searchTerms = UnmodifiableMapView({
         for (final entry in searchTerms.entries)
           normalizeLanguageCode(entry.key): UnmodifiableListView(
             List.of(entry.value),
           ),
       }),
       mealTypes = UnmodifiableSetView(Set.of(mealTypes)),
       cuisineTags = UnmodifiableSetView(Set.of(cuisineTags));

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawNutrition = jsonMap(json['nutrition']);
    final calories = jsonInt(
      json['calories_per_serving'] ?? rawNutrition['calories'],
    );
    final rawDimensions = jsonMap(
      json['variant_dimensions'] ?? json['dimensions'],
    );
    final rawSearchTerms = jsonMap(json['search_terms']);
    final rawIngredients = jsonList(json['ingredients']);
    final rawSteps = jsonList(json['steps'] ?? json['method']);

    return Recipe(
      id: jsonString(json['id']),
      dishId: jsonString(json['dish_id']),
      name: LocalizedText.fromJson(
        json['name'] ?? json['names'] ?? json['title'],
      ),
      description: LocalizedText.fromJson(
        json['description'] ?? json['descriptions'] ?? json['hero_text'],
      ),
      variantDimensions: {
        for (final entry in rawDimensions.entries)
          entry.key: jsonString(entry.value),
      },
      contains: jsonStringSet(json['contains'] ?? json['contains_flags']),
      attributes: jsonStringSet(json['attributes']),
      timeMinutes: jsonInt(json['time_minutes']),
      caloriesPerServing: calories,
      servings: jsonInt(json['servings'], 2),
      nutrition: Nutrition.fromJson({...rawNutrition, 'calories': calories}),
      ingredients: [
        for (final value in rawIngredients)
          RecipeIngredient.fromJson(jsonMap(value)),
      ],
      steps: [
        for (var index = 0; index < rawSteps.length; index++)
          RecipeStep.fromJson(jsonMap(rawSteps[index]), index: index),
      ],
      tags: jsonStringSet(json['tags']),
      searchTerms: {
        for (final entry in rawSearchTerms.entries)
          normalizeLanguageCode(entry.key): jsonStringList(entry.value),
      },
      mealTypes: jsonStringSet(json['meal_types']),
      cuisineTags: jsonStringSet(json['cuisine_tags']),
      partitionId: jsonString(json['partition_id'], 'core'),
    );
  }

  final String id;
  final String dishId;
  final LocalizedText name;
  final LocalizedText description;
  final Map<String, String> variantDimensions;
  final Set<String> contains;
  final Set<String> attributes;
  final int timeMinutes;
  final int caloriesPerServing;
  final int servings;
  final Nutrition nutrition;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Set<String> tags;
  final Map<String, List<String>> searchTerms;
  final Set<String> mealTypes;
  final Set<String> cuisineTags;
  final String partitionId;

  String? dimensionValue(String dimension) => variantDimensions[dimension];

  String get effort =>
      variantDimensions['effort'] ??
      attributes.firstWhereOrNull(
        (value) => const {'easy', 'medium', 'hard'}.contains(value),
      ) ??
      'medium';

  String get diet => variantDimensions['diet'] ?? 'classic';

  String get calorieLevel => variantDimensions['calorie_level'] ?? 'balanced';

  Set<String> get ingredientIds =>
      ingredients.map((ingredient) => ingredient.ingredientId).toSet();

  bool hasAttribute(String attribute) => attributes.contains(attribute);

  List<RecipeIngredient> ingredientsForServings(int desiredServings) {
    if (servings <= 0) return ingredients;
    final factor = desiredServings / servings;
    return ingredients.map((ingredient) => ingredient.scaled(factor)).toList();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'dish_id': dishId,
    'name': name.toJson(),
    'description': description.toJson(),
    'variant_dimensions': variantDimensions,
    'contains': contains.toList()..sort(),
    'attributes': attributes.toList()..sort(),
    'time_minutes': timeMinutes,
    'calories_per_serving': caloriesPerServing,
    'servings': servings,
    'nutrition': nutrition.toJson(),
    'ingredients': ingredients.map((value) => value.toJson()).toList(),
    'steps': steps.map((value) => value.toJson()).toList(),
    'tags': tags.toList()..sort(),
    if (searchTerms.isNotEmpty) 'search_terms': searchTerms,
    'meal_types': mealTypes.toList()..sort(),
    'cuisine_tags': cuisineTags.toList()..sort(),
    'partition_id': partitionId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recipe &&
          id == other.id &&
          dishId == other.dishId &&
          name == other.name &&
          description == other.description &&
          const MapEquality<String, String>().equals(
            variantDimensions,
            other.variantDimensions,
          ) &&
          const SetEquality<String>().equals(contains, other.contains) &&
          const SetEquality<String>().equals(attributes, other.attributes) &&
          timeMinutes == other.timeMinutes &&
          caloriesPerServing == other.caloriesPerServing &&
          servings == other.servings &&
          nutrition == other.nutrition &&
          const ListEquality<RecipeIngredient>().equals(
            ingredients,
            other.ingredients,
          ) &&
          const ListEquality<RecipeStep>().equals(steps, other.steps) &&
          const SetEquality<String>().equals(tags, other.tags) &&
          const DeepCollectionEquality().equals(
            searchTerms,
            other.searchTerms,
          ) &&
          const SetEquality<String>().equals(mealTypes, other.mealTypes) &&
          const SetEquality<String>().equals(cuisineTags, other.cuisineTags) &&
          partitionId == other.partitionId;

  @override
  int get hashCode => Object.hashAll([
    id,
    dishId,
    name,
    description,
    const MapEquality<String, String>().hash(variantDimensions),
    const SetEquality<String>().hash(contains),
    const SetEquality<String>().hash(attributes),
    timeMinutes,
    caloriesPerServing,
    servings,
    nutrition,
    const ListEquality<RecipeIngredient>().hash(ingredients),
    const ListEquality<RecipeStep>().hash(steps),
    const SetEquality<String>().hash(tags),
    const DeepCollectionEquality().hash(searchTerms),
    const SetEquality<String>().hash(mealTypes),
    const SetEquality<String>().hash(cuisineTags),
    partitionId,
  ]);
}
