/// Pure data models parsed from the bundled corpus assets.
/// All user-visible text is a `Map<String,String>` keyed by language code,
/// so adding a language is purely a data addition.
library;

class I18n {
  final Map<String, String> map;
  const I18n(this.map);

  String s(String lang) => map[lang] ?? map['en'] ?? '';

  static I18n of(dynamic v) {
    if (v is Map) {
      return I18n(v.map((k, e) => MapEntry(k.toString(), e.toString())));
    }
    if (v is String) return const I18n({});
    return const I18n({});
  }
}

I18n i18nOf(dynamic v) => v is Map<String, dynamic> ? I18n.of(v) : const I18n({});

class IngredientRef {
  final String id;
  final String qty; // numeric string like "2", "0.5", "to taste"
  final String unit; // g, ml, tbsp, tsp, clove, piece, pinch, sheet, leaf, cup, l, kg
  final I18n name;

  const IngredientRef({required this.id, required this.qty, required this.unit, required this.name});

  double get qtyNum => double.tryParse(qty) ?? 0.0;

  factory IngredientRef.fromMap(Map<String, dynamic> m) => IngredientRef(
        id: m['id'] as String,
        qty: (m['qty'] ?? '1').toString(),
        unit: (m['unit'] ?? 'unit').toString(),
        name: i18nOf(m['name']),
      );
}

class Step {
  final int n;
  final I18n text;
  final int seconds; // 0 = no timer
  const Step({required this.n, required this.text, required this.seconds});

  factory Step.fromMap(Map<String, dynamic> m) =>
      Step(n: (m['n'] as num?)?.toInt() ?? 0, text: i18nOf(m['text']), seconds: (m['seconds'] as num?)?.toInt() ?? 0);
}

class Recipe {
  final String id;
  final String dishId;
  final I18n name;
  final I18n summary;
  final String effort; // easy|medium|hard
  final int timeMinutes;
  final String timeBucket;
  final int caloriesPerServing;
  final String calorieBucket;
  final int servings;
  final List<String> contains;
  final List<String> ingredientIds;
  final List<IngredientRef> ingredients;
  final List<String> tags;
  final List<int> seasonalMonths;
  final String partition;
  final String cuisine;
  final List<String> techniques;
  final List<String> meals;
  final List<Step> steps;

  const Recipe({
    required this.id,
    required this.dishId,
    required this.name,
    required this.summary,
    required this.effort,
    required this.timeMinutes,
    required this.timeBucket,
    required this.caloriesPerServing,
    required this.calorieBucket,
    required this.servings,
    required this.contains,
    required this.ingredientIds,
    required this.ingredients,
    required this.tags,
    required this.seasonalMonths,
    required this.partition,
    required this.cuisine,
    required this.techniques,
    required this.meals,
    required this.steps,
  });

  factory Recipe.fromMap(Map<String, dynamic> m) => Recipe(
        id: m['id'] as String,
        dishId: m['dish_id'] as String,
        name: i18nOf(m['name']),
        summary: i18nOf(m['summary']),
        effort: m['effort'] as String? ?? 'medium',
        timeMinutes: (m['time_minutes'] as num?)?.toInt() ?? 30,
        timeBucket: m['time_bucket'] as String? ?? '≤60',
        caloriesPerServing: (m['calories_per_serving'] as num?)?.toInt() ?? 0,
        calorieBucket: m['calorie_bucket'] as String? ?? '≤800',
        servings: (m['servings'] as num?)?.toInt() ?? 2,
        contains: (m['contains'] as List? ?? const []).cast<String>(),
        ingredientIds: (m['ingredient_ids'] as List? ?? const []).cast<String>(),
        ingredients: (m['ingredients'] as List? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(IngredientRef.fromMap)
            .toList(),
        tags: (m['tags'] as List? ?? const []).cast<String>(),
        seasonalMonths:
            (m['seasonal_months'] as List? ?? const []).map((e) => (e as num).toInt()).toList(),
        partition: m['partition'] as String? ?? 'core',
        cuisine: m['cuisine'] as String? ?? 'other',
        techniques: (m['technique'] as List? ?? const []).cast<String>(),
        meals: (m['meal'] as List? ?? const []).cast<String>(),
        steps: (m['steps'] as List? ?? const []).cast<Map<String, dynamic>>().map(Step.fromMap).toList(),
      );
}

class Dish {
  final String id;
  final I18n canonicalName;
  final I18n heroText;
  final I18n capCaption;
  final String stripeColorHex;
  final List<String> variantRecipeIds;
  final String partitionId;
  final List<String> secondaryPartitions;
  final List<String> cuisineTags;
  final String frequencyTier;

  const Dish({
    required this.id,
    required this.canonicalName,
    required this.heroText,
    required this.capCaption,
    required this.stripeColorHex,
    required this.variantRecipeIds,
    required this.partitionId,
    required this.secondaryPartitions,
    required this.cuisineTags,
    required this.frequencyTier,
  });

  factory Dish.fromMap(Map<String, dynamic> m) => Dish(
        id: m['id'] as String,
        canonicalName: i18nOf(m['canonical_name']),
        heroText: i18nOf(m['hero_text']),
        capCaption: i18nOf(m['cap_caption']),
        stripeColorHex: (m['stripe_color'] ?? '#7E9B7A').toString(),
        variantRecipeIds: (m['variant_recipe_ids'] as List? ?? const []).cast<String>(),
        partitionId: m['partition_id'] as String? ?? 'core',
        secondaryPartitions: (m['secondary_partitions'] as List? ?? const []).cast<String>(),
        cuisineTags: (m['cuisine_tags'] as List? ?? const []).cast<String>(),
        frequencyTier: m['frequency_tier'] as String? ?? 'core',
      );
}

class IngredientMeta {
  final String id;
  final I18n name;
  final String category;
  final String aisle;
  final String unit;
  final I18n note;
  final List<int> seasonalMonths;

  const IngredientMeta({
    required this.id,
    required this.name,
    required this.category,
    required this.aisle,
    required this.unit,
    required this.note,
    required this.seasonalMonths,
  });

  factory IngredientMeta.fromMap(Map<String, dynamic> m) => IngredientMeta(
        id: m['id'] as String,
        name: i18nOf(m['name']),
        category: m['category'] as String? ?? 'pantry',
        aisle: m['aisle'] as String? ?? 'pantry',
        unit: m['unit'] as String? ?? 'unit',
        note: i18nOf(m['note']),
        seasonalMonths: (m['seasonal_months'] as List? ?? const []).map((e) => (e as num).toInt()).toList(),
      );
}

class FaqEntry {
  final String category;
  final I18n q;
  final I18n a;
  const FaqEntry({required this.category, required this.q, required this.a});

  factory FaqEntry.fromMap(Map<String, dynamic> m) => FaqEntry(
        category: m['category'] as String? ?? 'features',
        q: i18nOf(m['q']),
        a: i18nOf(m['a']),
      );
}

class FlagDef {
  final String id;
  final I18n label;
  final String group;
  final List<String> expandsTo;
  const FlagDef({
    required this.id,
    required this.label,
    required this.group,
    this.expandsTo = const [],
  });
}
