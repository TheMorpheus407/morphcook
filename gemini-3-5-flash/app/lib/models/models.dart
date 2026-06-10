import 'dart:convert';

class UserProfile {
  String name;
  String lang;
  Set<String> avoidFlags;
  Set<String> avoidIngredients;
  Set<String> requiredAttributes;
  int maxTimeMinutes;
  int calorieTarget;
  String preferredEffort; // easy | medium | hard
  bool showVariantTags;
  bool? reduceMotion;

  UserProfile({
    required this.name,
    required this.lang,
    required this.avoidFlags,
    required this.avoidIngredients,
    required this.requiredAttributes,
    required this.maxTimeMinutes,
    required this.calorieTarget,
    required this.preferredEffort,
    this.showVariantTags = true,
    this.reduceMotion,
  });

  factory UserProfile.defaultProfile() {
    return UserProfile(
      name: "Cook",
      lang: "en",
      avoidFlags: {},
      avoidIngredients: {},
      requiredAttributes: {},
      maxTimeMinutes: 45,
      calorieTarget: 600,
      preferredEffort: "medium",
      showVariantTags: true,
      reduceMotion: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lang': lang,
      'avoid_flags': avoidFlags.toList(),
      'avoid_ingredients': avoidIngredients.toList(),
      'required_attributes': requiredAttributes.toList(),
      'max_time_minutes': maxTimeMinutes,
      'calorie_target': calorieTarget,
      'preferred_effort': preferredEffort,
      'show_variant_tags': showVariantTags,
      'reduce_motion': reduceMotion,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? 'Cook',
      lang: json['lang'] ?? 'en',
      avoidFlags: Set<String>.from(json['avoid_flags'] ?? []),
      avoidIngredients: Set<String>.from(json['avoid_ingredients'] ?? []),
      requiredAttributes: Set<String>.from(json['required_attributes'] ?? []),
      maxTimeMinutes: json['max_time_minutes'] ?? 45,
      calorieTarget: json['calorie_target'] ?? 600,
      preferredEffort: json['preferred_effort'] ?? 'medium',
      showVariantTags: json['show_variant_tags'] ?? true,
      reduceMotion: json['reduce_motion'],
    );
  }
}

class Dish {
  final String id;
  final Map<String, String> canonicalName;
  final Map<String, String> heroText;
  final Map<String, String> capCaption;
  final String stripeColor;
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;

  Dish({
    required this.id,
    required this.canonicalName,
    required this.heroText,
    required this.capCaption,
    required this.stripeColor,
    required this.variantIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> json) {
    return Dish(
      id: json['id'],
      canonicalName: Map<String, String>.from(json['canonical_name']),
      heroText: Map<String, String>.from(json['hero_text']),
      capCaption: Map<String, String>.from(json['cap_caption']),
      stripeColor: json['stripe_color'],
      variantIds: List<String>.from(json['variant_ids']),
      partitionId: json['partition_id'],
      secondaryPartitions: List<String>.from(json['secondary_partitions'] ?? []),
      cuisineTags: List<String>.from(json['cuisine_tags'] ?? []),
      frequencyTier: json['frequency_tier'] ?? 'high',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'canonical_name': canonicalName,
      'hero_text': heroText,
      'cap_caption': capCaption,
      'stripe_color': stripeColor,
      'variant_ids': variantIds,
      'partition_id': partitionId,
      'secondary_partitions': secondaryPartitions,
      'cuisine_tags': cuisineTags,
      'frequency_tier': frequencyTier,
    };
  }
}

class RecipeIngredient {
  final String id;
  final double amount;
  final String unit;
  final Map<String, String> name;
  final String aisle;

  RecipeIngredient({
    required this.id,
    required this.amount,
    required this.unit,
    required this.name,
    required this.aisle,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'],
      name: Map<String, String>.from(json['name']),
      aisle: json['aisle'] ?? 'pantry',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'unit': unit,
      'name': name,
      'aisle': aisle,
    };
  }
}

class RecipeStep {
  final Map<String, String> text;
  final int timerSeconds;

  RecipeStep({
    required this.text,
    required this.timerSeconds,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      text: Map<String, String>.from(json['text']),
      timerSeconds: json['timer_seconds'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'timer_seconds': timerSeconds,
    };
  }
}

class Recipe {
  final String id;
  final String dishId;
  final Map<String, String> name;
  final Map<String, String> description;
  final List<String> containsFlags;
  final List<String> attributes;
  final int timeMinutes;
  final int caloriesPerServing;
  final Map<String, dynamic> nutrition;
  final List<String> ingredientIds;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;

  Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.description,
    required this.containsFlags,
    required this.attributes,
    required this.timeMinutes,
    required this.caloriesPerServing,
    required this.nutrition,
    required this.ingredientIds,
    required this.ingredients,
    required this.steps,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    var ingredientsList = (json['ingredients'] as List)
        .map((i) => RecipeIngredient.fromJson(i))
        .toList();
    var stepsList = (json['steps'] as List)
        .map((s) => RecipeStep.fromJson(s))
        .toList();

    return Recipe(
      id: json['id'],
      dishId: json['dish_id'],
      name: Map<String, String>.from(json['name']),
      description: Map<String, String>.from(json['description']),
      containsFlags: List<String>.from(json['contains_flags'] ?? []),
      attributes: List<String>.from(json['attributes'] ?? []),
      timeMinutes: json['time_minutes'] ?? 0,
      caloriesPerServing: json['calories_per_serving'] ?? 0,
      nutrition: Map<String, dynamic>.from(json['nutrition'] ?? {}),
      ingredientIds: List<String>.from(json['ingredient_ids'] ?? []),
      ingredients: ingredientsList,
      steps: stepsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dish_id': dishId,
      'name': name,
      'description': description,
      'contains_flags': containsFlags,
      'attributes': attributes,
      'time_minutes': timeMinutes,
      'calories_per_serving': caloriesPerServing,
      'nutrition': nutrition,
      'ingredient_ids': ingredientIds,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }
}

class IngredientNode {
  final String id;
  final Map<String, String> name;
  final List<IngredientNode> children;

  IngredientNode({
    required this.id,
    required this.name,
    this.children = const [],
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json) {
    var childrenList = <IngredientNode>[];
    if (json['children'] != null) {
      childrenList = (json['children'] as List)
          .map((c) => IngredientNode.fromJson(c))
          .toList();
    }
    return IngredientNode(
      id: json['id'],
      name: Map<String, String>.from(json['name']),
      children: childrenList,
    );
  }

  /// Traverses and collects all descendant IDs of this node (including itself)
  Set<String> getAllDescendantIds() {
    var ids = {id};
    for (var child in children) {
      ids.addAll(child.getAllDescendantIds());
    }
    return ids;
  }
}

class FAQEntry {
  final String id;
  final Map<String, String> category;
  final Map<String, String> question;
  final Map<String, String> answer;

  FAQEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
  });

  factory FAQEntry.fromJson(Map<String, dynamic> json) {
    return FAQEntry(
      id: json['id'],
      category: Map<String, String>.from(json['category']),
      question: Map<String, String>.from(json['question']),
      answer: Map<String, String>.from(json['answer']),
    );
  }
}

/// Pure function matching logic
bool isRecipeVisible(Recipe recipe, UserProfile profile, {bool overrideCalorieTarget = false, int calorieTolerance = 150}) {
  // 1. Avoid class-level flags
  for (var flag in profile.avoidFlags) {
    if (recipe.containsFlags.contains(flag)) {
      return false;
    }
  }

  // 2. Avoid specific ingredients
  for (var ingredientId in profile.avoidIngredients) {
    if (recipe.ingredientIds.contains(ingredientId)) {
      return false;
    }
  }

  // 3. Required positive attributes (e.g. halal, kosher)
  for (var reqAttr in profile.requiredAttributes) {
    // Treat compound requirements like halal or kosher
    if (reqAttr == 'halal') {
      if (recipe.containsFlags.contains('pork') || recipe.containsFlags.contains('alcohol')) {
        return false;
      }
    } else if (reqAttr == 'kosher') {
      if (recipe.containsFlags.contains('pork') || recipe.containsFlags.contains('shellfish')) {
        return false;
      }
    } else if (!recipe.attributes.contains(reqAttr)) {
      return false;
    }
  }

  // 4. Max cooking time filter
  if (recipe.timeMinutes > profile.maxTimeMinutes) {
    return false;
  }

  // 5. Calorie target filter (with per-dish override switch support)
  if (!overrideCalorieTarget) {
    int diff = (recipe.caloriesPerServing - profile.calorieTarget).abs();
    if (diff > calorieTolerance) {
      return false;
    }
  }

  return true;
}

/// Pure function ranking score
double calculateRecipeScore({
  required Recipe recipe,
  required UserProfile profile,
  required DateTime currentTime,
  required List<String> recentlyCookedIds, // cooked within last 30 days
}) {
  double score = 0.0;

  // 1. Match count of required positive attributes
  int matchedRequired = 0;
  for (var reqAttr in profile.requiredAttributes) {
    if (recipe.attributes.contains(reqAttr)) {
      matchedRequired++;
    }
  }
  score += matchedRequired * 1000.0;

  // 2. Effort match
  if (recipe.attributes.contains(profile.preferredEffort)) {
    score += 500.0;
  }

  // 3. Time closeness (closer to budget is better, but smaller is preferred)
  double timeDiff = (recipe.timeMinutes - profile.maxTimeMinutes).abs().toDouble();
  score += (100.0 - timeDiff);

  // 4. Calorie closeness (closer to target is better)
  double calorieDiff = (recipe.caloriesPerServing - profile.calorieTarget).abs().toDouble();
  score += (200.0 - calorieDiff);

  // 5. Time-Aware Ranking:
  // - Morning context (5am–11am): Breakfast recipes (+200 bonus)
  // - Evening context (5pm–9pm): Dinner recipes (+90 bonus)
  // - Weekend context: Medium and hard effort recipes (+90 bonus)
  int hour = currentTime.hour;
  bool isBreakfastTime = hour >= 5 && hour < 11;
  bool isDinnerTime = hour >= 17 && hour < 21;
  bool isWeekend = currentTime.weekday == DateTime.saturday || currentTime.weekday == DateTime.sunday;

  if (isBreakfastTime && (recipe.attributes.contains('breakfast') || recipe.id.contains('breakfast'))) {
    score += 200.0;
  }
  if (isDinnerTime && (recipe.attributes.contains('dinner') || recipe.id.contains('dinner') || recipe.dishId == 'doener' || recipe.dishId == 'alfredo' || recipe.dishId == 'padthai')) {
    score += 90.0;
  }
  if (isWeekend && (recipe.attributes.contains('medium') || recipe.attributes.contains('hard'))) {
    score += 90.0;
  }

  // 6. Staleness-Aware Ranking:
  // - Recipes not cooked in 30+ days receive a +50 bonus
  // - Recently cooked or never-cooked recipes receive no bonus (wait, never-cooked is stale, but let's strictly follow the spec:
  // "Recipes that haven't been cooked recently get a boost to encourage variety:
  // - Recipes not cooked in 30+ days receive a +50 bonus
  // - Recently cooked or never-cooked recipes receive no bonus")
  // So, if a recipe has a record of being cooked but not within 30 days, or we check if it is in recentlyCookedIds.
  // recentlyCookedIds should only contain IDs cooked within the last 30 days. If it's NOT in recentlyCookedIds, and we have cooked it at least once in the past, or if we define "not cooked in 30+ days" as "not cooked recently" which includes never cooked or not in recentlyCookedIds? Let's check spec: "Recipes not cooked in 30+ days receive a +50 bonus. Recently cooked or never-cooked recipes receive no bonus."
  // Wait, so we need to know:
  // - was it cooked? (i.e. is it in full cooking history)
  // - was it cooked within 30 days? (i.e. recently)
  // If it was cooked in the past, but NOT in the last 30 days, it gets +50.
  // Let's implement that exactly:
  // if (cookedInPastButNotRecently) score += 50.0
  // To know if it was cooked in past but not recently, we can pass two lists:
  // `historyIds` (all-time cooked) and `recentlyCookedIds` (cooked in last 30 days).
  // Or we can just check if `historyIds.contains(recipe.id) && !recentlyCookedIds.contains(recipe.id)`. Let's do that!
  
  return score;
}
