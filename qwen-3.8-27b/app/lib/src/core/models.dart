/// Bilingual (N-language-ready) text: `Map<lang, String>`.
typedef LocalizedText = Map<String, String>;

class RecipeIngredientRef {
  const RecipeIngredientRef({
    required this.id,
    required this.amount,
    required this.unit,
    required this.noteEn,
    required this.noteDe,
    this.optional = false,
  });

  final String id;
  final double amount;
  final String unit; // unit id from ontology units (e.g. g, ml, clove, tbsp, pc, pinch)
  final String noteEn;
  final String noteDe;
  final bool optional;

  factory RecipeIngredientRef.fromJson(Map<String, dynamic> j) => RecipeIngredientRef(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        unit: j['unit'] as String? ?? 'pc',
        noteEn: j['note_en'] as String? ?? '',
        noteDe: j['note_de'] as String? ?? '',
        optional: j['optional'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'unit': unit,
        'note_en': noteEn,
        'note_de': noteDe,
        if (optional) 'optional': true,
      };
}

class RecipeStep {
  const RecipeStep({
    required this.textEn,
    required this.textDe,
    this.timerSeconds = 0,
  });

  final String textEn;
  final String textDe;

  /// Optional per-step timer for cook mode (0 = no timer).
  final int timerSeconds;

  String text(String lang) => lang == 'de' ? textDe : textEn;

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
        textEn: j['text_en'] as String,
        textDe: j['text_de'] as String,
        timerSeconds: j['timer_s'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'text_en': textEn,
        'text_de': textDe,
        if (timerSeconds > 0) 'timer_s': timerSeconds,
      };
}

class RecipeMacros {
  const RecipeMacros({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories; // per serving
  final double protein; // g
  final double carbs; // g
  final double fat; // g

  factory RecipeMacros.fromJson(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return RecipeMacros(
      calories: (m['kcal'] as num? ?? 0).toDouble(),
      protein: (m['protein_g'] as num? ?? 0).toDouble(),
      carbs: (m['carbs_g'] as num? ?? 0).toDouble(),
      fat: (m['fat_g'] as num? ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'kcal': calories,
        'protein_g': protein,
        'carbs_g': carbs,
        'fat_g': fat,
      };
}

class Recipe {
  const Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.ingredientRefs,
    required this.steps,
    required this.contains,
    required this.attributes,
    required this.tags,
    required this.macro,
    required this.timeMinutes,
    required this.prepMinutes,
    required this.serves,
    required this.dietClass,
    required this.effort,
    required this.calorieLevel,
    required this.techniques,
    required this.seasonMonths,
  });

  final String id;
  final String dishId;
  final LocalizedText name;
  final List<RecipeIngredientRef> ingredientRefs;
  final List<RecipeStep> steps;
  final List<String> contains;
  final List<String> attributes;
  final List<String> tags;
  final RecipeMacros macro;
  final int timeMinutes;
  final int prepMinutes;
  final int serves;

  // Dimension values (used by the dish-detail dimension switchers)
  final String dietClass; // 'classic' | 'vegan' | 'vegetarian' | 'keto' | 'halal' | ...
  final String effort; // 'easy' | 'medium' | 'hard'
  final int calorieLevel; // kcal per serving

  final List<String> techniques;
  final List<int> seasonMonths; // 1-12, empty = all seasons

  List<String> get ingredientIds =>
      ingredientRefs.map((e) => e.id).toList(growable: false);

  String nameOf(String lang) => name[lang] ?? name.values.first;

  factory Recipe.fromJson(Map<String, dynamic> j) {
    final contains = (j['contains'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final attrs = (j['attributes'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final dims = (j['dimensions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final cal = (j['kcal'] as num? ?? 0).toInt();
    return Recipe(
      id: j['id'] as String,
      dishId: j['dish'] as String,
      name: _localized(j['name'] as Map? ?? const {}),
      ingredientRefs: ((j['ingredients'] as List? ?? const []) as List)
          .map((e) => RecipeIngredientRef.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      steps: ((j['steps'] as List? ?? const []) as List)
          .map((e) => RecipeStep.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      contains: contains,
      attributes: attrs,
      tags: ((j['tags'] as List? ?? const []) as List).map((e) => e.toString()).toList(),
      macro: RecipeMacros.fromJson(j['macros']),
      timeMinutes: (j['time_minutes'] as num? ?? 0).toInt(),
      prepMinutes: (j['prep_minutes'] as num? ?? 0).toInt(),
      serves: (j['serves'] as num? ?? 2).toInt(),
      dietClass: dims['diet'] as String? ?? 'classic',
      effort: dims['effort'] as String? ?? 'medium',
      calorieLevel: cal,
      techniques: attrs
          .where((a) => const ['bake', 'sauté', 'simmer', 'raw', 'grill', 'fry', 'steam', 'roast', 'broil',
                'pan-fry', 'deep-fry', 'stir-fry', 'poach', 'blanch'].contains(a))
          .toList(),
      seasonMonths:
          ((j['season_months'] as List? ?? const []) as List).map((e) => (e as num).toInt()).toList(),
    );
  }

  static LocalizedText _localized(Map? m) {
    final out = <String, String>{};
    for (final e in (m ?? const {}).entries) {
      out[e.key.toString()] = e.value.toString();
    }
    return out;
  }
}

class Dish {
  const Dish({
    required this.id,
    required this.name,
    required this.heroEn,
    required this.heroDe,
    required this.captionEn,
    required this.captionDe,
    required this.stripeSeed,
    required this.recipeIds,
    required this.cuisine,
    required this.meals,
    required this.frequencyTier,
    required this.partitionId,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText hero;
  final LocalizedText caption;
  final int stripeSeed;
  final List<String> recipeIds;
  final String cuisine; // 'mediterranean' | 'asian' | 'middle-eastern' | ...
  final List<String> meals; // ['breakfast'] / ['lunch','dinner'] ...
  final String frequencyTier; // 'core' | 'extended'
  final String partitionId;

  String nameOf(String lang) => name[lang] ?? name.values.first;
  String heroOf(String lang) => hero[lang] ?? hero.values.first;
  String captionOf(String lang) => caption[lang] ?? caption.values.first;

  factory Dish.fromJson(Map<String, dynamic> j) {
    final cuisine = j['cuisine'] as String? ?? 'mediterranean';
    return Dish(
      id: j['id'] as String,
      name: _loc(j['name']),
      hero: _loc(j['hero']),
      caption: _loc(j['caption']),
      stripeSeed: (j['stripe_seed'] as num? ?? 0).toInt(),
      recipeIds:
          ((j['recipes'] as List? ?? const []) as List).map((e) => e.toString()).toList(),
      cuisine: cuisine,
      meals: ((j['meals'] as List? ?? const ['lunch', 'dinner']) as List)
          .map((e) => e.toString())
          .toList(),
      frequencyTier: j['frequency_tier'] as String? ?? 'core',
      partitionId: j['partition_id'] as String? ?? (cuisine == 'asian'
          ? 'cuisine-asian'
          : cuisine == 'middle-eastern'
              ? 'cuisine-middle-eastern'
              : 'cuisine-italian'),
    );
  }

  static LocalizedText _loc(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return m.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}

/// An ingredient node (hierarchical dictionary).
class IngredientNode {
  const IngredientNode({
    required this.id,
    required this.name,
    required this.children,
    this.unit = 'pc',
    this.aisle = 'other',
    this.descriptionEn = '',
    this.descriptionDe = '',
    this.usageTipEn = '',
    this.usageTipDe = '',
    this.storageEn = '',
    this.storageDe = '',
    this.shelfLife = '',
    this.whereToFindEn = '',
    this.whereToFindDe = '',
    this.flag = '',
  });

  final String id;
  final LocalizedText name;
  final List<IngredientNode> children;
  final String unit;
  final String aisle;
  final String descriptionEn;
  final String descriptionDe;
  final String usageTipEn;
  final String usageTipDe;
  final String storageEn;
  final String storageDe;
  final String shelfLife;
  final String whereToFindEn;
  final String whereToFindDe;

  /// Contains-flag set when this ingredient is used (e.g. dairy, tree-nuts).
  final String flag;

  String nameOf(String lang) => name[lang] ?? name.values.first;

  /// All descendant ingredient ids (including self).
  List<String> closureIds() {
    final out = <String>{id};
    for (final c in children) {
      out.addAll(c.closureIds());
    }
    return out.toList();
  }

  factory IngredientNode.fromJson(Map<String, dynamic> j) => IngredientNode(
        id: j['id'] as String,
        name: _loc(j['name']),
        children: ((j['children'] as List? ?? const []) as List)
            .map((e) => IngredientNode.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
        unit: j['unit'] as String? ?? 'pc',
        aisle: j['aisle'] as String? ?? 'other',
        descriptionEn: j['description_en'] as String? ?? '',
        descriptionDe: j['description_de'] as String? ?? '',
        usageTipEn: j['usage_tip_en'] as String? ?? '',
        usageTipDe: j['usage_tip_de'] as String? ?? '',
        storageEn: j['storage_en'] as String? ?? '',
        storageDe: j['storage_de'] as String? ?? '',
        shelfLife: j['shelf_life'] as String? ?? '',
        whereToFindEn: j['where_to_find_en'] as String? ?? '',
        whereToFindDe: j['where_to_find_de'] as String? ?? '',
        flag: j['flag'] as String? ?? '',
      );

  static LocalizedText _loc(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return m.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Iterable<IngredientNode> walk() sync* {
    yield this;
    for (final c in children) {
      yield* c.walk();
    }
  }
}

class FlagDef {
  const FlagDef({required this.id, required this.label, this.expands = const []});
  final String id;
  final LocalizedText label;
  final List<String> expands;
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.category,
    required this.q,
    required this.a,
    this.linkRoute,
  });
  final String id;
  final String category;
  final LocalizedText q;
  final LocalizedText a;
  final String? linkRoute;
}

class Ontology {
  const Ontology({
    required this.avoidFlags,
    required this.compoundFlags,
    required this.units,
    required this.efforts,
    required this.dietClasses,
  });

  /// User-facing avoid checkboxes (class level), e.g. dairy, pork, nuts.
  final List<FlagDef> avoidFlags;

  /// Compound shortcuts: vegan, vegetarian, halal, ...
  final List<FlagDef> compoundFlags;

  /// Unit registry: id -> {factor to base, base, label}
  final Map<String, Map<String, Object>> units;
  final List<String> efforts;
  final List<String> dietClasses;

  String unitBase(String unitId) =>
      (units[unitId]?['base'] as String?) ?? unitId;

  double unitFactor(String unitId) =>
      (units[unitId]?['factor'] as num? ?? 1).toDouble();

  String unitLabel(String unitId, String lang) {
    final l = (units[unitId]?['label'] as Map?)?.cast<String, dynamic>();
    if (l != null) return l[lang] ?? l.values.first;
    return unitId;
  }

  /// Ingredients that belong to a given avoid-flag family.
  static Set<String> flagLeafIds(String flag, List<IngredientNode> roots) {
    final out = <String>{};
    void visit(IngredientNode n) {
      if (n.flag == flag) out.addAll(n.closureIds());
      n.children.forEach(visit);
    }

    roots.forEach(visit);
    return out;
  }

  static Ontology fromJson(Map<String, dynamic> j) {
    FlagDef flagOf(Map<String, dynamic> m) => FlagDef(
          id: m['id'] as String,
          label: _loc(m['label']),
          expands: ((m['expands'] as List? ?? const []) as List).map((e) => e.toString()).toList(),
        );

    return Ontology(
      avoidFlags:
          ((j['avoid_flags'] as List? ?? const []) as List).map((e) => flagOf((e as Map).cast<String, dynamic>())).toList(),
      compoundFlags:
          ((j['compound_flags'] as List? ?? const []) as List).map((e) => flagOf((e as Map).cast<String, dynamic>())).toList(),
      units: (j['units'] as Map? ?? const {}).map(
            (k, v) => MapEntry(k.toString(), (v as Map).cast<String, Object>()),
          ),
      efforts: ((j['efforts'] as List? ?? const ['easy', 'medium', 'hard']) as List).map((e) => e.toString()).toList(),
      dietClasses:
          ((j['diet_classes'] as List? ?? const ['classic', 'vegan', 'vegetarian', 'keto', 'halal']) as List).map((e) => e.toString()).toList(),
    );
  }

  static LocalizedText _loc(Object? j) {
    final m = (j as Map?)?.cast<String, dynamic>() ?? const {};
    return m.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}

class FaqBook {
  const FaqBook(this.entries);
  final List<FaqEntry> entries;

  static FaqBook fromJson(Map<String, dynamic> j) {
    final list = (j['faqs'] as List? ?? const []) as List;
    return FaqBook(list
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          LocalizedText loc(Object? x) {
            final m2 = (x as Map?)?.cast<String, dynamic>() ?? const {};
            return m2.map((k, v) => MapEntry(k.toString(), v.toString()));
          }

          return FaqEntry(
            id: m['id'] as String,
            category: m['category'] as String? ?? 'general',
            q: loc(m['q']),
            a: loc(m['a']),
            linkRoute: m['link_route'] as String?,
          );
        })
        .toList());
  }
}
