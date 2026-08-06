import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../models/models.dart';

class Partition {
  final String id;
  final String file;
  final String strategy; // launch | lazy
  final List<String> recipeIds;
  final List<String> dishIds;
  final String? cuisineTag;

  Partition({
    required this.id,
    required this.file,
    required this.strategy,
    required this.recipeIds,
    required this.dishIds,
    this.cuisineTag,
  });

  factory Partition.fromJson(Map<String, dynamic> j) => Partition(
        id: j['id'] as String,
        file: j['file'] as String,
        strategy: j['strategy'] as String? ?? 'lazy',
        recipeIds: (j['recipe_ids'] as List? ?? const []).cast<String>(),
        dishIds: (j['dish_ids'] as List? ?? const []).cast<String>(),
        cuisineTag: j['cuisine_tag'] as String?,
      );
}

/// Loads and holds the bundled corpus. Core recipes load at launch; extended
/// and cuisine partitions load on demand (per partition-manifest.json).
class Corpus {
  final Map<String, Partition> partitionById = {};
  final List<String> preload = [];
  final Set<String> _loaded = {};
  final Set<String> _loading = {};
  final Set<String> _errors = {};

  final Map<String, Dish> dishesById = {};
  final Map<String, Recipe> recipesById = {};
  final Map<String, List<Recipe>> recipesInPartition = {};
  final Map<String, List<String>> _searchTokens = {};

  late Ontology ontology;
  final List<IngredientNode> ingredientRoots = [];
  final Map<String, IngredientNode> ingredientsById = {};
  final Map<String, GuideEntry> guides = {};
  final List<FaqEntry> faqs = [];
  final List<FaqCategory> faqCategories = [];
  final Set<String> allTags = {};

  bool ready = false;

  Future<void> load() async {
    final manifest = await _json('data/partition-manifest.json');
    for (final p in (manifest['partitions'] as List)) {
      final part = Partition.fromJson((p as Map).cast<String, dynamic>());
      partitionById[part.id] = part;
      if (part.strategy == 'launch') preload.add(part.id);
    }
    final loading = (manifest['loading'] as Map? ?? const {});
    if (loading['preload'] is List) {
      for (final id in (loading['preload'] as List).cast<String>()) {
        if (!preload.contains(id)) preload.add(id);
      }
    }

    final dishFile = await _json('data/dishes.json');
    for (final d in (dishFile['dishes'] as List)) {
      final dish = Dish.fromJson((d as Map).cast<String, dynamic>());
      dishesById[dish.id] = dish;
    }

    final ontologyFile = await _json('data/ontology.json');
    ontology = Ontology.fromJson(ontologyFile);

    final ingFile = await _json('data/ingredients.json');
    for (final root in (ingFile['categories'] as List)) {
      final node =
          IngredientNode.fromJson((root as Map).cast<String, dynamic>());
      ingredientRoots.add(node);
      _registerIngredient(node);
    }

    final guideFile = await _json('data/ingredient-guide.json');
    for (final e in guideFile.entries) {
      guides[e.key] =
          GuideEntry.fromJson((e.value as Map).cast<String, dynamic>());
    }

    final faqFile = await _json('data/faqs.json');
    faqCategories.addAll((faqFile['categories'] as List? ?? const [])
        .map((c) => FaqCategory.fromJson((c as Map).cast<String, dynamic>())));
    faqs.addAll((faqFile['entries'] as List? ?? const [])
        .map((f) => FaqEntry.fromJson((f as Map).cast<String, dynamic>())));

    for (final p in preload) {
      await loadPartition(p);
    }
    ready = true;
  }

  void _registerIngredient(IngredientNode n) {
    ingredientsById[n.id] = n;
    for (final c in n.children) {
      _registerIngredient(c);
    }
  }

  Future<Map<String, dynamic>> _json(String path) async {
    final raw = await rootBundle.loadString('assets/$path');
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  bool isPartitionLoaded(String id) => _loaded.contains(id);
  Set<String> get loadedPartitions => Set.unmodifiable(_loaded);
  Set<String> get loadErrors => Set.unmodifiable(_errors);

  Future<void> loadPartition(String id) async {
    if (_loaded.contains(id) || _loading.contains(id)) return;
    final part = partitionById[id];
    if (part == null) {
      _errors.add(id);
      return;
    }
    _loading.add(id);
    try {
      final json = await _json('data/${part.file}');
      final list = json['recipes'] as List? ?? const [];
      final recipes = <Recipe>[];
      for (final r in list) {
        final recipe = Recipe.fromJson((r as Map).cast<String, dynamic>());
        recipes.add(recipe);
        recipesById[recipe.id] = recipe;
        _indexSearch(recipe);
      }
      recipesInPartition[id] = recipes;
      _loaded.add(id);
    } catch (_) {
      _errors.add(id);
    } finally {
      _loading.remove(id);
    }
  }

  Future<void> ensureDishLoaded(Dish dish) async {
    await loadPartition(dish.partitionId);
    for (final s in dish.secondaryPartitions) {
      if (s.startsWith('cuisine-')) await loadPartition(s);
    }
  }

  Future<void> ensureAllLoaded() async {
    for (final id in partitionById.keys.toList()) {
      await loadPartition(id);
    }
  }

  Recipe? recipeById(String id) => recipesById[id];
  Dish? dishById(String id) => dishesById[id];

  /// Variants of a dish across all loaded partitions.
  List<Recipe> recipesForDish(String dishId) {
    final out = <Recipe>[];
    for (final list in recipesInPartition.values) {
      for (final r in list) {
        if (r.dishId == dishId && !out.any((o) => o.id == r.id)) out.add(r);
      }
    }
    return out;
  }

  List<Recipe> get allRecipes =>
      [for (final list in recipesInPartition.values) ...list];

  List<Dish> get dishesAll => dishesById.values.toList();

  IngredientNode? ingredientById(String id) => ingredientsById[id];

  /// Localized label for an ingredient id, falling back to en then the raw id.
  String labelOf(String id, String lang) {
    final n = ingredientsById[id];
    if (n == null) return id;
    return n.label[lang]?.toString() ?? n.label['en']?.toString() ?? id;
  }

  /// Top-level aisle ids, in corpus order (17 aisles).
  List<String> get aisleOrder => ingredientRoots.map((n) => n.id).toList();

  final Map<String, List<String>> _descendantsCache = {};

  /// All descendant ids (including self) of an ingredient node.
  List<String> descendantsOf(String id) => _descendantsCache.putIfAbsent(
      id, () => ingredientsById[id]?.descendants() ?? [id]);

  /// Typeahead over all ingredient nodes (parents + leaves, both languages).
  List<IngredientNode> searchIngredients(String query, String lang) {
    if (query.trim().isEmpty) return const [];
    final q = query.toLowerCase();
    final out = <IngredientNode>[];
    for (final n in ingredientsById.values) {
      final en = n.label['en']?.toString().toLowerCase() ?? '';
      final de = n.label['de']?.toString().toLowerCase() ?? '';
      if (en.contains(q) || de.contains(q)) out.add(n);
    }
    out.sort((a, b) {
      final al = (a.label[lang] ?? a.label['en'])?.toString().length ?? 0;
      final bl = (b.label[lang] ?? b.label['en'])?.toString().length ?? 0;
      return al.compareTo(bl);
    });
    return out.take(14).toList();
  }

  /// Ancestor ids of an ingredient (itself + parents up to root).
  List<String> ancestorsOf(String id) {
    final out = <String>[];
    String? cur = id;
    var guard = 0;
    while (cur != null && guard++ < 12) {
      out.add(cur);
      final n = ingredientsById[cur];
      cur = n?.parentId;
    }
    return out;
  }

  GuideEntry? guideFor(String ingredientId) => guides[ingredientId];

  // --- full-text search index ----------------------------------------------

  void _indexSearch(Recipe r) {
    final tokens = <String>{};
    void ingest(String? s) {
      if (s == null) return;
      for (final t in s.toLowerCase().split(RegExp(r'[^a-z0-9äöüß]+'))) {
        if (t.length > 1) tokens.add(t);
      }
    }

    ingest(r.title['en']);
    ingest(r.title['de']);
    ingest(r.summary['en']);
    ingest(r.summary['de']);
    for (final tag in r.tags) {
      ingest(tag);
    }
    for (final ing in r.ingredients) {
      final node = ingredientsById[ing.id];
      if (node != null) {
        ingest(node.label['en']);
        ingest(node.label['de']);
      }
      ingest(ing.id);
    }
    _searchTokens[r.id] = tokens.toList();
    for (final tag in r.tags) {
      allTags.add(tag);
    }
  }

  /// Search across loaded recipes. Returns matching recipe ids.
  List<Recipe> search(String query, String lang) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    final qTokens = q
        .split(RegExp(r'[^a-z0-9äöüß]+'))
        .where((t) => t.length > 1)
        .toList();
    if (qTokens.isEmpty) return const [];
    final out = <Recipe>[];
    for (final entry in _searchTokens.entries) {
      final recipe = recipesById[entry.key];
      if (recipe == null) continue;
      final tokens = entry.value;
      var hit = true;
      for (final t in qTokens) {
        var matched = false;
        for (final tok in tokens) {
          if (tok.startsWith(t)) {
            matched = true;
            break;
          }
        }
        if (!matched) {
          hit = false;
          break;
        }
      }
      if (hit) out.add(recipe);
    }
    return out;
  }

  /// Recipes matching a tag (fuzzy, prefix).
  List<Recipe> byTag(String tag) {
    final t = tag.toLowerCase();
    return allRecipes.where((r) {
      return r.tags.any((x) => x.toLowerCase() == t) ||
          r.ingredientIds.any((i) => i == t) ||
          r.diet == t ||
          r.attributes.contains(t);
    }).toList();
  }
}
