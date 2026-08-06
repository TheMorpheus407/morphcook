import 'dart:convert';

import '../core/l10n.dart';
import '../data/corpus_repository.dart';
import '../data/profile.dart';
import 'matching.dart';

/// Cursor-based search over the bundled corpus.
///
/// The index tokenizes titles, tags and ingredient names per language.
/// Results respect profile filters post-match. Pagination is cursor-based
/// with 20 items per page; the cursor is an opaque offset token into a
/// stable per-query result snapshot.
class SearchService {
  static const pageSize = 20;

  final CorpusRepository corpus;
  final Map<String, Set<String>> _indexEn = {};
  final Map<String, Set<String>> _indexDe = {};
  bool _indexed = false;

  SearchService(this.corpus);

  static List<String> tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^\p{L}\p{N}\s]+", unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
  }

  void _add(Map<String, Set<String>> index, String token, String recipeId) {
    index.putIfAbsent(token, () => <String>{}).add(recipeId);
  }

  void _indexText(
      Map<String, Set<String>> index, String? text, String recipeId) {
    if (text == null) return;
    for (final token in tokenize(text)) {
      _add(index, token, recipeId);
    }
  }

  /// Build the inverted index over all currently loaded recipes. Called
  /// lazily on first search, and rebuilt when new partitions arrive.
  void buildIndex() {
    _indexEn.clear();
    _indexDe.clear();
    final dictionary = corpus.ingredients;
    for (final recipe in corpus.loadedRecipes) {
      final dish = corpus.dish(recipe.dishId);
      _indexText(_indexEn, tx(recipe.title, AppLang.en), recipe.id);
      _indexText(_indexDe, tx(recipe.title, AppLang.de), recipe.id);
      if (dish != null) {
        _indexText(_indexEn, tx(dish.name, AppLang.en), recipe.id);
        _indexText(_indexDe, tx(dish.name, AppLang.de), recipe.id);
      }
      for (final tag in recipe.tags) {
        _indexText(_indexEn, tag, recipe.id);
        _indexText(_indexDe, tag, recipe.id);
      }
      for (final attribute in recipe.attributes) {
        _indexText(_indexEn, attribute, recipe.id);
        _indexText(_indexDe, attribute, recipe.id);
      }
      _indexText(_indexEn, recipe.dietAxis, recipe.id);
      _indexText(_indexDe, recipe.dietAxis, recipe.id);
      for (final ingredientId in recipe.ingredientIds) {
        final node = dictionary[ingredientId];
        if (node == null) continue;
        _indexText(_indexEn, tx(node.name, AppLang.en), recipe.id);
        _indexText(_indexDe, tx(node.name, AppLang.de), recipe.id);
      }
    }
    _indexed = true;
  }

  Set<String> _matchToken(Map<String, Set<String>> index, String token) {
    final out = <String>{};
    index.forEach((key, ids) {
      // Prefix match on the index key; reverse containment only for keys
      // long enough to be meaningful (avoids "pan" matching "pancakes").
      if (key.startsWith(token) || (key.length >= 4 && token.startsWith(key))) {
        out.addAll(ids);
      }
    });
    return out;
  }

  /// Run a query. Returns recipe ids ordered by a simple relevance score
  /// (number of matched tokens, then title hits).
  List<String> _queryIds(String query) {
    if (!_indexed) buildIndex();
    final tokens = tokenize(query);
    if (tokens.isEmpty) return const [];

    final perTokenEn = [for (final t in tokens) _matchToken(_indexEn, t)];
    final perTokenDe = [for (final t in tokens) _matchToken(_indexDe, t)];

    final candidates = <String>{};
    for (final set in [...perTokenEn, ...perTokenDe]) {
      candidates.addAll(set);
    }
    if (candidates.isEmpty) return const [];

    // Every token must match in at least one language index.
    final results = <String, int>{};
    for (final id in candidates) {
      var ok = true;
      var score = 0;
      for (var i = 0; i < tokens.length; i++) {
        final inEn = perTokenEn[i].contains(id);
        final inDe = perTokenDe[i].contains(id);
        if (!inEn && !inDe) {
          ok = false;
          break;
        }
        score += 1;
        final recipe = corpus.recipe(id);
        if (recipe != null) {
          final titleEn = tx(recipe.title, AppLang.en).toLowerCase();
          final titleDe = tx(recipe.title, AppLang.de).toLowerCase();
          if (titleEn.contains(tokens[i]) || titleDe.contains(tokens[i])) {
            score += 3;
          }
        }
      }
      if (ok) results[id] = score;
    }
    final ids = results.keys.toList()
      ..sort((a, b) {
        final byScore = results[b]!.compareTo(results[a]!);
        if (byScore != 0) return byScore;
        return a.compareTo(b);
      });
    return ids;
  }

  /// One page of results. Profile filters apply post-match. A `null`
  /// [nextCursor] means the result set is exhausted.
  Future<SearchPage> search(
    String query, {
    String? cursor,
    required Profile profile,
    bool overrideCalorieTarget = false,
  }) async {
    // Search may reach outside the resident set; load everything on demand.
    if (corpus.manifest.partitions.length > 1) {
      await corpus.loadAllPartitions();
      buildIndex();
    }

    final ids = _queryIds(query);
    final visible = ids.where((id) {
      final recipe = corpus.recipe(id);
      if (recipe == null) return false;
      return isRecipeVisible(recipe, profile,
          ontology: corpus.ontology,
          dictionary: corpus.ingredients,
          overrideCalorieTarget: overrideCalorieTarget);
    }).toList();

    final offset = decodeCursor(cursor);
    final pageIds =
        visible.skip(offset).take(pageSize).toList();
    final hasMore = offset + pageIds.length < visible.length;
    return SearchPage(
      recipeIds: pageIds,
      nextCursor: hasMore ? encodeCursor(offset + pageIds.length) : null,
      total: visible.length,
      query: query,
    );
  }

  static String encodeCursor(int offset) =>
      base64Url.encode(utf8.encode('o:$offset'));

  static int decodeCursor(String? cursor) {
    if (cursor == null) return 0;
    try {
      final raw = utf8.decode(base64Url.decode(cursor));
      if (raw.startsWith('o:')) return int.parse(raw.substring(2));
    } catch (_) {}
    return 0;
  }
}

class SearchPage {
  final List<String> recipeIds;
  final String? nextCursor;
  final int total;
  final String query;

  const SearchPage({
    required this.recipeIds,
    required this.nextCursor,
    required this.total,
    required this.query,
  });

  bool get isEmpty => recipeIds.isEmpty;
}
