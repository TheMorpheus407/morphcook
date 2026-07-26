import '../data/corpus_repository.dart';
import '../domain/matching.dart';
import '../domain/models.dart';

class SearchHit {
  const SearchHit({
    required this.recipe,
    required this.score,
    required this.visible,
  });

  final Recipe recipe;
  final double score;

  /// Hidden hits are counted, never silently dropped — the results screen says
  /// how many the profile filtered away and offers to show them anyway.
  final bool visible;
}

class SearchOutcome {
  const SearchOutcome({
    required this.hits,
    required this.hiddenCount,
    required this.query,
  });

  static const SearchOutcome empty = SearchOutcome(
    hits: [],
    hiddenCount: 0,
    query: '',
  );

  final List<SearchHit> hits;
  final int hiddenCount;
  final String query;

  bool get isEmpty => hits.isEmpty;
}

/// Free-text search over the build-time index, plus tag filters.
///
/// The index maps token → recipe ids per language. Partitions are pulled in on
/// demand: an id in the index may belong to a partition that has not been read
/// off the bundle yet.
class SearchService {
  SearchService({required this.repository, required this.matcher});

  final CorpusRepository repository;
  final RecipeMatcher matcher;

  static final RegExp _splitter = RegExp(r'[^\wÀ-ɏ]+');

  static List<String> tokenize(String text) => text
      .toLowerCase()
      .split(_splitter)
      .where((t) => t.length > 1)
      .toList(growable: false);

  Future<SearchOutcome> search(
    String query, {
    required String lang,
    required MatchContext context,
    Set<String> tagFilters = const {},
    Set<String> dietFilters = const {},
    Set<String> effortFilters = const {},
    bool includeHidden = false,
  }) async {
    final tokens = tokenize(query);
    final index = await repository.searchTokens(lang);

    Set<String>? candidateIds;
    if (tokens.isNotEmpty) {
      for (final token in tokens) {
        final exact = index[token];
        final matches = <String>{...?exact};
        if (exact == null) {
          // Prefix match, so "spag" finds "spaghetti".
          for (final entry in index.entries) {
            if (entry.key.startsWith(token)) matches.addAll(entry.value);
          }
        }
        candidateIds = candidateIds == null
            ? matches
            : candidateIds.intersection(matches);
        if (candidateIds.isEmpty) break;
      }
    }

    // A tag/diet/effort-only search browses the whole corpus.
    if (candidateIds == null) {
      await repository.loadAllPartitions();
      candidateIds = repository.loadedRecipes.map((r) => r.id).toSet();
    } else {
      await _ensureLoaded(candidateIds);
    }

    final hits = <SearchHit>[];
    var hidden = 0;
    for (final id in candidateIds) {
      final recipe = repository.recipe(id);
      if (recipe == null) continue;
      if (tagFilters.isNotEmpty && !tagFilters.every(recipe.tags.contains)) {
        continue;
      }
      if (dietFilters.isNotEmpty &&
          !dietFilters.contains(recipe.axes['diet'])) {
        continue;
      }
      if (effortFilters.isNotEmpty && !effortFilters.contains(recipe.effort)) {
        continue;
      }
      final visible = matcher.isVisible(recipe, context);
      if (!visible) {
        hidden++;
        if (!includeHidden) continue;
      }
      hits.add(
        SearchHit(
          recipe: recipe,
          score: _relevance(recipe, tokens, lang),
          visible: visible,
        ),
      );
    }

    hits.sort((a, b) {
      if (a.visible != b.visible) return a.visible ? -1 : 1;
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.recipe.id.compareTo(b.recipe.id);
    });

    return SearchOutcome(hits: hits, hiddenCount: hidden, query: query);
  }

  Future<void> _ensureLoaded(Set<String> ids) async {
    final missing = ids.where((id) => repository.recipe(id) == null);
    if (missing.isEmpty) return;
    // The index does not record partitions, so a miss means loading the rest.
    await repository.loadAllPartitions();
  }

  double _relevance(Recipe recipe, List<String> tokens, String lang) {
    if (tokens.isEmpty) return recipe.isDishDefault ? 1 : 0;
    final title = recipe.title(lang).toLowerCase();
    final dishName =
        repository.dish(recipe.dishId)?.name(lang).toLowerCase() ?? '';
    var score = 0.0;
    for (final token in tokens) {
      if (title.startsWith(token)) {
        score += 6;
      } else if (title.contains(token)) {
        score += 4;
      }
      if (dishName.contains(token)) score += 3;
      if (recipe.tags.any((t) => t.contains(token))) score += 2;
      if (recipe.blurb(lang).toLowerCase().contains(token)) score += 1;
    }
    if (recipe.isDishDefault) score += 0.5;
    return score;
  }
}
