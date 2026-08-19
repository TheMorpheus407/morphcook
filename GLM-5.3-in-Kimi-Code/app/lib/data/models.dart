/// Data models mirroring the bundled JSON corpus (see app/assets/).
///
/// All user-visible text is `Map<lang, String>` so adding a language is a
/// data addition, never a schema change.
library;

import 'dart:ui' show Color;

import '../l10n.dart' show Lang;

class LText {
  final Map<String, String> map;
  const LText(this.map);
  factory LText.fromJson(Map<String, dynamic> json) =>
      LText(json.map((k, v) => MapEntry(k, v.toString())));
  Map<String, dynamic> toJson() => map;
  String get(Lang lang) => map[lang.name] ?? map['en'] ?? '';
}

class RecipeIngredient {
  final String id;
  final double amount;
  final String unit;
  final LText? note;
  const RecipeIngredient({
    required this.id,
    required this.amount,
    required this.unit,
    this.note,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) =>
      RecipeIngredient(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        unit: json['unit'] as String,
        note: json['note'] == null
            ? null
            : LText.fromJson(json['note'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'unit': unit,
        if (note != null) 'note': note!.toJson(),
      };
}

class RecipeStep {
  final LText text;
  final int? timerSeconds;
  const RecipeStep({required this.text, this.timerSeconds});

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
        text: LText.fromJson(json['text'] as Map<String, dynamic>),
        timerSeconds: json['timer_seconds'] as int?,
      );

  Map<String, dynamic> toJson() =>
      {'text': text.toJson(), if (timerSeconds != null) 'timer_seconds': timerSeconds};
}

class Macros {
  final double protein;
  final double carbs;
  final double fat;
  const Macros({required this.protein, required this.carbs, required this.fat});
  factory Macros.fromJson(Map<String, dynamic> json) => Macros(
        protein: (json['protein'] as num).toDouble(),
        carbs: (json['carbs'] as num).toDouble(),
        fat: (json['fat'] as num).toDouble(),
      );
  Map<String, dynamic> toJson() =>
      {'protein': protein, 'carbs': carbs, 'fat': fat};
}

class Recipe {
  final String id;
  final String dishId;
  final LText title;
  final LText subtitle;
  final String diet; // key into ontology.diet_labels
  final int servings;
  final int timeMinutes;
  final String effort; // easy | medium | hard
  final int caloriesPerServing;
  final Macros macros;
  final List<String> contains; // contains-flags
  final List<String> techniques;
  final String? mealType; // breakfast | lunch | dinner | null
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<LText> tips;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.title,
    required this.subtitle,
    required this.diet,
    required this.servings,
    required this.timeMinutes,
    required this.effort,
    required this.caloriesPerServing,
    required this.macros,
    required this.contains,
    required this.techniques,
    required this.ingredients,
    required this.steps,
    required this.tips,
    this.mealType,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final attrs = (json['attributes'] as Map<String, dynamic>?) ?? const {};
    return Recipe(
      id: json['id'] as String,
      dishId: json['dish_id'] as String,
      title: LText.fromJson(json['title'] as Map<String, dynamic>),
      subtitle: LText.fromJson(json['subtitle'] as Map<String, dynamic>),
      diet: json['diet'] as String,
      servings: json['servings'] as int,
      timeMinutes: json['time_minutes'] as int,
      effort: json['effort'] as String,
      caloriesPerServing: json['calories_per_serving'] as int,
      macros: Macros.fromJson(json['macros'] as Map<String, dynamic>),
      contains: (json['contains'] as List).cast<String>(),
      techniques: ((attrs['techniques'] as List?) ?? const []).cast<String>(),
      mealType: attrs['meal_type'] as String?,
      ingredients: (json['ingredients'] as List)
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List)
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      tips: (json['tips'] as List? ?? const [])
          .map((e) => LText.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Calorie bucket per ontology: <=400 | <=600 | <=800 | >800.
  String get calorieBucket {
    final c = caloriesPerServing;
    if (c <= 400) return '<=400';
    if (c <= 600) return '<=600';
    if (c <= 800) return '<=800';
    return '>800';
  }

  /// Time bucket per ontology.
  String get timeBucket {
    final t = timeMinutes;
    if (t <= 15) return '<=15';
    if (t <= 30) return '<=30';
    if (t <= 60) return '<=60';
    return '>60';
  }

  Set<String> get ingredientIds => ingredients.map((i) => i.id).toSet();
}

class Dish {
  final String id;
  final LText canonicalName;
  final LText hero;
  final LText capCaption;
  final String stripeColor; // hex, e.g. #C1543C
  final List<String> variants; // recipe ids
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final int frequencyTier;
  final String? mealType;

  const Dish({
    required this.id,
    required this.canonicalName,
    required this.hero,
    required this.capCaption,
    required this.stripeColor,
    required this.variants,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
    this.mealType,
  });

  factory Dish.fromJson(Map<String, dynamic> json) => Dish(
        id: json['id'] as String,
        canonicalName: LText.fromJson(json['canonical_name'] as Map<String, dynamic>),
        hero: LText.fromJson(json['hero'] as Map<String, dynamic>),
        capCaption: LText.fromJson(json['cap_caption'] as Map<String, dynamic>),
        stripeColor: json['stripe_color'] as String,
        variants: (json['variants'] as List).cast<String>(),
        partitionId: json['partition_id'] as String,
        secondaryPartitions:
            ((json['secondary_partitions'] as List?) ?? const []).cast<String>(),
        cuisineTags: ((json['cuisine_tags'] as List?) ?? const []).cast<String>(),
        frequencyTier: json['frequency_tier'] as int? ?? 2,
        mealType: json['meal_type'] as String?,
      );

  Color get color => _parseColor(stripeColor);
}

class FlagDef {
  final LText label;
  final String group;
  const FlagDef(this.label, this.group);
}

class CompoundFlag {
  final LText label;
  final List<String> expandsTo;
  final LText note;
  const CompoundFlag(this.label, this.expandsTo, this.note);
}

class AttributeDef {
  final LText label;
  final List<String> values;
  final Map<String, LText> valueLabels;
  const AttributeDef(this.label, this.values, this.valueLabels);
}

class DietLabel {
  final LText label;
  final String? compoundFlag;
  const DietLabel(this.label, this.compoundFlag);
}

class Ontology {
  final Map<String, FlagDef> containsFlags;
  final Map<String, CompoundFlag> compoundFlags;
  final Map<String, AttributeDef> attributes;
  final Map<String, DietLabel> dietLabels;

  const Ontology(this.containsFlags, this.compoundFlags, this.attributes,
      this.dietLabels);

  static Ontology fromJson(Map<String, dynamic> json) {
    final contains = <String, FlagDef>{};
    (json['contains_flags'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      contains[k] = FlagDef(
        LText.fromJson(m['label'] as Map<String, dynamic>),
        m['group'] as String? ?? 'other',
      );
    });
    final compound = <String, CompoundFlag>{};
    (json['compound_flags'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      compound[k] = CompoundFlag(
        LText.fromJson(m['label'] as Map<String, dynamic>),
        (m['expands_to'] as List).cast<String>(),
        LText.fromJson(m['note'] as Map<String, dynamic>),
      );
    });
    final attrs = <String, AttributeDef>{};
    (json['attributes'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      final labels = <String, LText>{};
      (m['value_labels'] as Map<String, dynamic>).forEach((vk, vv) {
        labels[vk] = LText.fromJson(vv as Map<String, dynamic>);
      });
      attrs[k] = AttributeDef(
        LText.fromJson(m['label'] as Map<String, dynamic>),
        (m['values'] as List).cast<String>(),
        labels,
      );
    });
    final diets = <String, DietLabel>{};
    (json['diet_labels'] as Map<String, dynamic>).forEach((k, v) {
      final m = v as Map<String, dynamic>;
      diets[k] = DietLabel(
        LText.fromJson(m['label'] as Map<String, dynamic>),
        m['compound_flag'] as String?,
      );
    });
    return Ontology(contains, compound, attrs, diets);
  }

  /// Expand compound avoid-flags into base contains-flags (idempotent).
  Set<String> expandAvoidFlags(Set<String> flags) {
    final out = <String>{};
    final queue = List<String>.from(flags);
    while (queue.isNotEmpty) {
      final f = queue.removeLast();
      if (out.contains(f)) continue;
      final compound = compoundFlags[f];
      if (compound != null) {
        out.add(f); // keep the compound itself too
        queue.addAll(compound.expandsTo);
      } else if (containsFlags.containsKey(f)) {
        out.add(f);
      }
    }
    return out;
  }

  LText flagLabel(String flag) => containsFlags[flag]?.label ?? LText(const {});
}

class IngredientNode {
  final String id;
  final String? parent;
  final LText name;
  final String aisle;
  final String? unitType;
  final String? flag;
  const IngredientNode({
    required this.id,
    this.parent,
    required this.name,
    required this.aisle,
    this.unitType,
    this.flag,
  });

  factory IngredientNode.fromJson(Map<String, dynamic> json) =>
      IngredientNode(
        id: json['id'] as String,
        parent: json['parent'] as String?,
        name: LText.fromJson(json['name'] as Map<String, dynamic>),
        aisle: json['aisle'] as String,
        unitType: json['unit_type'] as String?,
        flag: json['flag'] as String?,
      );
}

/// Flat, pre-indexed ingredient dictionary with parent/child navigation.
class IngredientIndex {
  final Map<String, IngredientNode> nodes;
  final Map<String, Set<String>> _children;
  final Map<String, Set<String>> _subtreeCache = {};

  IngredientIndex(this.nodes, this._children);

  factory IngredientIndex.fromJson(List<dynamic> raw) {
    final nodes = <String, IngredientNode>{};
    final children = <String, Set<String>>{};
    for (final e in raw) {
      final n = IngredientNode.fromJson(e as Map<String, dynamic>);
      nodes[n.id] = n;
      if (n.parent != null) {
        children.putIfAbsent(n.parent!, () => {}).add(n.id);
      }
    }
    return IngredientIndex(nodes, children);
  }

  Set<String> childrenOf(String id) => _children[id] ?? const {};

  /// id + all descendants — avoiding a parent excludes everything beneath it.
  Set<String> subtreeOf(String id) {
    final cached = _subtreeCache[id];
    if (cached != null) return cached;
    final out = <String>{id};
    final stack = List<String>.from(childrenOf(id));
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      if (!out.add(cur)) continue;
      stack.addAll(childrenOf(cur));
    }
    _subtreeCache[id] = out;
    return out;
  }

  /// All flags derivable from an ingredient id (its own + ancestors).
  Set<String> flagsOf(String id) {
    final out = <String>{};
    String? cur = id;
    while (cur != null) {
      final node = nodes[cur];
      if (node == null) break;
      if (node.flag != null) out.add(node.flag!);
      cur = node.parent;
    }
    return out;
  }

  /// Searchable suggestions: any node whose name matches in either language.
  List<IngredientNode> search(String query, {int limit = 8}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <IngredientNode>[];
    for (final n in nodes.values) {
      final en = n.name.map['en']?.toLowerCase() ?? '';
      final de = n.name.map['de']?.toLowerCase() ?? '';
      if (en.startsWith(q) || de.startsWith(q)) {
        hits.add(n);
        if (hits.length >= limit) break;
      }
    }
    if (hits.length < limit) {
      for (final n in nodes.values) {
        if (hits.contains(n)) continue;
        final en = n.name.map['en']?.toLowerCase() ?? '';
        final de = n.name.map['de']?.toLowerCase() ?? '';
        if (en.contains(q) || de.contains(q)) {
          hits.add(n);
          if (hits.length >= limit) break;
        }
      }
    }
    return hits;
  }
}

class FaqEntry {
  final String id;
  final String category;
  final LText question;
  final LText answer;
  final List<String> relatedIds;
  final String? relatedScreen;

  const FaqEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.relatedIds,
    this.relatedScreen,
  });

  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
        id: json['id'] as String,
        category: json['category'] as String,
        question: LText.fromJson(json['question'] as Map<String, dynamic>),
        answer: LText.fromJson(json['answer'] as Map<String, dynamic>),
        relatedIds: ((json['related_faq_ids'] as List?) ?? const []).cast<String>(),
        relatedScreen: json['related_screen'] as String?,
      );
}

class GuideEntry {
  final String id;
  final LText name;
  final LText description;
  final LText usage;
  final LText storage;
  final LText where;

  const GuideEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.usage,
    required this.storage,
    required this.where,
  });

  factory GuideEntry.fromJson(Map<String, dynamic> json) => GuideEntry(
        id: json['id'] as String,
        name: LText.fromJson(json['name'] as Map<String, dynamic>),
        description: LText.fromJson(json['description'] as Map<String, dynamic>),
        usage: LText.fromJson(json['usage'] as Map<String, dynamic>),
        storage: LText.fromJson(json['storage'] as Map<String, dynamic>),
        where: LText.fromJson(json['where'] as Map<String, dynamic>),
      );
}

class PartitionInfo {
  final String id;
  final String file;
  final String loadedAt;
  final int recipeCount;
  final List<String> dishIds;
  final LText description;
  const PartitionInfo({
    required this.id,
    required this.file,
    required this.loadedAt,
    required this.recipeCount,
    required this.dishIds,
    required this.description,
  });

  factory PartitionInfo.fromJson(String id, Map<String, dynamic> json) =>
      PartitionInfo(
        id: id,
        file: json['file'] as String,
        loadedAt: json['loaded_at'] as String,
        recipeCount: json['recipe_count'] as int,
        dishIds: (json['dish_ids'] as List).cast<String>(),
        description: LText.fromJson(json['description'] as Map<String, dynamic>),
      );
}

class CorpusManifest {
  final int version;
  final int totalRecipes;
  final int totalDishes;
  final Map<String, PartitionInfo> partitions;
  const CorpusManifest(this.version, this.totalRecipes, this.totalDishes, this.partitions);

  factory CorpusManifest.fromJson(Map<String, dynamic> json) {
    final parts = <String, PartitionInfo>{};
    (json['partitions'] as Map<String, dynamic>).forEach((k, v) {
      parts[k] = PartitionInfo.fromJson(k, v as Map<String, dynamic>);
    });
    return CorpusManifest(
      json['version'] as int? ?? 1,
      json['total_recipes'] as int? ?? 0,
      json['total_dishes'] as int? ?? 0,
      parts,
    );
  }
}

Color _parseColor(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  if (v == null) return const Color(0xFFC1543C);
  return Color(v);
}
