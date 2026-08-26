/// Loads the bundled corpus JSON assets into in-memory model maps.
/// Pure, async, no dependencies — unit-testable with raw JSON strings.
library;

import 'dart:convert';

import 'models.dart';

class Corpus {
  final Map<String, Recipe> recipes;
  final Map<String, Dish> dishes;
  final Map<String, FlagDef> containsFlags;
  final List<FlagDef> compoundFlags;
  final Map<String, IngredientMeta> ingredients;
  final Map<String, String> flagMap; // ingredient id -> top-level flag
  final List<String> treeGroups;
  final Map<String, List<String>> tree; // group -> members
  final List<FaqEntry> faqs;
  final Map<String, Map<String, String>> faqCategories;
  final Map<String, Map<String, String>> guide; // ingredient id -> lang -> text

  const Corpus({
    required this.recipes,
    required this.dishes,
    required this.containsFlags,
    required this.compoundFlags,
    required this.ingredients,
    required this.flagMap,
    required this.treeGroups,
    required this.tree,
    required this.faqs,
    required this.faqCategories,
    required this.guide,
  });

  Recipe? recipe(String id) => recipes[id];
  Dish? dish(String id) => dishes[id];
}

Corpus corpusFromJson(
  List<String> recipePartitions,
  String dishesJson,
  String ontologyJson,
  String ingredientsJson,
  String faqsJson,
  String guideJson,
) {
  final recMap = <String, Recipe>{};
  for (final part in recipePartitions) {
    final doc = jsonDecode(part) as Map<String, dynamic>;
    for (final r in (doc['recipes'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final rc = Recipe.fromMap(r);
      recMap[rc.id] = rc;
    }
  }

  final dishesDoc = jsonDecode(dishesJson) as Map<String, dynamic>;
  final dishMap = <String, Dish>{};
  for (final d in (dishesDoc['dishes'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final dish = Dish.fromMap(d);
    dishMap[dish.id] = dish;
  }

  // ontology
  final onDoc = jsonDecode(ontologyJson) as Map<String, dynamic>;
  final contains = <String, FlagDef>{};
  for (final f in (onDoc['contains_flags'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final def = FlagDef(
        id: f['id'] as String,
        label: i18nOf(f['label']),
        group: f['group'] as String? ?? 'other');
    contains[def.id] = def;
  }
  final compounds = <FlagDef>[];
  for (final f in (onDoc['compound_flags'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    compounds.add(FlagDef(
      id: f['id'] as String,
      label: i18nOf(f['label']),
      group: 'compound',
      expandsTo: (f['expands_to'] as List? ?? const []).cast<String>(),
    ));
  }

  // ingredients
  final ingDoc = jsonDecode(ingredientsJson) as Map<String, dynamic>;
  final tree = <String, List<String>>{};
  for (final e in (ingDoc['tree'] as Map? ?? const <String, dynamic>{}).entries) {
    tree[e.key as String] = (e.value as List).cast<String>();
  }
  final flagMap = (ingDoc['flag_map'] as Map? ?? const {}).map((k, v) => MapEntry(k.toString(), v.toString()));
  final ingredients = <String, IngredientMeta>{};
  for (final i in (ingDoc['ingredients'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final meta = IngredientMeta.fromMap(i);
    ingredients[meta.id] = meta;
  }

  // faqs
  final faqDoc = jsonDecode(faqsJson) as Map<String, dynamic>;
  final faqs = (faqDoc['faq'] as List? ?? const []).cast<Map<String, dynamic>>().map(FaqEntry.fromMap).toList();
  final faqCats = <String, Map<String, String>>{};
  for (final c in (faqDoc['categories'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    faqCats[c['id'] as String] = i18nOf(c['label']).map;
  }

  // ingredient guide
  final guideDoc = jsonDecode(guideJson) as Map<String, dynamic>;
  final guide = <String, Map<String, String>>{};
  for (final e in (guideDoc['guide'] as Map? ?? const <String, dynamic>{}).entries) {
    final v = e.value;
    if (v is Map) {
      guide[e.key as String] = v.map((k, vv) => MapEntry(k.toString(), vv.toString()));
    }
  }

  return Corpus(
    recipes: recMap,
    dishes: dishMap,
    containsFlags: contains,
    compoundFlags: compounds,
    ingredients: ingredients,
    flagMap: flagMap,
    treeGroups: tree.keys.toList(),
    tree: tree,
    faqs: faqs,
    faqCategories: faqCats,
    guide: guide,
  );
}
