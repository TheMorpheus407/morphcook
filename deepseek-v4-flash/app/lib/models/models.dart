import 'package:flutter/material.dart';

/// Domain models parsed from the bundled corpus + local state.
/// All user-visible text is `Map<lang, String>`.

extension FirstWhereOrNullExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

class IngredientRef {
  final String id;
  final double amount;
  final String unit;
  final Map<String, dynamic>? note;

  IngredientRef({
    required this.id,
    required this.amount,
    required this.unit,
    this.note,
  });

  factory IngredientRef.fromJson(Map<String, dynamic> j) => IngredientRef(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        unit: j['unit'] as String? ?? 'piece',
        note: j['note'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'unit': unit,
        if (note != null) 'note': note,
      };
}

class StepData {
  final Map<String, dynamic> text;
  final int timerSeconds;

  StepData({required this.text, this.timerSeconds = 0});

  factory StepData.fromJson(Map<String, dynamic> j) => StepData(
        text: (j['text'] as Map).cast<String, dynamic>(),
        timerSeconds: (j['timer_seconds'] as num?)?.toInt() ?? 0,
      );
}

class Recipe {
  final String id;
  final String dishId;
  final Map<String, dynamic> title;
  final Map<String, dynamic> summary;
  final Map<String, dynamic>? kitchenNotes;
  final String diet;
  final Set<String> contains;
  final List<String> attributes;
  final int timeMinutes;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int servings;
  final List<String> mealTypes;
  final List<String> tags;
  final List<IngredientRef> ingredients;
  final List<StepData> steps;

  Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.summary,
    this.kitchenNotes,
    required this.diet,
    required this.contains,
    required this.attributes,
    required this.timeMinutes,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servings,
    required this.mealTypes,
    required this.tags,
    required this.ingredients,
    required this.steps,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id'] as String,
        dishId: j['dish_id'] as String,
        title: (j['title'] as Map).cast<String, dynamic>(),
        summary: (j['summary'] as Map).cast<String, dynamic>(),
        kitchenNotes: j['kitchen_notes'] as Map<String, dynamic>?,
        diet: j['diet'] as String? ?? 'classic',
        contains: (j['contains'] as List? ?? const []).cast<String>().toSet(),
        attributes: (j['attributes'] as List? ?? const []).cast<String>(),
        timeMinutes: (j['time_minutes'] as num).toInt(),
        calories: (j['calories_per_serving'] as num? ?? 0).toInt(),
        protein: (j['protein_g'] as num? ?? 0).toInt(),
        carbs: (j['carbs_g'] as num? ?? 0).toInt(),
        fat: (j['fat_g'] as num? ?? 0).toInt(),
        servings: (j['servings'] as num? ?? 1).toInt(),
        mealTypes:
            (j['meal_types'] as List? ?? const []).cast<String>(),
        tags: (j['tags'] as List? ?? const []).cast<String>(),
        ingredients: (j['ingredients'] as List? ?? const [])
            .map((e) => IngredientRef.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        steps: (j['steps'] as List? ?? const [])
            .map((e) => StepData.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );

  List<String> get ingredientIds => ingredients.map((i) => i.id).toList();

  static const _efforts = {'easy', 'medium', 'hard'};
  static const _timeBuckets = {'≤15', '≤30', '≤60', '>60'};
  static const _calorieBuckets = {'≤400', '≤600', '≤800', '>800'};

  String? get effort => attributes.firstWhereOrNull((a) => _efforts.contains(a));

  String? get timeBucket =>
      attributes.firstWhereOrNull((a) => _timeBuckets.contains(a));

  String? get calorieBucket =>
      attributes.firstWhereOrNull((a) => _calorieBuckets.contains(a));

  List<String> get techniques => attributes
      .where((a) =>
          !_efforts.contains(a) &&
          !_timeBuckets.contains(a) &&
          !_calorieBuckets.contains(a) &&
          !a.startsWith('cuisine-'))
      .toList();

  bool get isBreakfast => mealTypes.contains('breakfast');
  bool get isDinner => mealTypes.contains('dinner');

  /// Scaled ingredient amount for [servings] portions.
  double amountFor(int servings, IngredientRef ing) =>
      ing.amount * servings / this.servings;
}

class Dish {
  final String id;
  final Map<String, dynamic> canonicalName;
  final Map<String, dynamic> heroText;
  final Map<String, dynamic> capCaption;
  final Color stripeColor;
  final List<String> variantIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;

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
  });

  factory Dish.fromJson(Map<String, dynamic> j) {
    final hex = (j['stripe_color'] as String? ?? '#c9703e').replaceAll('#', '');
    return Dish(
      id: j['id'] as String,
      canonicalName: (j['canonical_name'] as Map).cast<String, dynamic>(),
      heroText: (j['hero_text'] as Map? ?? const {}).cast<String, dynamic>(),
      capCaption: (j['cap_caption'] as Map? ?? const {}).cast<String, dynamic>(),
      stripeColor: Color(0xFF000000 | int.parse(hex, radix: 16)),
      variantIds:
          (j['variant_ids'] as List? ?? const []).cast<String>(),
      partitionId: j['partition_id'] as String? ?? 'extended',
      secondaryPartitions: (j['secondary_partitions'] as List? ?? const [])
          .cast<String>(),
      cuisineTags: (j['cuisine_tags'] as List? ?? const []).cast<String>(),
    );
  }

  Color get stripeSecondary => _lighten(stripeColor);

  static Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness * 0.8 + 0.25).clamp(0.0, 1.0))
        .toColor();
  }
}

class IngredientNode {
  final String id;
  final Map<String, dynamic> label;
  final List<IngredientNode> children;
  final String? parentId;
  final String? rootId; // top-level aisle id

  IngredientNode({
    required this.id,
    required this.label,
    required this.children,
    this.parentId,
    this.rootId,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> j,
      {String? parentId, String? rootId}) {
    final id = j['id'] as String;
    return IngredientNode(
      id: id,
      label: (j['label'] as Map).cast<String, dynamic>(),
      children: (j['children'] as List? ?? const [])
          .map((c) => IngredientNode.fromJson(
              (c as Map).cast<String, dynamic>(),
              parentId: id,
              rootId: rootId ?? (parentId == null ? id : null)))
          .toList(),
      parentId: parentId,
      rootId: rootId,
    );
  }

  bool get isLeaf => children.isEmpty;

  /// All descendant ids including self.
  List<String> descendants({bool includeSelf = true}) {
    final out = <String>[];
    if (includeSelf) out.add(id);
    for (final c in children) {
      out.addAll(c.descendants());
    }
    return out;
  }

  /// The top-level aisle id (root) for this node.
  String get aisle => rootId ?? id;

  /// The direct parent id or null.
  String? get parent => parentId;
}

class Ontology {
  final List<String> containsFlags;
  final Map<String, CompoundAvoid> compoundAvoids;
  final Map<String, Map<String, dynamic>> attributes;
  final List<String> dietOrder;

  Ontology({
    required this.containsFlags,
    required this.compoundAvoids,
    required this.attributes,
    required this.dietOrder,
  });

  factory Ontology.fromJson(Map<String, dynamic> j) => Ontology(
        containsFlags: (j['contains_flags'] as List).cast<String>(),
        compoundAvoids: (j['compound_avoids'] as Map).map((k, v) => MapEntry(
            k as String,
            CompoundAvoid.fromJson(
                k, (v as Map).cast<String, dynamic>()))),
        attributes: {
          for (final e in (j['attributes'] as Map).entries)
            e.key as String: switch (e.value) {
              final Map m => m.cast<String, dynamic>(),
              final List l => {
                  for (final id in l) id as String: <String, dynamic>{}
                },
              _ => throw FormatException(
                  'attribute group must be a map or list: ${e.key}'),
            }
        },
        dietOrder: (j['diet_order'] as List? ?? const []).cast<String>(),
      );

  CompoundAvoid? compound(String id) => compoundAvoids[id];

  /// Expand a set of user avoid-flags (which may include compounds) into the
  /// set of raw contains-flags that recipes carry.
  Set<String> expandAvoids(Set<String> flags) {
    final out = <String>{};
    for (final f in flags) {
      final c = compoundAvoids[f];
      if (c != null) {
        out.addAll(c.expandsTo);
      } else {
        out.add(f);
      }
    }
    return out;
  }
}

class CompoundAvoid {
  final String id;
  final Map<String, dynamic> label;
  final List<String> expandsTo;

  CompoundAvoid({
    required this.id,
    required this.label,
    required this.expandsTo,
  });

  factory CompoundAvoid.fromJson(String id, Map<String, dynamic> j) =>
      CompoundAvoid(
        id: id,
        label: (j['label'] as Map? ?? {}).cast<String, dynamic>(),
        expandsTo: (j['expands_to'] as List? ?? const []).cast<String>(),
      );
}

class GuideEntry {
  final Map<String, dynamic>? description;
  final Map<String, dynamic>? tips;
  final Map<String, dynamic>? storage;
  final Map<String, dynamic>? whereToFind;

  GuideEntry({
    this.description,
    this.tips,
    this.storage,
    this.whereToFind,
  });

  factory GuideEntry.fromJson(Map<String, dynamic> j) => GuideEntry(
        description: j['description'] as Map<String, dynamic>?,
        tips: j['tips'] as Map<String, dynamic>?,
        storage: j['storage'] as Map<String, dynamic>?,
        whereToFind: j['where_to_find'] as Map<String, dynamic>?,
      );
}

class FaqEntry {
  final String category;
  final Map<String, dynamic> question;
  final Map<String, dynamic> answer;
  final List<String> keywords;

  FaqEntry({
    required this.category,
    required this.question,
    required this.answer,
    required this.keywords,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
        category: j['category'] as String,
        question: (j['question'] as Map).cast<String, dynamic>(),
        answer: (j['answer'] as Map).cast<String, dynamic>(),
        keywords: (j['keywords'] as List? ?? const []).cast<String>(),
      );
}

class FaqCategory {
  final String id;
  final Map<String, dynamic> label;

  FaqCategory({required this.id, required this.label});

  factory FaqCategory.fromJson(Map<String, dynamic> j) => FaqCategory(
        id: j['id'] as String,
        label: (j['label'] as Map).cast<String, dynamic>(),
      );
}

/// User profile (profile + adaptation preferences).
class UserProfile {
  String name;
  String lang;
  Set<String> avoidFlags; // class-level + compounds
  Set<String> avoidIngredients;
  Set<String> requiredAttributes;
  int? maxTimeMinutes;
  int? calorieTarget;
  String? preferredEffort; // easy | medium | hard
  bool showVariantTags;
  bool? reduceMotion; // null = follow system
  bool visualAlertEnabled;
  bool quickNextTapEnabled;
  bool completedOnboarding;

  UserProfile({
    this.name = '',
    this.lang = 'en',
    Set<String>? avoidFlags,
    Set<String>? avoidIngredients,
    Set<String>? requiredAttributes,
    this.maxTimeMinutes,
    this.calorieTarget,
    this.preferredEffort,
    this.showVariantTags = true,
    this.reduceMotion,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.completedOnboarding = false,
  })  : avoidFlags = avoidFlags ?? {},
        avoidIngredients = avoidIngredients ?? {},
        requiredAttributes = requiredAttributes ?? {};

  static const calorieTolerance = 150;

  Map<String, dynamic> toJson() => {
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
        'visual_alert_enabled': visualAlertEnabled,
        'quick_next_tap_enabled': quickNextTapEnabled,
        'completed_onboarding': completedOnboarding,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] as String? ?? '',
        lang: j['lang'] as String? ?? 'en',
        avoidFlags:
            (j['avoid_flags'] as List? ?? const []).cast<String>().toSet(),
        avoidIngredients: (j['avoid_ingredients'] as List? ?? const [])
            .cast<String>()
            .toSet(),
        requiredAttributes: (j['required_attributes'] as List? ?? const [])
            .cast<String>()
            .toSet(),
        maxTimeMinutes: (j['max_time_minutes'] as num?)?.toInt(),
        calorieTarget: (j['calorie_target'] as num?)?.toInt(),
        preferredEffort: j['preferred_effort'] as String?,
        showVariantTags: j['show_variant_tags'] as bool? ?? true,
        reduceMotion: j['reduce_motion'] as bool?,
        visualAlertEnabled: j['visual_alert_enabled'] as bool? ?? true,
        quickNextTapEnabled: j['quick_next_tap_enabled'] as bool? ?? false,
        completedOnboarding: j['completed_onboarding'] as bool? ?? false,
      );
}

/// A saved recipe entry (cookbook).
class SavedEntry {
  final String recipeId;
  final DateTime savedAt;

  SavedEntry({required this.recipeId, required this.savedAt});
}

/// One cooking session in history.
class HistoryEntry {
  final String recipeId;
  final DateTime at;

  HistoryEntry({required this.recipeId, required this.at});
}

/// A weekly meal plan slot key: "mon.breakfast", "sun.dinner", …
String slotKey(String day, String meal) => '$day.$meal';

const mealNames = ['breakfast', 'lunch', 'dinner'];
const dayNames = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Shopping list source (one row = one recipe that was added).
class ShoppingLine {
  final String recipeId;
  final DateTime addedAt;
  final int? servings;

  ShoppingLine({
    required this.recipeId,
    required this.addedAt,
    this.servings,
  });
}

/// Aggregated shopping item, grouped per aisle.
class ShoppingItem {
  final String ingredientId;
  final String aisle;
  final double amount;
  final String unit;
  final int sourceCount;

  ShoppingItem({
    required this.ingredientId,
    required this.aisle,
    required this.amount,
    required this.unit,
    this.sourceCount = 1,
  });
}