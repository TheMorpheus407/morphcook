import 'package:flutter/painting.dart' show Color;

/// Every user-visible string in the corpus is `Map<lang, String>`. Adding a
/// language is a data addition; it is never a schema change.
class Localized {
  const Localized(this._values);

  factory Localized.fromJson(Object? json) {
    if (json is Map) {
      return Localized(
        json.map((k, v) => MapEntry(k.toString(), v.toString())),
      );
    }
    return const Localized({});
  }

  static const Localized empty = Localized({});

  final Map<String, String> _values;

  bool get isEmpty => _values.isEmpty;
  bool get isNotEmpty => _values.isNotEmpty;

  /// Falls back to English, then to any language present, then to ''.
  String call(String lang) {
    final exact = _values[lang];
    if (exact != null && exact.isNotEmpty) return exact;
    final en = _values['en'];
    if (en != null && en.isNotEmpty) return en;
    for (final v in _values.values) {
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  Iterable<String> get allValues => _values.values;

  Map<String, String> toJson() => Map.unmodifiable(_values);
}

// ---------------------------------------------------------------------------
// Ontology
// ---------------------------------------------------------------------------

class ContainsFlag {
  const ContainsFlag({
    required this.id,
    required this.label,
    required this.category,
    required this.euAllergen,
  });

  factory ContainsFlag.fromJson(Map<String, dynamic> j) => ContainsFlag(
    id: j['id'] as String,
    label: Localized.fromJson(j['label']),
    category: j['category'] as String? ?? 'other',
    euAllergen: j['eu_allergen'] as bool? ?? false,
  );

  final String id;
  final Localized label;
  final String category;
  final bool euAllergen;
}

class CompoundFlag {
  const CompoundFlag({
    required this.id,
    required this.label,
    required this.expandsTo,
    required this.note,
  });

  factory CompoundFlag.fromJson(Map<String, dynamic> j) => CompoundFlag(
    id: j['id'] as String,
    label: Localized.fromJson(j['label']),
    expandsTo: (j['expands_to'] as List).cast<String>().toSet(),
    note: Localized.fromJson(j['note']),
  );

  final String id;
  final Localized label;
  final Set<String> expandsTo;
  final Localized note;
}

class LabelledId {
  const LabelledId(this.id, this.label, {this.note = Localized.empty});

  factory LabelledId.fromJson(Map<String, dynamic> j) => LabelledId(
    j['id'] as String,
    Localized.fromJson(j['label']),
    note: Localized.fromJson(j['note']),
  );

  final String id;
  final Localized label;
  final Localized note;
}

/// One row of the variant switcher. Data-driven: a new axis is a new entry in
/// `ontology.json` plus a key in each recipe's `axes` map. No engine change.
class VariantDimension {
  const VariantDimension({
    required this.id,
    required this.label,
    required this.note,
  });

  factory VariantDimension.fromJson(Map<String, dynamic> j) => VariantDimension(
    id: j['id'] as String,
    label: Localized.fromJson(j['label']),
    note: Localized.fromJson(j['note']),
  );

  final String id;
  final Localized label;
  final Localized note;
}

class Ontology {
  Ontology({
    required this.containsFlags,
    required this.compoundFlags,
    required this.efforts,
    required this.timeBuckets,
    required this.calorieBuckets,
    required this.techniques,
    required this.descriptors,
    required this.dimensions,
    required this.axisValues,
    required this.mealSlots,
    required this.certificationNote,
  });

  factory Ontology.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
        ((raw as List?) ?? const [])
            .map((e) => f((e as Map).cast<String, dynamic>()))
            .toList(growable: false);

    final attrs = (j['attributes'] as Map).cast<String, dynamic>();
    final axisRaw =
        (j['axis_values'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Ontology(
      containsFlags: {
        for (final f in list(j['contains_flags'], ContainsFlag.fromJson))
          f.id: f,
      },
      compoundFlags: {
        for (final f in list(j['compound_flags'], CompoundFlag.fromJson))
          f.id: f,
      },
      efforts: list(attrs['effort'], LabelledId.fromJson),
      timeBuckets: list(attrs['time_bucket'], LabelledId.fromJson),
      calorieBuckets: list(attrs['calorie_bucket'], LabelledId.fromJson),
      techniques: list(attrs['technique'], LabelledId.fromJson),
      descriptors: list(attrs['descriptor'], LabelledId.fromJson),
      dimensions: list(j['dimensions'], VariantDimension.fromJson),
      axisValues: axisRaw.map(
        (k, v) => MapEntry(k, list(v, LabelledId.fromJson)),
      ),
      mealSlots: list(j['meal_slots'], LabelledId.fromJson),
      certificationNote: Localized.fromJson(j['certification_note']),
    );
  }

  final Map<String, ContainsFlag> containsFlags;
  final Map<String, CompoundFlag> compoundFlags;
  final List<LabelledId> efforts;
  final List<LabelledId> timeBuckets;
  final List<LabelledId> calorieBuckets;
  final List<LabelledId> techniques;
  final List<LabelledId> descriptors;
  final List<VariantDimension> dimensions;
  final Map<String, List<LabelledId>> axisValues;
  final List<LabelledId> mealSlots;
  final Localized certificationNote;

  /// Expands user-facing shortcuts (`vegan`) into the raw contains-flags they
  /// stand for, leaving raw flags untouched.
  Set<String> expandAvoidFlags(Iterable<String> selected) {
    final out = <String>{};
    for (final id in selected) {
      final compound = compoundFlags[id];
      if (compound != null) {
        out.addAll(compound.expandsTo);
      } else if (containsFlags.containsKey(id)) {
        out.add(id);
      }
    }
    return out;
  }

  Localized labelForFlag(String id) =>
      containsFlags[id]?.label ??
      compoundFlags[id]?.label ??
      Localized({'en': id});

  Localized labelForAxisValue(String dimensionId, String valueId) {
    for (final v in axisValues[dimensionId] ?? const <LabelledId>[]) {
      if (v.id == valueId) return v.label;
    }
    if (dimensionId == 'effort') {
      for (final e in efforts) {
        if (e.id == valueId) return e.label;
      }
    }
    if (dimensionId == 'calorie_level') {
      for (final c in calorieBuckets) {
        if (c.id == valueId) return c.label;
      }
    }
    return Localized({'en': valueId});
  }

  Localized labelForDescriptor(String id) {
    for (final d in descriptors) {
      if (d.id == id) return d.label;
    }
    return compoundFlags[id]?.label ?? Localized({'en': id});
  }
}

// ---------------------------------------------------------------------------
// Ingredients
// ---------------------------------------------------------------------------

enum UnitType { mass, volume, count }

UnitType _unitTypeFrom(String raw) => switch (raw) {
  'mass' => UnitType.mass,
  'volume' => UnitType.volume,
  _ => UnitType.count,
};

class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.parent,
    required this.label,
    required this.aisle,
    required this.unitType,
    required this.flags,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> j) => IngredientNode(
    id: j['id'] as String,
    parent: j['parent'] as String?,
    label: Localized.fromJson(j['label']),
    aisle: j['aisle'] as String? ?? 'other',
    unitType: _unitTypeFrom(j['unit_type'] as String? ?? 'count'),
    flags: (j['flags'] as List? ?? const []).cast<String>().toSet(),
  );

  final String id;
  final String? parent;
  final Localized label;
  final String aisle;
  final UnitType unitType;
  final Set<String> flags;
}

class IngredientDictionary {
  IngredientDictionary(this.nodes, this.aisles)
    : _children = _buildChildren(nodes);

  factory IngredientDictionary.fromJson(Map<String, dynamic> j) {
    final nodes = <String, IngredientNode>{};
    for (final raw in (j['nodes'] as List)) {
      final n = IngredientNode.fromJson((raw as Map).cast<String, dynamic>());
      nodes[n.id] = n;
    }
    final aisles = ((j['aisles'] as List?) ?? const [])
        .map((e) => LabelledId.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return IngredientDictionary(nodes, aisles);
  }

  static Map<String, List<String>> _buildChildren(
    Map<String, IngredientNode> nodes,
  ) {
    final out = <String, List<String>>{};
    for (final n in nodes.values) {
      final p = n.parent;
      if (p != null) (out[p] ??= <String>[]).add(n.id);
    }
    return out;
  }

  final Map<String, IngredientNode> nodes;
  final List<LabelledId> aisles;
  final Map<String, List<String>> _children;

  IngredientNode? operator [](String id) => nodes[id];

  /// Avoidance propagates downward: avoiding `cheese` avoids parmesan too.
  Set<String> expandDownwards(Iterable<String> ids) {
    final out = <String>{};
    final stack = <String>[...ids];
    while (stack.isNotEmpty) {
      final id = stack.removeLast();
      if (!out.add(id)) continue;
      stack.addAll(_children[id] ?? const <String>[]);
    }
    return out;
  }

  List<String> ancestorsOf(String id) {
    final out = <String>[];
    var cur = nodes[id]?.parent;
    while (cur != null) {
      out.add(cur);
      cur = nodes[cur]?.parent;
    }
    return out;
  }

  Localized aisleLabel(String id) {
    for (final a in aisles) {
      if (a.id == id) return a.label;
    }
    return Localized({'en': id});
  }

  /// Ordering used to group a shopping list; unknown aisles sink to the bottom.
  int aisleRank(String id) {
    final i = aisles.indexWhere((a) => a.id == id);
    return i < 0 ? aisles.length : i;
  }

  List<IngredientNode> search(String query, String lang, {int limit = 20}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final starts = <IngredientNode>[];
    final contains = <IngredientNode>[];
    for (final n in nodes.values) {
      final label = n.label(lang).toLowerCase();
      if (label.startsWith(q)) {
        starts.add(n);
      } else if (label.contains(q) || n.id.contains(q)) {
        contains.add(n);
      }
    }
    int byLabel(IngredientNode a, IngredientNode b) =>
        a.label(lang).compareTo(b.label(lang));
    starts.sort(byLabel);
    contains.sort(byLabel);
    return [...starts, ...contains].take(limit).toList(growable: false);
  }
}

class IngredientGuideEntry {
  const IngredientGuideEntry({
    required this.ingredientId,
    required this.title,
    required this.summary,
    required this.usage,
    required this.storage,
    required this.whereToFind,
  });

  factory IngredientGuideEntry.fromJson(Map<String, dynamic> j) =>
      IngredientGuideEntry(
        ingredientId: j['ingredient_id'] as String,
        title: Localized.fromJson(j['title']),
        summary: Localized.fromJson(j['summary']),
        usage: Localized.fromJson(j['usage']),
        storage: Localized.fromJson(j['storage']),
        whereToFind: Localized.fromJson(j['where_to_find']),
      );

  final String ingredientId;
  final Localized title;
  final Localized summary;
  final Localized usage;
  final Localized storage;
  final Localized whereToFind;
}

// ---------------------------------------------------------------------------
// Recipes & dishes
// ---------------------------------------------------------------------------

class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredientId,
    required this.qty,
    required this.unit,
    required this.note,
    required this.optional,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
    ingredientId: j['ingredient_id'] as String,
    qty: (j['qty'] as num?)?.toDouble(),
    unit: j['unit'] as String? ?? '',
    note: Localized.fromJson(j['note']),
    optional: j['optional'] as bool? ?? false,
  );

  final String ingredientId;
  final double? qty;
  final String unit;
  final Localized note;
  final bool optional;

  RecipeIngredient scaled(double factor) => RecipeIngredient(
    ingredientId: ingredientId,
    qty: qty == null ? null : qty! * factor,
    unit: unit,
    note: note,
    optional: optional,
  );
}

class RecipeStep {
  const RecipeStep({required this.text, required this.timerSeconds});

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
    text: Localized.fromJson(j['text']),
    timerSeconds: (j['timer_seconds'] as num?)?.toInt(),
  );

  final Localized text;
  final int? timerSeconds;
}

class Macros {
  const Macros({
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory Macros.fromJson(Map<String, dynamic>? j) => Macros(
    proteinG: (j?['protein_g'] as num?)?.toDouble() ?? 0,
    carbsG: (j?['carbs_g'] as num?)?.toDouble() ?? 0,
    fatG: (j?['fat_g'] as num?)?.toDouble() ?? 0,
  );

  final double proteinG;
  final double carbsG;
  final double fatG;
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.blurb,
    required this.handwritten,
    required this.axes,
    required this.contains,
    required this.attributes,
    required this.techniques,
    required this.effort,
    required this.timeMinutes,
    required this.timeBucket,
    required this.servings,
    required this.caloriesPerServing,
    required this.macros,
    required this.mealSlots,
    required this.ingredients,
    required this.ingredientIds,
    required this.steps,
    required this.tips,
    required this.tags,
    required this.stripeColor,
    required this.isDishDefault,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
    id: j['id'] as String,
    dishId: j['dish_id'] as String,
    title: Localized.fromJson(j['title']),
    blurb: Localized.fromJson(j['blurb']),
    handwritten: Localized.fromJson(j['handwritten']),
    axes: (j['axes'] as Map).cast<String, dynamic>().map(
      (k, v) => MapEntry(k, v.toString()),
    ),
    contains: (j['contains'] as List? ?? const []).cast<String>().toSet(),
    attributes: (j['attributes'] as List? ?? const []).cast<String>().toSet(),
    techniques: (j['techniques'] as List? ?? const []).cast<String>().toList(),
    effort: j['effort'] as String? ?? 'medium',
    timeMinutes: (j['time_minutes'] as num?)?.toInt() ?? 0,
    timeBucket: j['time_bucket'] as String? ?? 't60',
    servings: (j['servings'] as num?)?.toInt() ?? 2,
    caloriesPerServing: (j['calories_per_serving'] as num?)?.toInt() ?? 0,
    macros: Macros.fromJson((j['macros'] as Map?)?.cast<String, dynamic>()),
    mealSlots: (j['meal_slots'] as List? ?? const []).cast<String>().toList(),
    ingredients: ((j['ingredients'] as List?) ?? const [])
        .map(
          (e) => RecipeIngredient.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(growable: false),
    ingredientIds: (j['ingredient_ids'] as List? ?? const [])
        .cast<String>()
        .toSet(),
    steps: ((j['steps'] as List?) ?? const [])
        .map((e) => RecipeStep.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false),
    tips: ((j['tips'] as List?) ?? const [])
        .map(Localized.fromJson)
        .toList(growable: false),
    tags: (j['tags'] as List? ?? const []).cast<String>().toList(),
    stripeColor: _parseColor(j['stripe_color'] as String?),
    isDishDefault: j['is_dish_default'] as bool? ?? false,
  );

  final String id;
  final String dishId;
  final Localized title;
  final Localized blurb;
  final Localized handwritten;
  final Map<String, String> axes;
  final Set<String> contains;
  final Set<String> attributes;
  final List<String> techniques;
  final String effort;
  final int timeMinutes;
  final String timeBucket;
  final int servings;
  final int caloriesPerServing;
  final Macros macros;
  final List<String> mealSlots;
  final List<RecipeIngredient> ingredients;
  final Set<String> ingredientIds;
  final List<RecipeStep> steps;
  final List<Localized> tips;
  final List<String> tags;
  final Color stripeColor;
  final bool isDishDefault;

  String? axis(String dimensionId) => axes[dimensionId];
}

class Dish {
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

  factory Dish.fromJson(Map<String, dynamic> j) => Dish(
    id: j['id'] as String,
    name: Localized.fromJson(j['name']),
    hero: Localized.fromJson(j['hero']),
    capCaption: Localized.fromJson(j['cap_caption']),
    stripeColor: _parseColor(j['stripe_color'] as String?),
    recipeIds: (j['recipe_ids'] as List? ?? const []).cast<String>().toList(),
    partitionId: j['partition_id'] as String? ?? 'core',
    secondaryPartitions: (j['secondary_partitions'] as List? ?? const [])
        .cast<String>()
        .toList(),
    cuisineTags: (j['cuisine_tags'] as List? ?? const [])
        .cast<String>()
        .toList(),
    frequencyTier: (j['frequency_tier'] as num?)?.toInt() ?? 2,
    categories: (j['categories'] as List? ?? const []).cast<String>().toList(),
    mealSlots: (j['meal_slots'] as List? ?? const []).cast<String>().toList(),
    tags: (j['tags'] as List? ?? const []).cast<String>().toList(),
  );

  final String id;
  final Localized name;
  final Localized hero;
  final Localized capCaption;
  final Color stripeColor;
  final List<String> recipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final int frequencyTier;
  final List<String> categories;
  final List<String> mealSlots;
  final List<String> tags;
}

Color _parseColor(String? hex) {
  if (hex == null) return const Color(0xFF9A8873);
  final cleaned = hex.replaceFirst('#', '');
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return const Color(0xFF9A8873);
  return Color(cleaned.length <= 6 ? 0xFF000000 | value : value);
}

// ---------------------------------------------------------------------------
// Partition manifest
// ---------------------------------------------------------------------------

class PartitionInfo {
  const PartitionInfo({
    required this.id,
    required this.file,
    required this.label,
    required this.dishIds,
    required this.dishCount,
    required this.recipeCount,
    required this.loading,
    required this.tier,
  });

  factory PartitionInfo.fromJson(Map<String, dynamic> j) => PartitionInfo(
    id: j['id'] as String,
    file: j['file'] as String,
    label: Localized.fromJson(j['label']),
    dishIds: (j['dish_ids'] as List? ?? const []).cast<String>().toList(),
    dishCount: (j['dish_count'] as num?)?.toInt() ?? 0,
    recipeCount: (j['recipe_count'] as num?)?.toInt() ?? 0,
    loading: j['loading'] as String? ?? 'lazy',
    tier: (j['tier'] as num?)?.toInt() ?? 2,
  );

  final String id;
  final String file;
  final Localized label;
  final List<String> dishIds;
  final int dishCount;
  final int recipeCount;
  final String loading;
  final int tier;

  bool get isEager => loading == 'eager';
}

class PartitionManifest {
  const PartitionManifest({
    required this.corpusVersion,
    required this.generatedAt,
    required this.partitions,
    required this.routing,
    required this.crossReferences,
    required this.prefetchOnIdle,
    required this.note,
  });

  factory PartitionManifest.fromJson(Map<String, dynamic> j) {
    final strategy =
        (j['loading_strategy'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PartitionManifest(
      corpusVersion: j['corpus_version'] as String? ?? '0',
      generatedAt: j['generated_at'] as String? ?? '',
      partitions: ((j['partitions'] as List?) ?? const [])
          .map(
            (e) => PartitionInfo.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
      routing: ((j['routing'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      crossReferences: ((j['cross_references'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false),
      prefetchOnIdle: (strategy['prefetch_on_idle'] as List? ?? const [])
          .cast<String>()
          .toList(),
      note: Localized.fromJson(strategy['note']),
    );
  }

  final String corpusVersion;
  final String generatedAt;
  final List<PartitionInfo> partitions;
  final Map<String, String> routing;
  final List<Map<String, dynamic>> crossReferences;
  final List<String> prefetchOnIdle;
  final Localized note;

  PartitionInfo? byId(String id) {
    for (final p in partitions) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Which partitions could hold this dish, primary first.
  List<String> partitionsFor(String dishId) {
    final primary = routing[dishId];
    final out = <String>[?primary];
    for (final ref in crossReferences) {
      if (ref['dish_id'] == dishId) {
        out.addAll((ref['also_in'] as List? ?? const []).cast<String>());
      }
    }
    return out;
  }
}

// ---------------------------------------------------------------------------
// FAQ
// ---------------------------------------------------------------------------

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.anchor,
    required this.question,
    required this.answer,
    required this.keywords,
    required this.related,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
    id: j['id'] as String,
    category: j['category'] as String? ?? 'features',
    anchor: j['anchor'] as String? ?? j['id'] as String,
    question: Localized.fromJson(j['question']),
    answer: Localized.fromJson(j['answer']),
    keywords: (j['keywords'] as List? ?? const []).cast<String>().toList(),
    related: (j['related'] as List? ?? const []).cast<String>().toList(),
  );

  final String id;
  final String category;
  final String anchor;
  final Localized question;
  final Localized answer;
  final List<String> keywords;
  final List<String> related;

  bool matches(String query, String lang) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (question(lang).toLowerCase().contains(q)) return true;
    if (answer(lang).toLowerCase().contains(q)) return true;
    return keywords.any((k) => k.toLowerCase().contains(q));
  }
}

class FaqCollection {
  const FaqCollection({required this.categories, required this.entries});

  factory FaqCollection.fromJson(Map<String, dynamic> j) => FaqCollection(
    categories: ((j['categories'] as List?) ?? const [])
        .map((e) => LabelledId.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false),
    entries: ((j['entries'] as List?) ?? const [])
        .map((e) => FaqEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false),
  );

  final List<LabelledId> categories;
  final List<FaqEntry> entries;

  FaqEntry? byAnchor(String anchor) {
    for (final e in entries) {
      if (e.anchor == anchor) return e;
    }
    return null;
  }

  FaqEntry? byId(String id) {
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }
}
