/// Corpus data models. All user-visible text is `Map<String, dynamic>`
/// (`Map<lang, String>`) so adding a language is a data addition only.
library;

typedef L10nText = Map<String, dynamic>;

class RecipeIngredient {
  final String ingredientId;
  final double qty;
  final String unit;
  final L10nText? note;
  final bool optional;

  const RecipeIngredient({
    required this.ingredientId,
    required this.qty,
    required this.unit,
    this.note,
    this.optional = false,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) => RecipeIngredient(
        ingredientId: json['ingredient_id'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] as Map<String, dynamic>?,
        optional: json['optional'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'ingredient_id': ingredientId,
        'qty': qty,
        'unit': unit,
        if (note != null) 'note': note,
        if (optional) 'optional': true,
      };
}

class RecipeStep {
  final L10nText text;
  final int? timerSeconds;

  const RecipeStep({required this.text, this.timerSeconds});

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        text: json['text'] as Map<String, dynamic>,
        timerSeconds: json['timer_seconds'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        if (timerSeconds != null) 'timer_seconds': timerSeconds,
      };
}

class Recipe {
  final String id;
  final String dishId;
  final L10nText title;
  final L10nText blurb;
  final L10nText handwritten;
  final String dietAxis;
  final String effortAxis;
  final String calorieLevelAxis;
  final List<String> contains;
  final List<String> attributes;
  final List<String> techniques;
  final String effort;
  final int timeMinutes;
  final String timeBucket;
  final String calorieBucket;
  final int servings;
  final int caloriesPerServing;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final List<String> mealSlots;
  final List<String> tags;
  final List<RecipeIngredient> ingredients;
  final List<String> ingredientIds;
  final List<RecipeStep> steps;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.blurb,
    required this.handwritten,
    required this.dietAxis,
    required this.effortAxis,
    required this.calorieLevelAxis,
    required this.contains,
    required this.attributes,
    required this.techniques,
    required this.effort,
    required this.timeMinutes,
    required this.timeBucket,
    required this.calorieBucket,
    required this.servings,
    required this.caloriesPerServing,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.mealSlots,
    required this.tags,
    required this.ingredients,
    required this.ingredientIds,
    required this.steps,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final axes = json['axes'] as Map<String, dynamic>? ?? const {};
    final macros = json['macros'] as Map<String, dynamic>? ?? const {};
    return Recipe(
      id: json['id'] as String,
      dishId: json['dish_id'] as String,
      title: json['title'] as Map<String, dynamic>,
      blurb: (json['blurb'] as Map<String, dynamic>?) ?? const {},
      handwritten: (json['handwritten'] as Map<String, dynamic>?) ?? const {},
      dietAxis: axes['diet'] as String? ?? 'classic',
      effortAxis: axes['effort'] as String? ?? 'easy',
      calorieLevelAxis: axes['calorie_level'] as String? ?? 'standard',
      contains: (json['contains'] as List? ?? const []).cast<String>(),
      attributes: (json['attributes'] as List? ?? const []).cast<String>(),
      techniques: (json['techniques'] as List? ?? const []).cast<String>(),
      effort: json['effort'] as String? ?? 'easy',
      timeMinutes: json['time_minutes'] as int? ?? 30,
      timeBucket: json['time_bucket'] as String? ?? 't30',
      calorieBucket: json['calorie_bucket'] as String? ?? 'c600',
      servings: json['servings'] as int? ?? 2,
      caloriesPerServing: json['calories_per_serving'] as int? ?? 0,
      proteinG: (macros['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (macros['carbs_g'] as num?)?.toInt() ?? 0,
      fatG: (macros['fat_g'] as num?)?.toInt() ?? 0,
      mealSlots: (json['meal_slots'] as List? ?? const []).cast<String>(),
      tags: (json['tags'] as List? ?? const []).cast<String>(),
      ingredients: (json['ingredients'] as List? ?? const [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      ingredientIds:
          (json['ingredient_ids'] as List? ?? const []).cast<String>(),
      steps: (json['steps'] as List? ?? const [])
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Dish {
  final String id;
  final L10nText name;
  final L10nText hero;
  final L10nText capCaption;
  final String stripeColor;
  final List<String> recipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final int frequencyTier;
  final List<String> categories;
  final List<String> mealSlots;
  final List<String> tags;

  const Dish({
    required this.id,
    required this.name,
    required this.hero,
    required this.capCaption,
    required this.stripeColor,
    required this.recipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    required this.categories,
    required this.mealSlots,
    required this.tags,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        name: json['name'] as Map<String, dynamic>,
        hero: (json['hero'] as Map<String, dynamic>?) ?? const {},
        capCaption: (json['cap_caption'] as Map<String, dynamic>?) ?? const {},
        stripeColor: json['stripe_color'] as String? ?? '#C2703F',
        recipeIds: (json['recipe_ids'] as List? ?? const []).cast<String>(),
        partitionId: json['partition_id'] as String? ?? 'core',
        secondaryPartitions:
            (json['secondary_partitions'] as List? ?? const []).cast<String>(),
        cuisineTags: (json['cuisine_tags'] as List? ?? const []).cast<String>(),
        frequencyTier: json['frequency_tier'] as int? ?? 3,
        categories: (json['categories'] as List? ?? const []).cast<String>(),
        mealSlots: (json['meal_slots'] as List? ?? const []).cast<String>(),
        tags: (json['tags'] as List? ?? const []).cast<String>(),
      );
}

class IngredientNode {
  final String id;
  final L10nText name;
  final String aisle;
  final String form; // solid | liquid | count
  final List<IngredientNode> children;
  String? parentId;

  IngredientNode({
    required this.id,
    required this.name,
    required this.aisle,
    required this.form,
    required this.children,
    this.parentId,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json,
      {required String aisle, String? parentId}) {
    final node = IngredientNode(
      id: json['id'] as String,
      name: json['name'] as Map<String, dynamic>,
      aisle: json['aisle'] as String? ?? aisle,
      form: json['form'] as String? ?? 'solid',
      children: <IngredientNode>[],
      parentId: parentId,
    );
    final kids = json['children'] as List?;
    if (kids != null) {
      for (final k in kids) {
        node.children.add(IngredientNode.fromJson(k as Map<String, dynamic>,
            aisle: node.aisle, parentId: node.id));
      }
    }
    return node;
  }
}

class Aisle {
  final String id;
  final L10nText name;
  final int order;
  const Aisle({required this.id, required this.name, required this.order});
}

class IngredientDictionary {
  final List<Aisle> aisles;
  final List<IngredientNode> roots;
  final Map<String, IngredientNode> byId = {};

  IngredientDictionary({required this.aisles, required this.roots}) {
    void walk(IngredientNode n) {
      byId[n.id] = n;
      n.children.forEach(walk);
    }

    roots.forEach(walk);
  }

  factory IngredientDictionary.fromJson(Map<String, dynamic> json) {
    final aisles = (json['aisles'] as List? ?? const [])
        .map((a) => Aisle(
              id: a['id'] as String,
              name: a['name'] as Map<String, dynamic>,
              order: a['order'] as int? ?? 0,
            ))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final roots = (json['tree'] as List? ?? const [])
        .map((t) => IngredientNode.fromJson(t as Map<String, dynamic>,
            aisle: 'pantry'))
        .toList();
    return IngredientDictionary(aisles: aisles, roots: roots);
  }

  IngredientNode? operator [](String id) => byId[id];

  /// All descendant ids of [id], including [id] itself.
  Set<String> descendantsOf(String id) {
    final out = <String>{};
    final node = byId[id];
    if (node == null) return out;
    void walk(IngredientNode n) {
      out.add(n.id);
      n.children.forEach(walk);
    }

    walk(node);
    return out;
  }

  /// Every leaf + parent id, for typeahead.
  List<IngredientNode> allNodes() => byId.values.toList();
}

class Ontology {
  final Map<String, L10nText> containsFlags;
  final Map<String, List<String>> compoundExpansions;
  final Map<String, L10nText> compoundLabels;
  final Map<String, L10nText> attributes;
  final Map<String, L10nText> effortLabels;
  final Map<String, L10nText> timeBucketLabels;
  final Map<String, L10nText> calorieBucketLabels;
  final Map<String, L10nText> techniqueLabels;
  final Map<String, List<String>> dimensionValues;
  final Map<String, Map<String, L10nText>> dimensionLabels;

  const Ontology({
    required this.containsFlags,
    required this.compoundExpansions,
    required this.compoundLabels,
    required this.attributes,
    required this.effortLabels,
    required this.timeBucketLabels,
    required this.calorieBucketLabels,
    required this.techniqueLabels,
    required this.dimensionValues,
    required this.dimensionLabels,
  });

  factory Ontology.fromJson(Map<String, dynamic> json) {
    Map<String, L10nText> labeled(dynamic raw) {
      final out = <String, L10nText>{};
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is Map && v['label'] is Map<String, dynamic>) {
            out[k as String] = v['label'] as Map<String, dynamic>;
          }
        });
      }
      return out;
    }

    final compounds = <String, List<String>>{};
    final compoundLabels = <String, L10nText>{};
    final rawCompounds = json['compound_flags'] as Map? ?? const {};
    rawCompounds.forEach((k, v) {
      if (v is Map) {
        compounds[k as String] =
            ((v['expands_to'] as List? ?? const []).cast<String>());
        if (v['label'] is Map<String, dynamic>) {
          compoundLabels[k] = v['label'] as Map<String, dynamic>;
        }
      }
    });

    final dims = json['dimensions'] as Map? ?? const {};
    final dimValues = <String, List<String>>{};
    final dimLabels = <String, Map<String, L10nText>>{};
    dims.forEach((k, v) {
      if (v is Map) {
        dimValues[k as String] =
            ((v['values'] as List? ?? const []).cast<String>());
        final labels = <String, L10nText>{};
        final rawLabels = v['labels'] as Map? ?? const {};
        rawLabels.forEach((lk, lv) {
          if (lv is Map<String, dynamic>) labels[lk as String] = lv;
        });
        dimLabels[k] = labels;
      }
    });

    Map<String, L10nText> nestedLabels(String key) {
      final out = <String, L10nText>{};
      final raw = json[key] as Map? ?? const {};
      final labels = raw['labels'] as Map? ?? raw;
      labels.forEach((k, v) {
        if (v is Map<String, dynamic>) out[k as String] = v;
      });
      return out;
    }

    return Ontology(
      containsFlags: labeled(json['contains_flags']),
      compoundExpansions: compounds,
      compoundLabels: compoundLabels,
      attributes: labeled(json['attributes']),
      effortLabels: nestedLabels('effort'),
      timeBucketLabels: nestedLabels('time_bucket'),
      calorieBucketLabels: nestedLabels('calorie_bucket'),
      techniqueLabels: nestedLabels('techniques'),
      dimensionValues: dimValues,
      dimensionLabels: dimLabels,
    );
  }

  /// Expand a user-selected avoid flag: compound flags expand to their base
  /// contains-flags; plain contains-flags stay as-is.
  Set<String> expandAvoidFlag(String flag) {
    final expansion = compoundExpansions[flag];
    if (expansion != null) return expansion.toSet();
    return {flag};
  }
}

class Faq {
  final String id;
  final String category;
  final L10nText q;
  final L10nText a;
  final List<String> tags;

  const Faq({
    required this.id,
    required this.category,
    required this.q,
    required this.a,
    required this.tags,
  });

  factory Faq.fromJson(Map<String, dynamic> json) => Faq(
        id: json['id'] as String,
        category: json['category'] as String? ?? 'features',
        q: json['q'] as Map<String, dynamic>,
        a: json['a'] as Map<String, dynamic>,
        tags: (json['tags'] as List? ?? const []).cast<String>(),
      );
}

class GuideEntry {
  final String ingredientId;
  final L10nText description;
  final L10nText tip;
  final L10nText storage;
  final L10nText where;

  const GuideEntry({
    required this.ingredientId,
    required this.description,
    required this.tip,
    required this.storage,
    required this.where,
  });

  factory GuideEntry.fromJson(Map<String, dynamic> json) => GuideEntry(
        ingredientId: json['ingredient_id'] as String,
        description: (json['description'] as Map<String, dynamic>?) ?? const {},
        tip: (json['tip'] as Map<String, dynamic>?) ?? const {},
        storage: (json['storage'] as Map<String, dynamic>?) ?? const {},
        where: (json['where'] as Map<String, dynamic>?) ?? const {},
      );
}

class PartitionInfo {
  final String id;
  final String file;
  final String loading; // eager | idle_prefetch | lazy
  final String description;
  const PartitionInfo({
    required this.id,
    required this.file,
    required this.loading,
    required this.description,
  });
}

class PartitionManifest {
  final String corpusVersion;
  final List<PartitionInfo> partitions;
  final Map<String, ({String primary, List<String> alsoIn})> dishRouting;

  const PartitionManifest({
    required this.corpusVersion,
    required this.partitions,
    required this.dishRouting,
  });

  factory PartitionManifest.fromJson(Map<String, dynamic> json) {
    final routing = <String, ({String primary, List<String> alsoIn})>{};
    final rawDishes = json['dishes'] as Map? ?? const {};
    rawDishes.forEach((k, v) {
      if (v is Map) {
        routing[k as String] = (
          primary: v['primary'] as String? ?? 'core',
          alsoIn: ((v['also_in'] as List? ?? const []).cast<String>()),
        );
      }
    });
    return PartitionManifest(
      corpusVersion: json['corpus_version'] as String? ?? '0.0.0',
      partitions: (json['partitions'] as List? ?? const [])
          .map((p) => PartitionInfo(
                id: p['id'] as String,
                file: p['file'] as String,
                loading: p['loading'] as String? ?? 'lazy',
                description: p['description'] as String? ?? '',
              ))
          .toList(),
      dishRouting: routing,
    );
  }

  PartitionInfo? byId(String id) {
    for (final p in partitions) {
      if (p.id == id) return p;
    }
    return null;
  }
}
