import 'models.dart';

/// In-memory token index over the corpus (built once, per language set).
class SearchIndex {
  SearchIndex({
    required this.titleByRecipe,
    required this.ingredientsByRecipe,
  });

  final Map<String, String> titleByRecipe; // recipeId -> lowercase title
  final Map<String, List<String>> ingredientsByRecipe; // recipeId -> ingredient display names

  Iterable<String> tokens(String s) {
    final out = <String>[];
    for (final part in s.toLowerCase().split(RegExp(r'[^a-zäöüß0-9]+'))) {
      if (part.isNotEmpty) out.add(part);
    }
    return out;
  }

  /// Score a recipe for a set of query tokens (AND over tokens, substring OR over fields).
  int score(Recipe r, String lang, List<String> tokens) {
    if (tokens.isEmpty) return 0;
    final title = titleByRecipe[r.id] ?? '';
    var total = 0;
    for (final t in tokens) {
      var s = 0;
      if (title.contains(t)) s += 5;
      else {
        final ings = ingredientsByRecipe[r.id] ?? const [''];
        for (final ing in ings) {
          if (ing.contains(t)) {
            s += 2;
            break;
          }
        }
      }
      // dish-level tags are embedded in title string by caller
      if (s == 0) return 0;
      total += s;
    }
    return total;
  }
}

class SearchResult {
  const SearchResult({required this.recipe, required this.score});
  final Recipe recipe;
  final int score;
  int get cursor => score;
}

/// Cursor-based search with pagination (20/page, max 50 rendered, prefetch 10).
class SearchEngine {
  SearchEngine({
    required this.index,
    required this.allRecipes,
    this.pageSize = 20,
    this.maxResults = 50,
  });

  final SearchIndex index;
  final List<Recipe> allRecipes;
  final int pageSize;
  final int maxResults;

  List<SearchResult> searchAll(
    String query,
    String lang,
    Set<String> tags, {
    Profile? profileFilter,
  }) {
    final tokens = index.tokens(query).toList();
    final out = <SearchResult>[];
    for (final r in allRecipes) {
      if (tags.isNotEmpty) {
        final ok = tags.every((tag) => r.tags.contains(tag) || r.contains.contains(tag) || r.nameOf(lang).toLowerCase().contains(tag));
        if (!ok) continue;
      }
      final s = index.score(r, lang, tokens);
      if (s > 0) out.add(SearchResult(recipe: r, score: s));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.length > maxResults
        ? out.sublist(0, maxResults)
        : out.toList(growable: false);
  }

  /// [cursor] == -1 for first page, else the min score of the previous page.
  ({List<SearchResult> items, int nextCursor, bool hasMore}) page(
    String cursorToken,
    List<SearchResult> ranked,
  ) {
    int cursor = -1;
    if (cursorToken.isNotEmpty) {
      cursor = int.tryParse(cursorToken) ?? -1;
    }
    final items = cursor < 0
        ? ranked.take(pageSize).toList()
        : ranked
              .where((r) => r.score < cursor)
              .take(pageSize)
              .toList()
            .toList();
    // stable tie-break within equal scores: by id
    if (items.length > 1) {
      items.sort((a, b) {
        final d = b.score.compareTo(a.score);
        if (d != 0) return d;
        return a.recipe.id.compareTo(b.recipe.id);
      });
    }
    final more = cursor < 0 ? ranked.length > items.length : items.length == pageSize;
    final next = items.isEmpty ? '' : items.last.score.toString();
    return (items: items, nextCursor: next, hasMore: more && items.isNotEmpty);
  }
}
