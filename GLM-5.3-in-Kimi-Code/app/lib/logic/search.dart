/// Bundled search index + cursor-based pagination (20/page, prefetch @10).
///
/// Tokenizes dish titles, recipe titles/subtitles, tags and ingredient
/// names per language. Profile filters apply post-match. Zero-result
/// queries are surfaced to the app state for the content-requests log.
library;

import '../data/corpus.dart';
import '../data/models.dart';
import '../l10n.dart';
import 'matching.dart';
import 'profile.dart';

class SearchHit {
  final Dish dish;
  final Recipe recipe; // the profile-matched variant
  final double score;
  const SearchHit(this.dish, this.recipe, this.score);
}

class SearchFilters {
  final String? cuisine;
  final String? diet;
  final String? effort;
  const SearchFilters({this.cuisine, this.diet, this.effort});

  bool get isEmpty => cuisine == null && diet == null && effort == null;

  static const empty = SearchFilters();
}

/// Build-time-equivalent token index (built once at app start from the
/// bundled corpus — no network, no runtime generation cost beyond startup).
class SearchIndex {
  final Corpus corpus;
  final Map<String, Map<String, Set<String>>> _tokens = {}; // lang -> token -> dish ids

  SearchIndex(this.corpus) {
    for (final lang in Lang.values) {
      final map = <String, Set<String>>{};
      for (final dish in corpus.dishes.values) {
        final tokens = <String>{};
        void add(String? text) {
          if (text == null) return;
          _tokenize(text).forEach(tokens.add);
        }

        add(dish.canonicalName.get(lang));
        add(dish.hero.get(lang));
        for (final t in dish.cuisineTags) {
          add(t);
        }
        for (final rid in dish.variants) {
          final r = corpus.recipes[rid];
          if (r == null) continue;
          add(r.title.get(lang));
          add(r.subtitle.get(lang));
          for (final i in r.ingredients) {
            add(corpus.ingredients.nodes[i.id]?.name.get(lang));
            add(i.note?.get(lang));
          }
        }
        for (final t in tokens) {
          map.putIfAbsent(t, () => {}).add(dish.id);
        }
      }
      _tokens[lang.name] = map;
    }
  }

  static Iterable<String> _tokenize(String text) sync* {
    final lowered = text.toLowerCase();
    final raw = lowered.split(RegExp(r'[^a-zäöüß0-9]+'));
    for (final t in raw) {
      if (t.length >= 2) yield t;
    }
  }

  /// Full query execution: match → filters → profile → rank → paginate.
  SearchResult query(
    String query,
    Profile p,
    Ontology onto, {
    Lang lang = Lang.en,
    SearchFilters filters = SearchFilters.empty,
    String? cursor,
    int pageSize = 20,
    Avoidance? avoidance,
  }) {
    final tokens = _tokenize(query).toList();
    final langMap = _tokens[lang.name] ?? const <String, Set<String>>{};

    final dishScores = <String, double>{};
    if (tokens.isEmpty) {
      // empty query → all dishes, neutral score
      for (final id in corpus.dishes.keys) {
        dishScores[id] = 0;
      }
    } else {
      for (final token in tokens) {
        // prefix match over token map
        langMap.forEach((t, ids) {
          if (t.startsWith(token)) {
            final weight = t == token ? 1.0 : 0.6;
            for (final id in ids) {
              dishScores[id] = (dishScores[id] ?? 0) + weight;
            }
          }
        });
      }
    }

    // filters
    Iterable<Dish> dishes = dishScores.keys.map((id) => corpus.dishes[id]!);
    if (filters.cuisine != null) {
      dishes = dishes.where((d) =>
          d.cuisineTags.contains(filters.cuisine) ||
          d.secondaryPartitions.contains(filters.cuisine));
    }
    if (filters.diet != null) {
      dishes = dishes.map((d) => d).where((d) {
        return d.variants.any((rid) => corpus.recipes[rid]?.diet == filters.diet);
      });
    }

    final hits = <SearchHit>[];
    for (final d in dishes) {
      // pick the profile-visible (else diet-compatible) representative
      Recipe? best;
      for (final rid in d.variants) {
        final r = corpus.recipes[rid];
        if (r == null) continue;
        if (filters.effort != null && r.effort != filters.effort) continue;
        if (filters.diet != null && r.diet != filters.diet) continue;
        final res = matchesRecipe(r, p, onto, avoidance: avoidance);
        if (res.visible) {
          best = r;
          break;
        }
      }
      // when nothing is fully visible, still offer a diet-compatible rep
      best ??= d.variants
          .map((rid) => corpus.recipes[rid])
          .whereType<Recipe>()
          .where((r) =>
              (filters.diet == null || r.diet == filters.diet) &&
              (filters.effort == null || r.effort == filters.effort))
          .where((r) => isDietCompatible(r, p, onto, avoidance: avoidance))
          .firstOrNull;
      if (best == null) continue;
      hits.add(SearchHit(d, best, dishScores[d.id] ?? 0));
    }

    hits.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.dish.id.compareTo(b.dish.id);
    });

    // cursor pagination
    int start = 0;
    if (cursor != null) {
      start = int.tryParse(cursor) ?? 0;
    }
    final page = hits.skip(start).take(pageSize).toList();
    final nextStart = start + page.length;
    final nextCursor =
        nextStart < hits.length ? nextStart.toString() : null;

    return SearchResult(
      hits: page,
      nextCursor: nextCursor,
      total: hits.length,
      query: query,
    );
  }
}

class SearchResult {
  final List<SearchHit> hits;
  final String? nextCursor;
  final int total;
  final String query;
  const SearchResult({
    required this.hits,
    required this.nextCursor,
    required this.total,
    required this.query,
  });

  bool get hasMore => nextCursor != null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
