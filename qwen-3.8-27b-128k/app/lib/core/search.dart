/// Free-text search over the bundled corpus + cursor-based pagination.
library;

import 'models.dart';

class SearchHit {
  final Recipe recipe;
  final int score;
  final String matchedOn; // label for the "matched on" chip
  const SearchHit(this.recipe, this.score, this.matchedOn);
}

class SearchPage {
  final List<SearchHit> items;
  final String? nextCursor;
  const SearchPage(this.items, this.nextCursor);
}

class Searcher {
  Searcher(this.dishes, this.recipes);
  final Map<String, Dish> dishes;
  final Map<String, Recipe> recipes;

  static const int pageSize = 20;

  List<String> _tokensOf(String text) {
    return text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9äöüßåå]+'))
        .where((t) => t.length >= 2)
        .toList();
  }

  /// Full scan (corpus is small & local), sorted, then cursor-paged.
  /// [cursor] == null → first page. Cursor encodes the recipe id boundary.
  SearchPage search(
    String query,
    List<Recipe> candidates, {
    String? cursor,
    List<String> tagFilter = const [],
  }) {
    final q = query.trim().toLowerCase();
    final qTokens = _tokensOf(q);

    final scored = <SearchHit>[];
    final seen = <String>{};

    List<SearchHit> scoreRecipe(Recipe r, String scope, int weight) {
      final out = <SearchHit>[];
      if (qTokens.isEmpty) {
        out.add(SearchHit(r, weight, scope));
      } else {
        var hits = 0;
        for (final t in qTokens) {
          if (r.name.s('en').toLowerCase().contains(t) ||
              r.name.s('de').toLowerCase().contains(t) ||
              r.summary.s('en').toLowerCase().contains(t) ||
              r.summary.s('de').toLowerCase().contains(t) ||
              r.tags.any((tag) => tag.toLowerCase().contains(t))) {
            hits++;
          } else {
            return const []; // all tokens must match somewhere
          }
        }
        out.add(SearchHit(r, weight * hits, scope));
      }
      return out;
    }

    for (final r in recipes.values) {
      if (!seen.add(r.id)) continue;
      if (tagFilter.isNotEmpty && !tagFilter.any(r.tags.contains)) continue;
      final dish = dishes[r.dishId];
      final dishText =
          dish != null ? '${dish.canonicalName.s('en')} ${dish.heroText.s('en')}' : '';
      final ingText =
          r.ingredients.map((i) => '${i.name.s('en')} ${i.name.s('de')}').join(' ');
      final stepText =
          r.steps.map((s) => '${s.text.s('en')} ${s.text.s('de')}').join(' ');

      final all = [
        ...scoreRecipe(r, 'name', 3),
        ..._scoreText(dishText, r, 2, qTokens, scope: 'dish'),
        ..._scoreText(ingText, r, 1, qTokens, scope: 'ingredient'),
        ..._scoreText(stepText, r, 1, qTokens, scope: 'method'),
      ];
      if (all.isNotEmpty) {
        scored.add(all.reduce((a, b) => a.score >= b.score ? a : b));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    var start = 0;
    if (cursor != null && cursor.isNotEmpty) {
      final idx = scored.indexWhere((h) => h.recipe.id == cursor);
      if (idx >= 0) start = idx + 1;
    }
    final end = start + pageSize;
    final page = scored.skip(start).take(pageSize).toList();
    final next = end < scored.length ? page.last.recipe.id : null;
    return SearchPage(page, next);
  }

  List<SearchHit> _scoreText(
    String text,
    Recipe r,
    int weight,
    List<String> qTokens, {
    required String scope,
  }) {
    if (qTokens.isEmpty) return [SearchHit(r, weight, scope)];
    final lower = text.toLowerCase();
    var hits = 0;
    for (final t in qTokens) {
      if (lower.contains(t)) {
        hits++;
      } else {
        return const [];
      }
    }
    return [SearchHit(r, weight * hits, scope)];
  }

  /// Distinct tags across the candidate set (for the tag chip filter).
  List<String> allTags(List<Recipe> candidates) {
    final out = <String>{};
    for (final r in candidates) {
      out.addAll(r.tags);
    }
    final list = out.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }
}
