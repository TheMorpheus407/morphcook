import '../core/localized.dart';
import '../models/recipe.dart';

/// Bundled search index built at load time from the corpus. Tokenizes title,
/// tags and ingredient names per language. Profile filters apply post-match
/// by the caller.
class SearchIndex {
  SearchIndex._(this._tokensByRecipe);

  /// recipeId -> set of lowercase tokens.
  final Map<String, Set<String>> _tokensByRecipe;

  factory SearchIndex.build(Iterable<Recipe> recipes) {
    final map = <String, Set<String>>{};
    for (final r in recipes) {
      final tokens = <String>{};
      for (final raw in r.searchTokens) {
        tokens.addAll(_tokenize(raw));
      }
      map[r.id] = tokens;
    }
    return SearchIndex._(map);
  }

  static Iterable<String> _tokenize(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((t) => t.isNotEmpty);

  /// Recipe ids whose tokens match all query terms (AND), optionally also
  /// requiring [tagFilters] (attribute ids). Scored: title hits weigh more.
  List<String> query(
    String text, {
    Set<String> tagFilters = const {},
    required Map<String, Recipe> byId,
    required AppLang lang,
  }) {
    final terms = _tokenize(text).toList();
    final scored = <String, int>{};
    for (final entry in _tokensByRecipe.entries) {
      final recipe = byId[entry.key];
      if (recipe == null) continue;
      if (!tagFilters.every(recipe.attributes.contains)) continue;

      if (terms.isEmpty) {
        scored[entry.key] = 0;
        continue;
      }
      var ok = true;
      var score = 0;
      final title = recipe.name.resolve(lang).toLowerCase();
      for (final term in terms) {
        final inToken = entry.value.any((t) => t.startsWith(term));
        if (!inToken) {
          ok = false;
          break;
        }
        if (title.contains(term)) score += 10;
        score += 1;
      }
      if (ok) scored[entry.key] = score;
    }
    final ids = scored.keys.toList()
      ..sort((a, b) {
        final cmp = scored[b]!.compareTo(scored[a]!);
        return cmp != 0 ? cmp : a.compareTo(b);
      });
    return ids;
  }
}
