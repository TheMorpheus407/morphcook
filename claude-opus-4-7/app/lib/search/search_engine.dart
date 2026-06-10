import '../data/corpus.dart';
import '../matching/matcher.dart';
import '../models/profile.dart';
import '../models/recipe.dart';

/// In-memory token index over recipe title + tags + ingredient names (per lang).
class SearchEngine {
  final Corpus corpus;
  late final Map<String, Set<String>> _byToken; // token → recipe ids

  SearchEngine(this.corpus) {
    _byToken = {};
    for (final r in corpus.recipes) {
      _index(r);
    }
  }

  void _index(Recipe r) {
    final tokens = <String>{};
    for (final lang in const ['en', 'de']) {
      tokens.addAll(_tokenize(r.name.get(lang)));
      tokens.addAll(_tokenize(r.description.get(lang)));
      tokens.addAll(_tokenize(r.variantTag.get(lang)));
    }
    tokens.addAll(r.attributes);
    tokens.addAll(r.contains);
    tokens.addAll(r.cuisineTags);
    for (final ing in r.ingredients) {
      tokens.addAll(_tokenize(ing.name.get('en')));
      tokens.addAll(_tokenize(ing.name.get('de')));
      tokens.add(ing.id);
    }
    tokens.add(r.dishId);
    for (final t in tokens) {
      _byToken.putIfAbsent(t, () => <String>{}).add(r.id);
    }
  }

  Iterable<String> _tokenize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9äöüß ]"), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2);
  }

  /// Returns recipes ranked by token overlap, optionally filtered by [matcher].
  List<Recipe> search(
    String query, {
    Matcher? matcher,
    Profile? profile,
    int limit = 200,
    List<String>? mustTags,
  }) {
    final tokens = _tokenize(query).toList();
    if (tokens.isEmpty && (mustTags == null || mustTags.isEmpty)) {
      // Return everything matching profile when no query.
      final all = corpus.recipes;
      if (matcher != null && profile != null) {
        return matcher.filter(all, profile).toList();
      }
      return all;
    }

    final scores = <String, int>{};
    for (final t in tokens) {
      for (final entry in _byToken.entries) {
        if (entry.key.contains(t)) {
          for (final id in entry.value) {
            scores[id] = (scores[id] ?? 0) + (entry.key == t ? 5 : 1);
          }
        }
      }
    }
    if (mustTags != null) {
      for (final tag in mustTags) {
        final ids = _byToken[tag] ?? const {};
        scores.removeWhere((k, _) => !ids.contains(k));
      }
    }
    final ids = scores.keys.toList()
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final results = <Recipe>[];
    for (final id in ids.take(limit)) {
      final r = corpus.recipesById[id];
      if (r == null) continue;
      if (matcher != null && profile != null) {
        if (!matcher.evaluate(r, profile).visible) continue;
      }
      results.add(r);
    }
    return results;
  }
}
