import '../models/ingredient.dart';
import '../models/recipe.dart';
import 'pagination.dart';

/// Inverted index over recipe title, tags and ingredient names per language.
/// Built per partition as partitions load (partition-based chunk loading).
class SearchIndex {
  final Map<String, Set<String>> _tokenToRecipeIds = {};
  final Map<String, Recipe> _recipes = {};
  final Set<String> _indexedPartitions = {};

  bool hasPartition(String partitionId) =>
      _indexedPartitions.contains(partitionId);

  static Iterable<String> tokenize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ')
      .split(RegExp(r'[\s-]+'))
      .where((t) => t.length > 1);

  void indexPartition(
    String partitionId,
    Iterable<Recipe> recipes,
    IngredientDictionary dictionary,
  ) {
    if (_indexedPartitions.contains(partitionId)) return;
    _indexedPartitions.add(partitionId);
    for (final recipe in recipes) {
      _recipes[recipe.id] = recipe;
      final tokens = <String>{};
      for (final title in recipe.title.values.values) {
        tokens.addAll(tokenize(title));
      }
      for (final tag in recipe.tags.all) {
        tokens.addAll(tokenize(tag));
      }
      for (final ing in recipe.ingredients) {
        final node = dictionary.byId(ing.ingredientId);
        if (node != null) {
          for (final name in node.name.values.values) {
            tokens.addAll(tokenize(name));
          }
        }
      }
      for (final token in tokens) {
        _tokenToRecipeIds.putIfAbsent(token, () => {}).add(recipe.id);
      }
    }
  }

  /// Free-text query: every query token must prefix-match some index token.
  /// Optional [tagFilters] are attribute ids that must all be present.
  List<Recipe> query(String text, {Set<String> tagFilters = const {}}) {
    final queryTokens = tokenize(text).toList();
    Set<String>? candidates;

    for (final qt in queryTokens) {
      final matches = <String>{};
      for (final entry in _tokenToRecipeIds.entries) {
        if (entry.key.startsWith(qt)) matches.addAll(entry.value);
      }
      candidates = candidates == null
          ? matches
          : candidates.intersection(matches);
      if (candidates.isEmpty) break;
    }

    var results = (candidates ?? _recipes.keys.toSet())
        .map((id) => _recipes[id]!)
        .where((r) => tagFilters.every((t) => r.attributes.contains(t)))
        .toList();

    results.sort((a, b) => a.title.of('en').compareTo(b.title.of('en')));
    return results;
  }
}

/// Keeps only recipes whose dish files under [categoryId] (null = keep all).
/// [categoryOf] resolves a recipe to its dish's category; recipes it cannot
/// resolve (no corpus dish) are dropped when a category is selected.
List<Recipe> filterByCategory(
  List<Recipe> results,
  String? categoryId,
  String? Function(Recipe) categoryOf,
) {
  if (categoryId == null) return results;
  return results.where((r) => categoryOf(r) == categoryId).toList();
}

final _coverageId = RegExp(r'-no-[a-z-]+$');

/// Collapses coverage variants out of ranked search results.
///
/// Coverage variants ("…-no-gluten") re-author a base cell free of specific
/// allergens and share its (dish, diet, effort, calorie) coordinates. To a
/// permissive profile both are visible, but listing them side by side reads
/// as duplicates — one row per dish-and-coordinate is what the dish page
/// shows too. The base recipe wins when visible; otherwise the first-ranked
/// visible variant stands in, keeping its position in the ranking.
List<Recipe> collapseCoverageVariants(Iterable<Recipe> ranked) {
  final slotByKey = <String, int>{};
  final out = <Recipe>[];
  for (final recipe in ranked) {
    final v = recipe.variant;
    final key = '${recipe.dishId}|${v.diet}|${v.effort}|${v.calorie}';
    final slot = slotByKey[key];
    if (slot == null) {
      slotByKey[key] = out.length;
      out.add(recipe);
    } else if (_coverageId.hasMatch(out[slot].id) &&
        !_coverageId.hasMatch(recipe.id)) {
      out[slot] = recipe;
    }
  }
  return out;
}

/// Cursor-based pager over a result list (cursor = stringified offset into
/// a stable snapshot, which keeps pagination stable while the user scrolls).
PageFetcher<Recipe> pagedResults(List<Recipe> results) {
  return (cursor, pageSize) async {
    final offset = cursor == null ? 0 : int.parse(cursor);
    final slice = results.skip(offset).take(pageSize).toList();
    final next = offset + slice.length;
    return Page(
      items: slice,
      nextCursor: next < results.length ? '$next' : null,
    );
  };
}
