import 'dart:math' as math;

import '../models/recipe.dart';

/// A search hit with its score.
class SearchHit {
  const SearchHit(this.recipe, this.score);

  final Recipe recipe;
  final double score;
}

/// A build-time-style search index over the bundled corpus.
///
/// The index tokenises the title, tags and ingredient names in both shipped
/// languages, so a German query finds a recipe whose German title matches and
/// vice versa. Everything stays in memory — the corpus is small and the app
/// is offline-only.
class SearchIndex {
  SearchIndex(this._tokens);

  /// recipe id → set of lowercase tokens.
  final Map<String, Set<String>> _tokens;

  /// Builds the index from the recipes that are currently loaded.
  factory SearchIndex.fromRecipes(Iterable<Recipe> recipes) {
    final tokens = <String, Set<String>>{};
    for (final recipe in recipes) {
      tokens[recipe.id] = _tokenizeRecipe(recipe);
    }
    return SearchIndex(tokens);
  }

  static Set<String> _tokenizeRecipe(Recipe recipe) {
    final tokens = <String>{};
    final haystack = <String>[
      recipe.title.resolve('en'),
      recipe.title.resolve('de'),
      recipe.dishId.replaceAll('-', ' '),
      recipe.tags.resolve('en'),
      recipe.tags.resolve('de'),
      recipe.heroText.resolve('en'),
      recipe.heroText.resolve('de'),
      recipe.diet,
      for (final ingredient in recipe.ingredients) ...<String>[
        ingredient.name.resolve('en'),
        ingredient.name.resolve('de'),
        ingredient.ingredientId.replaceAll('.', ' '),
      ],
    ].join(' ');

    for (final token in _tokenize(haystack)) {
      tokens.add(token);
    }
    return tokens;
  }

  /// Lowercases and splits into word tokens, keeping tokens of two characters
  /// or more plus full digits.
  static Iterable<String> _tokenize(String input) sync* {
    final normalized = input.toLowerCase();
    final buffer = StringBuffer();
    for (var i = 0; i < normalized.length; i++) {
      final code = normalized.codeUnitAt(i);
      final isSeparator = code == 32 ||
          code == 9 ||
          code == 10 ||
          code == 45 ||
          code == 46 ||
          code == 44 ||
          code == 47 ||
          code == 58 ||
          code == 40 ||
          code == 41;
      if (isSeparator) {
        if (buffer.isNotEmpty) {
          yield buffer.toString();
          buffer.clear();
        }
      } else {
        buffer.writeCharCode(code);
      }
    }
    if (buffer.isNotEmpty) yield buffer.toString();
  }

  /// Tokenises a raw query the same way the index was built.
  static List<String> queryTokens(String query) {
    return _tokenize(query)
        .where((token) => token.length >= 2 || int.tryParse(token) != null)
        .toList(growable: false);
  }

  /// Scores a recipe against the query tokens.
  ///
  /// Exact token hits score highest; prefix hits score partially so that
  /// "toma" still finds "tomato".
  double score(String recipeId, List<String> tokens) {
    final index = _tokens[recipeId];
    if (index == null || tokens.isEmpty) return 0;
    var total = 0.0;
    for (final token in tokens) {
      if (index.contains(token)) {
        total += 1;
        continue;
      }
      var prefixHit = false;
      for (final candidate in index) {
        if (candidate.startsWith(token) || token.startsWith(candidate)) {
          prefixHit = true;
          break;
        }
      }
      if (prefixHit) total += 0.4;
    }
    return total / tokens.length;
  }

  /// Recipes whose tokens match, best first.
  ///
  /// [universe] restricts the search to a subset of the corpus — the
  /// search screen passes the recipes that already pass the user's profile
  /// filters.
  List<SearchHit> search(String query, {List<Recipe>? universe}) {
    final tokens = queryTokens(query);
    if (tokens.isEmpty) return const <SearchHit>[];
    final hits = <SearchHit>[];
    for (final recipe in universe ?? const <Recipe>[]) {
      final value = score(recipe.id, tokens);
      if (value > 0) hits.add(SearchHit(recipe, value));
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.recipe.title
          .resolve('en')
          .compareTo(b.recipe.title.resolve('en'));
    });
    return hits;
  }

  /// Simple fuzzy score used for suggestions when a query returns nothing.
  int similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final distance = _levenshtein(a.toLowerCase(), b.toLowerCase());
    final longest = math.max(a.length, b.length);
    if (longest == 0) return 0;
    return ((longest - distance) / longest * 100).round();
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = math.min(
          math.min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + cost,
        );
      }
      final swap = previous;
      previous = current;
      current = swap;
    }
    return previous[b.length];
  }
}
