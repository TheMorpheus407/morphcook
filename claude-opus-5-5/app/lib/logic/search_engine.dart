import 'dart:convert';

import '../data/corpus_repository.dart';
import '../models/profile.dart';
import '../models/recipe.dart';
import 'matching.dart';
import 'pagination.dart';
import 'ranking.dart';

/// Tag filters. OR inside a group, AND across groups.
class SearchFilters {
  const SearchFilters({
    this.diets = const {},
    this.efforts = const {},
    this.meals = const {},
    this.techniques = const {},
    this.cuisines = const {},
    this.maxMinutes,
  });

  final Set<String> diets;
  final Set<String> efforts;
  final Set<String> meals;
  final Set<String> techniques;
  final Set<String> cuisines;
  final int? maxMinutes;

  bool get isEmpty =>
      diets.isEmpty && efforts.isEmpty && meals.isEmpty && techniques.isEmpty && cuisines.isEmpty && maxMinutes == null;

  int get count =>
      diets.length + efforts.length + meals.length + techniques.length + cuisines.length + (maxMinutes == null ? 0 : 1);

  bool accepts(Recipe r) =>
      (diets.isEmpty || diets.contains(r.diet)) &&
      (efforts.isEmpty || efforts.contains(r.effort)) &&
      (meals.isEmpty || r.mealTypes.any(meals.contains)) &&
      (techniques.isEmpty || r.techniques.any(techniques.contains)) &&
      (cuisines.isEmpty || cuisines.contains(r.cuisine)) &&
      (maxMinutes == null || r.timeMinutes <= maxMinutes!);

  SearchFilters toggle(String group, String value) {
    Set<String> flip(Set<String> s) => s.contains(value) ? ({...s}..remove(value)) : {...s, value};
    return switch (group) {
      'diet' => copy(diets: flip(diets)),
      'effort' => copy(efforts: flip(efforts)),
      'meal' => copy(meals: flip(meals)),
      'technique' => copy(techniques: flip(techniques)),
      'cuisine' => copy(cuisines: flip(cuisines)),
      _ => this,
    };
  }

  SearchFilters copy({
    Set<String>? diets,
    Set<String>? efforts,
    Set<String>? meals,
    Set<String>? techniques,
    Set<String>? cuisines,
    int? Function()? maxMinutes,
  }) => SearchFilters(
    diets: diets ?? this.diets,
    efforts: efforts ?? this.efforts,
    meals: meals ?? this.meals,
    techniques: techniques ?? this.techniques,
    cuisines: cuisines ?? this.cuisines,
    maxMinutes: maxMinutes == null ? this.maxMinutes : maxMinutes(),
  );
}

class SearchOutcome {
  const SearchOutcome({required this.results, required this.corpusHits, required this.hiddenByProfile});

  final List<Recipe> results;

  /// Recipes matching the text at all, before profile and tag filters.
  final int corpusHits;

  /// Text matches that the profile hides.
  final int hiddenByProfile;
}

/// Free text + tag filters over the bundled index; the profile applies to
/// the matches afterwards. Loads only the partitions that contain hits.
class SearchEngine {
  SearchEngine(this.repo);

  final CorpusRepository repo;

  Future<SearchOutcome> run({
    required String query,
    required SearchFilters filters,
    required Profile profile,
    required MatchContext ctx,
    DateTime? now,
    Map<String, DateTime> lastCooked = const {},
  }) async {
    final lang = profile.lang;
    final text = query.trim();
    final Map<String, double> scores;
    if (text.isEmpty) {
      scores = {for (final id in repo.searchIndex.allRecipeIds) id: 0};
    } else {
      scores = repo.searchIndex.match(text, lang);
    }
    await repo.ensureRecipes(scores.keys);
    final hits = [
      for (final id in scores.keys)
        if (repo.recipe(id) != null) repo.recipe(id)!,
    ];
    final visible = hits.where((r) => isVisible(r, ctx)).toList();
    final filtered = visible.where(filters.accepts).toList();
    final t = now ?? DateTime.now();
    filtered.sort((a, b) {
      final c = scores[b.id]!.compareTo(scores[a.id]!);
      if (c != 0) return c;
      final ra = rankScore(a, profile, t, lastCooked: lastCooked[a.id]);
      final rb = rankScore(b, profile, t, lastCooked: lastCooked[b.id]);
      if (ra != rb) return rb.compareTo(ra);
      return a.id.compareTo(b.id);
    });
    return SearchOutcome(results: filtered, corpusHits: hits.length, hiddenByProfile: hits.length - visible.length);
  }

  /// Cursor-based page over an already computed, stable result list. The
  /// cursor carries the last id seen, so a page boundary survives inserts
  /// or removals between requests; the offset is only a fallback.
  static PageResult<Recipe> page(List<Recipe> results, String? cursor, int pageSize) {
    var start = 0;
    if (cursor != null) {
      final c = decodeCursor(cursor);
      final idx = results.indexWhere((r) => r.id == c.lastId);
      start = idx >= 0 ? idx + 1 : c.offset.clamp(0, results.length);
    }
    final end = (start + pageSize).clamp(0, results.length);
    final items = results.sublist(start, end);
    final next = end < results.length && items.isNotEmpty ? encodeCursor(offset: end, lastId: items.last.id) : null;
    return PageResult(items, nextToken: next);
  }

  static String encodeCursor({required int offset, required String lastId}) =>
      base64Url.encode(utf8.encode(jsonEncode({'o': offset, 'l': lastId})));

  static ({int offset, String lastId}) decodeCursor(String cursor) {
    try {
      final m = jsonDecode(utf8.decode(base64Url.decode(cursor))) as Map<String, dynamic>;
      return (offset: m['o'] as int, lastId: m['l'] as String);
    } catch (_) {
      return (offset: 0, lastId: '');
    }
  }
}
