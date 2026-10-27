import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/content.dart';
import '../models/localized_text.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching.dart';

class SearchIndexEntry {
  const SearchIndexEntry({
    required this.recipeId,
    required this.dishId,
    required this.partitionId,
    required this.tokensByLang,
    required this.tags,
  });
  final String recipeId;
  final String dishId;
  final String partitionId;
  final Map<String, List<String>> tokensByLang;
  final Set<String> tags;

  factory SearchIndexEntry.fromJson(Map json) => SearchIndexEntry(
    recipeId: (json['recipe_id'] ?? json['id']).toString(),
    dishId: json['dish_id'].toString(),
    partitionId: json['partition_id']?.toString() ?? 'core',
    tokensByLang: json['tokens_by_lang'] is Map
        ? (json['tokens_by_lang'] as Map).map(
            (lang, tokens) => MapEntry(lang.toString(), stringList(tokens)),
          )
        : const {},
    tags: stringList(json['tags']).toSet(),
  );
}

class SearchPage {
  const SearchPage({required this.recipes, required this.nextCursor});
  final List<Recipe> recipes;
  final String? nextCursor;
}

class DishChoice {
  const DishChoice({required this.dish, required this.recipe});
  final Dish dish;
  final Recipe recipe;
}

class RecipeRepository {
  RecipeRepository({AssetBundle? bundle}) : bundle = bundle ?? rootBundle;

  final AssetBundle bundle;
  final Map<String, Dish> dishes = {};
  final Map<String, Recipe> recipes = {};
  final Map<String, SearchIndexEntry> searchEntries = {};
  final Map<String, IngredientGuideEntry> ingredientGuide = {};
  final Map<String, Set<String>> cuisineRecipes = {};
  final List<FaqEntry> faqs = [];
  final Set<String> loadedPartitions = {};
  final Map<String, Future<void>> _loadingPartitions = {};
  late Ontology ontology;
  late IngredientDictionary ingredients;
  late RecipeMatcher matcher;
  Map<String, Object?> manifest = {};

  Future<void> load() async {
    final results = await Future.wait([
      _json('dishes.json'),
      _json('ontology.json'),
      _json('ingredients.json'),
      _json('ingredient-guide.json'),
      _json('faqs.json'),
      _json('partition-manifest.json'),
      _json('search-index.json'),
    ]);
    for (final item in (results[0]['dishes'] as List? ?? const [])) {
      final dish = Dish.fromJson(item as Map);
      dishes[dish.id] = dish;
    }
    ontology = Ontology.fromJson(results[1]);
    ingredients = IngredientDictionary.fromJson(results[2]);
    matcher = RecipeMatcher(ontology: ontology, ingredients: ingredients);
    for (final item in (results[3]['entries'] as List? ?? const [])) {
      final entry = IngredientGuideEntry.fromJson(item as Map);
      ingredientGuide[entry.ingredientId] = entry;
    }
    faqs.addAll(
      (results[4]['entries'] as List? ?? const []).map(
        (item) => FaqEntry.fromJson(item as Map),
      ),
    );
    manifest = results[5];
    for (final item
        in (results[6]['entries'] as List? ??
            results[6]['recipes'] as List? ??
            const [])) {
      final entry = SearchIndexEntry.fromJson(item as Map);
      searchEntries[entry.recipeId] = entry;
    }
    final launch = stringList(manifest['launch_partitions']);
    await Future.wait(
      (launch.isEmpty ? ['core'] : launch).map(ensurePartition),
    );
  }

  Future<Map<String, dynamic>> _json(String file) async {
    final source = await bundle.loadString('assets/$file');
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('assets/$file must contain a JSON object.');
    }
    return decoded;
  }

  Future<void> ensurePartition(String id) {
    if (loadedPartitions.contains(id)) return Future.value();
    final pending = _loadingPartitions.putIfAbsent(id, () async {
      final definitions = manifest['partitions'] as List? ?? const [];
      final definition = definitions.firstWhere(
        (item) => item['id'].toString() == id,
        orElse: () => throw StateError('Unknown recipe partition: $id'),
      );
      final data = await _json(definition['file'].toString());
      if (data['recipes'] is List) {
        for (final item in data['recipes'] as List) {
          final recipe = Recipe.fromJson(item as Map, partitionId: id);
          recipes[recipe.id] = recipe;
        }
      }
      if (data['recipe_ids'] is List) {
        final ids = stringList(data['recipe_ids']);
        cuisineRecipes[id] = ids.toSet();
        for (final recipeId in ids) {
          final partition = searchEntries[recipeId]?.partitionId;
          if (partition != null && partition != id) {
            await ensurePartition(partition);
          }
        }
      }
      loadedPartitions.add(id);
      _loadingPartitions.remove(id);
    });
    return pending.onError((error, stackTrace) {
      _loadingPartitions.remove(id);
      throw error!;
    });
  }

  Future<void> ensureRecipe(String id) async {
    if (recipes.containsKey(id)) return;
    final partition =
        searchEntries[id]?.partitionId ??
        dishes.values
            .firstWhere(
              (dish) => dish.variantIds.contains(id),
              orElse: () => throw StateError('Unknown recipe: $id'),
            )
            .partitionId;
    await ensurePartition(partition);
  }

  Future<List<Recipe>> recipesForDish(Dish dish) async {
    await ensurePartition(dish.partitionId);
    for (final id in dish.variantIds) {
      await ensureRecipe(id);
    }
    return dish.variantIds
        .map((id) => recipes[id])
        .whereType<Recipe>()
        .toList();
  }

  Future<List<Recipe>> recipesForCuisine(String partitionId) async {
    await ensurePartition(partitionId);
    final ids = cuisineRecipes[partitionId] ?? const <String>{};
    return ids.map((id) => recipes[id]).whereType<Recipe>().toList();
  }

  List<DishChoice> homeChoices(
    Profile profile, {
    required DateTime now,
    Map<String, DateTime> lastCooked = const {},
  }) {
    final choices = <DishChoice>[];
    for (final dish in dishes.values.where(
      (dish) => loadedPartitions.contains(dish.partitionId),
    )) {
      final recipe = matcher.bestVariant(
        dish,
        recipes,
        profile,
        now: now,
        lastCooked: lastCooked,
      );
      if (recipe != null) choices.add(DishChoice(dish: dish, recipe: recipe));
    }
    choices.sort((a, b) {
      final byScore = matcher
          .score(
            b.recipe,
            profile,
            now: now,
            lastCooked: lastCooked[b.recipe.id],
          )
          .compareTo(
            matcher.score(
              a.recipe,
              profile,
              now: now,
              lastCooked: lastCooked[a.recipe.id],
            ),
          );
      return byScore != 0 ? byScore : a.dish.id.compareTo(b.dish.id);
    });
    return choices;
  }

  Future<SearchPage> search(
    String query,
    Set<String> tags,
    Profile profile, {
    String? after,
    required DateTime now,
    Map<String, DateTime> lastCooked = const {},
    int limit = 20,
  }) async {
    final terms = _normalize(
      query,
    ).split(RegExp(r'\s+')).where((term) => term.isNotEmpty).toList();
    final matchingEntries = searchEntries.values.where((entry) {
      if (!tags.every(entry.tags.contains)) return false;
      if (terms.isEmpty) return true;
      final tokens = entry.tokensByLang.values
          .expand((tokens) => tokens)
          .map(_normalize);
      return terms.every(
        (term) => tokens.any((token) => token.startsWith(term)),
      );
    }).toList();
    await Future.wait(
      matchingEntries.map((entry) => ensurePartition(entry.partitionId)),
    );
    final candidates = matchingEntries
        .map((entry) => recipes[entry.recipeId])
        .whereType<Recipe>();
    final ranked = matcher.rank(
      candidates,
      profile,
      now: now,
      lastCooked: lastCooked,
    );
    var start = 0;
    if (after != null) {
      final index = ranked.indexWhere((recipe) => recipe.id == after);
      start = index < 0 ? 0 : index + 1;
    }
    if (start >= ranked.length) {
      return const SearchPage(recipes: [], nextCursor: null);
    }
    final end = (start + limit).clamp(0, ranked.length);
    final page = ranked.sublist(start, end);
    return SearchPage(
      recipes: page,
      nextCursor: end < ranked.length && page.isNotEmpty ? page.last.id : null,
    );
  }

  static String _normalize(String value) {
    const accents = {
      'ä': 'a',
      'ö': 'o',
      'ü': 'u',
      'ß': 'ss',
      'á': 'a',
      'à': 'a',
      'é': 'e',
      'è': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ë': 'e',
    };
    var result = value.toLowerCase().trim();
    for (final entry in accents.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }
}
