import 'dart:ui' show Color;

import 'localized.dart';

class RecipeIngredient {
  const RecipeIngredient({required this.id, this.qty, required this.unit, this.note});

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
    id: j['id'] as String,
    qty: (j['qty'] as num?)?.toDouble(),
    unit: j['unit'] as String,
    note: j['note'] == null ? null : LText.fromJson(j['note']),
  );

  final String id;
  final double? qty;
  final String unit;
  final LText? note;

  /// Identity used for the morph highlight: same id + same amount + unit
  /// counts as "unchanged" between two variants.
  String get signature => '$id|$qty|$unit';
}

class RecipeStep {
  const RecipeStep({required this.text, this.timerSeconds});

  factory RecipeStep.fromJson(Map<String, dynamic> j) =>
      RecipeStep(text: LText.fromJson(j['text']), timerSeconds: j['timer_seconds'] as int?);

  final LText text;
  final int? timerSeconds;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.blurb,
    required this.note,
    required this.cuisine,
    required this.diet,
    required this.effort,
    required this.timeMinutes,
    required this.timeBucket,
    required this.servings,
    required this.calories,
    required this.calorieBucket,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.contains,
    required this.attributes,
    required this.techniques,
    required this.mealTypes,
    required this.tags,
    required this.dimensions,
    required this.ingredientIds,
    required this.ingredients,
    required this.steps,
    this.partitionId = 'core',
  });

  factory Recipe.fromJson(Map<String, dynamic> j, {String partitionId = 'core'}) {
    final macros = (j['macros'] as Map?) ?? const {};
    return Recipe(
      id: j['id'] as String,
      dishId: j['dish_id'] as String,
      title: LText.fromJson(j['title']),
      blurb: LText.fromJson(j['blurb']),
      note: LText.fromJson(j['note']),
      cuisine: j['cuisine'] as String? ?? '',
      diet: j['diet'] as String,
      effort: j['effort'] as String,
      timeMinutes: j['time_minutes'] as int,
      timeBucket: j['time_bucket'] as String? ?? '',
      servings: j['servings'] as int,
      calories: j['calories_per_serving'] as int,
      calorieBucket: j['calorie_bucket'] as String? ?? '',
      protein: (macros['protein_g'] as num?)?.toInt() ?? 0,
      carbs: (macros['carbs_g'] as num?)?.toInt() ?? 0,
      fat: (macros['fat_g'] as num?)?.toInt() ?? 0,
      contains: {for (final f in (j['contains'] as List? ?? const [])) f as String},
      attributes: {for (final a in (j['attributes'] as List? ?? const [])) a as String},
      techniques: [for (final t in (j['techniques'] as List? ?? const [])) t as String],
      mealTypes: [for (final m in (j['meal_types'] as List? ?? const [])) m as String],
      tags: [for (final t in (j['tags'] as List? ?? const [])) LText.fromJson(t)],
      dimensions: {for (final e in ((j['dimensions'] as Map?) ?? const {}).entries) e.key as String: e.value as String},
      ingredientIds: [for (final i in (j['ingredient_ids'] as List? ?? const [])) i as String],
      ingredients: [
        for (final i in (j['ingredients'] as List? ?? const [])) RecipeIngredient.fromJson(i as Map<String, dynamic>),
      ],
      steps: [for (final s in (j['steps'] as List? ?? const [])) RecipeStep.fromJson(s as Map<String, dynamic>)],
      partitionId: partitionId,
    );
  }

  final String id;
  final String dishId;
  final LText title;
  final LText blurb;
  final LText note;
  final String cuisine;
  final String diet;
  final String effort;
  final int timeMinutes;
  final String timeBucket;
  final int servings;
  final int calories;
  final String calorieBucket;
  final int protein;
  final int carbs;
  final int fat;
  final Set<String> contains;
  final Set<String> attributes;
  final List<String> techniques;
  final List<String> mealTypes;
  final List<LText> tags;
  final Map<String, String> dimensions;
  final List<String> ingredientIds;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final String partitionId;

  String dimension(String id) => dimensions[id] ?? '';
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.caption,
    required this.stripeColor,
    required this.cuisine,
    required this.variants,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
    id: j['id'] as String,
    name: LText.fromJson(j['name']),
    hero: LText.fromJson(j['hero']),
    caption: LText.fromJson(j['caption']),
    stripeColor: _parseColor(j['stripe_color'] as String? ?? '#D9826A'),
    cuisine: j['cuisine'] as String? ?? '',
    variants: [for (final v in (j['variants'] as List? ?? const [])) v as String],
    partitionId: j['partition_id'] as String? ?? 'core',
    secondaryPartitions: [for (final p in (j['secondary_partitions'] as List? ?? const [])) p as String],
    cuisineTags: [for (final c in (j['cuisine_tags'] as List? ?? const [])) c as String],
    frequencyTier: j['frequency_tier'] as String? ?? 'medium',
  );

  final String id;
  final LText name;
  final LText hero;
  final LText caption;
  final Color stripeColor;
  final String cuisine;
  final List<String> variants;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;

  static Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
  }
}
