import '../corpus_repository.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching.dart';

/// Bundled-index free-text search with tag filters; profile filters apply
/// post-match. Cursor-based pagination, 20 items per page.
class SearchEngine {
  final CorpusRepository corpus;
  final MatchingEngine matching;

  SearchEngine(this.corpus, this.matching);

  static List<String> tokenize(String input) => input
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.isNotEmpty)
      .toList();

  /// Returns recipe ids matching [query] tokens + [tags], ordered by
  /// relevance (token hits), filtered by the profile.
  List<Recipe> search(
    String query,
    UserProfile profile, {
    Set<String> tags = const {},
  }) {
    final queryTokens = tokenize(query);
    final scored = <Recipe, int>{};

    for (final entry in corpus.searchIndex.entries) {
      final recipe = corpus.recipeById(entry.key);
      if (recipe == null) continue;
      if (tags.isNotEmpty && !recipe.tags.toSet().containsAll(tags)) continue;

      var hits = 0;
      if (queryTokens.isEmpty) {
        hits = 1; // tag-only browse
      } else {
        final indexTokens = entry.value;
        for (final qt in queryTokens) {
          if (indexTokens.any((t) => t.startsWith(qt))) hits++;
        }
      }
      if (hits > 0) scored[recipe] = hits;
    }

    final results = scored.keys.toList()
      ..sort((a, b) {
        final c = scored[b]!.compareTo(scored[a]!);
        if (c != 0) return c;
        return matching.score(b, profile).compareTo(matching.score(a, profile));
      });

    // Profile filters apply post-match.
    return results.where((r) => matching.visible(r, profile)).toList();
  }

  /// One cursor-based page of [recipes]. Cursor = string offset; page size 20.
  List<Recipe> page(List<Recipe> recipes, String? cursor, {int pageSize = 20}) {
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
    if (start >= recipes.length) return const [];
    return recipes.sublist(
      start,
      (start + pageSize).clamp(0, recipes.length),
    );
  }
}
