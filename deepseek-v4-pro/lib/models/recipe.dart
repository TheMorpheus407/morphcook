import 'dart:convert';

import 'package:flutter/material.dart';

/// A single recipe — one authored variant of a dish concept.
class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    this.diet = 'classic',
    required this.name,
    required this.blurb,
    required this.contains,
    required this.ingredientIds,
    required this.attributes,
    required this.effort,
    required this.timeMinutes,
    required this.timeBucket,
    required this.caloriesPerServing,
    required this.calorieBucket,
    required this.servings,
    required this.cuisine,
    required this.mealTypes,
    required this.technique,
    required this.tags,
    required this.stripeColors,
    required this.caption,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    this.reviewed = true,
  });

  final String id;
  final String dishId;

  /// Explicit diet label for the variant-switcher dimension.
  final String diet;
  final Map<String, String> name;
  final Map<String, String> blurb;
  final Set<String> contains;
  final List<String> ingredientIds;
  final Set<String> attributes;
  final String effort;
  final int timeMinutes;
  final String timeBucket;
  final int caloriesPerServing;
  final String calorieBucket;
  final int servings;
  final String cuisine;
  final Set<String> mealTypes;
  final Set<String> technique;
  final Set<String> tags;
  final List<Color> stripeColors;
  final Map<String, String> caption;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final Nutrition nutrition;
  final bool reviewed;

  factory Recipe.fromJson(Map<String, dynamic> json) {
    List<Color> stripes(List<dynamic>? hexes) => (hexes ?? const [])
        .map((h) {
          try {
            final value = int.parse(h.toString().replaceFirst('#', ''), radix: 16);
            return Color(0xFF000000 | value);
          } catch (_) {
            return const Color(0xFFD98E4A);
          }
        })
        .toList();
    return Recipe(
      id: json['id'] as String,
      dishId: json['dish_id'] as String,
      diet: json['diet'] as String? ?? 'classic',
      name: _langMap(json['name']),
      blurb: _langMap(json['blurb']),
      contains: (json['contains'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      ingredientIds:
          (json['ingredient_ids'] as List<dynamic>? ?? const []).cast<String>(),
      attributes: (json['attributes'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      effort: json['effort'] as String? ?? 'medium',
      timeMinutes: json['time_minutes'] as int? ?? 30,
      timeBucket: json['time_bucket'] as String? ?? 'le30',
      caloriesPerServing: json['calories_per_serving'] as int? ?? 500,
      calorieBucket: json['calorie_bucket'] as String? ?? 'le600',
      servings: json['servings'] as int? ?? 2,
      cuisine: json['cuisine'] as String? ?? '',
      mealTypes: (json['meal_types'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      technique: (json['technique'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>().toSet(),
      stripeColors: stripes(json['stripe_colors'] as List<dynamic>?),
      caption: _langMap(json['caption']),
      ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      nutrition: Nutrition.fromJson(
          json['nutrition'] as Map<String, dynamic>? ?? const {}),
      reviewed: json['reviewed'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dish_id': dishId,
        'diet': diet,
        'name': name,
        'blurb': blurb,
        'contains': contains.toList()..sort(),
        'ingredient_ids': ingredientIds,
        'attributes': attributes.toList()..sort(),
        'effort': effort,
        'time_minutes': timeMinutes,
        'time_bucket': timeBucket,
        'calories_per_serving': caloriesPerServing,
        'calorie_bucket': calorieBucket,
        'servings': servings,
        'cuisine': cuisine,
        'meal_types': mealTypes.toList()..sort(),
        'technique': technique.toList()..sort(),
        'tags': tags.toList()..sort(),
        'stripe_colors':
            stripeColors.map((c) => '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}').toList(),
        'caption': caption,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': steps.map((s) => s.toJson()).toList(),
        'nutrition': nutrition.toJson(),
        'reviewed': reviewed,
      };

  static Map<String, String> _langMap(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    if (v is String) return {'en': v};
    return const {};
  }
}

class RecipeIngredient {
  const RecipeIngredient({
    required this.id,
    required this.amount,
    required this.unit,
    this.note = const {},
  });

  final String id;
  final double amount;
  final String unit;
  final Map<String, String> note;

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        note: Recipe._langMap(json['note']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'amount': amount, 'unit': unit, 'note': note};
}

class RecipeStep {
  const RecipeStep({
    required this.title,
    required this.text,
    this.timerMinutes,
  });

  final Map<String, String> title;
  final Map<String, String> text;
  final int? timerMinutes;

  bool get hasTimer => timerMinutes != null && timerMinutes! > 0;

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        title: Recipe._langMap(json['title']),
        text: Recipe._langMap(json['text']),
        timerMinutes: (json['timer_minutes'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() =>
      {'title': title, 'text': text, 'timer_minutes': timerMinutes};
}

class Nutrition {
  const Nutrition({this.proteinG = 0, this.carbsG = 0, this.fatG = 0});

  final double proteinG;
  final double carbsG;
  final double fatG;

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
        proteinG: (json['protein_g'] as num? ?? 0).toDouble(),
        carbsG: (json['carbs_g'] as num? ?? 0).toDouble(),
        fatG: (json['fat_g'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() =>
      {'protein_g': proteinG, 'carbs_g': carbsG, 'fat_g': fatG};
}

/// Thin decode helper for raw corpus bytes.
Recipe recipeFromJsonString(String raw) =>
    Recipe.fromJson(jsonDecode(raw) as Map<String, dynamic>);
