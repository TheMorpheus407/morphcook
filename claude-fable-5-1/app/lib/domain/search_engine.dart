// Free-text + tag search over the bundled index, cursor-paginated, with
// partition chunks fetched on demand and profile filters applied
// post-match. Zero-result queries are reported so they can be logged as
// content requests.
import '../data/corpus_repository.dart';
import '../data/models/dish.dart';
import '../data/models/recipe.dart';
import '../data/models/search_index.dart';
import 'matching.dart';
import 'pagination.dart';
import 'search_tokenizer.dart';

class SearchQuery {
  const SearchQuery({this.text = '', this.tags = const {}});
  final String text;
  final Set<String> tags;
  bool get isEmpty => text.trim().isEmpty && tags.isEmpty;
}

class SearchHit {
  const SearchHit({required this.recipe, required this.dish, required this.score});
  final Recipe recipe;
  final Dish dish;
  final int score;
}

class SearchResultPage extends Page<SearchHit, String> {
  const SearchResultPage({required super.items, super.nextCursor, required this.totalCandidates});

  /// How many index entries matched before profile filtering.
  final int totalCandidates;
}

class SearchEngine {
  SearchEngine(this.repo);
  final CorpusRepository repo;

  /// Candidate entries with scores, best first. Pure and synchronous.
  List<(SearchEntry, int)> candidates(SearchQuery q, {required String lang}) {
    final tokens = tokenize(q.text);
    final out = <(SearchEntry, int)>[];
    for (final e in repo.searchIndex.entries) {
      if (q.tags.isNotEmpty && !_hasTags(e, q.tags)) continue;
      var score = 0;
      var matchedAll = true;
      final bag = e.tokens[lang] ?? const {};
      final bagEn = e.tokens['en'] ?? const {};
      for (final t in tokens) {
        final s = _tokenScore(t, bag) + (lang == 'en' ? 0 : _tokenScore(t, bagEn) ~/ 2);
        if (s == 0) {
          matchedAll = false;
          break;
        }
        score += s;
      }
      if (!matchedAll) continue;
      if (tokens.isEmpty) score = 1;
      out.add((e, score));
    }
    out.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : a.$1.title.of(lang).compareTo(b.$1.title.of(lang));
    });
    return out;
  }

  bool _hasTags(SearchEntry e, Set<String> tags) {
    final dish = repo.dish(e.dishId);
    final all = {...e.tags, ...?dish?.cuisineTags, ...?dish?.tags};
    final r = repo.recipeIfLoaded(e.recipeId);
    if (r != null) {
      all.addAll(r.attributes);
      all.addAll(r.mealTypes);
      all.add(r.diet);
    } else {
      all.addAll(e.tokens['en']?.keys ?? const []);
    }
    return tags.every(all.contains);
  }

  static int _tokenScore(String t, Map<String, int> bag) {
    final exact = bag[t];
    if (exact != null) return exact * 3;
    var best = 0;
    for (final e in bag.entries) {
      if (e.key.startsWith(t) && e.value > best) best = e.value;
    }
    return best;
  }

  /// One page of results. The cursor is the offset into the candidate
  /// list; profile filtering happens after fetching each recipe.
  Future<SearchResultPage> search(
    SearchQuery q, {
    required String lang,
    required MatchContext ctx,
    String? cursor,
    int pageSize = 20,
    bool ignoreCalories = false,
  }) async {
    if (q.isEmpty) return const SearchResultPage(items: [], totalCandidates: 0);
    final cands = candidates(q, lang: lang);
    var offset = int.tryParse(cursor ?? '') ?? 0;
    final items = <SearchHit>[];
    while (offset < cands.length && items.length < pageSize) {
      final (entry, score) = cands[offset];
      offset++;
      final recipe = await repo.recipe(entry.recipeId);
      final dish = repo.dish(entry.dishId);
      if (recipe == null || dish == null) continue;
      if (q.tags.isNotEmpty && !_hasTags(entry, q.tags)) continue;
      if (!isVisible(recipe, ctx, ignoreCalories: ignoreCalories)) continue;
      items.add(SearchHit(recipe: recipe, dish: dish, score: score));
    }
    return SearchResultPage(
      items: items,
      nextCursor: offset < cands.length ? '$offset' : null,
      totalCandidates: cands.length,
    );
  }
}
