import 'dart:convert';

import 'package:flutter/services.dart';

import 'corpus.dart';
import 'matching.dart';
import 'model/profile.dart';
import 'model/recipe.dart';
import 'pagination.dart';

/// One entry of a partition's search index chunk.
class SearchIndexEntry {
  final String recipeId;
  final Map<String, List<String>> tokens; // lang -> tokens

  const SearchIndexEntry({required this.recipeId, required this.tokens});

  factory SearchIndexEntry.fromJson(Map<String, dynamic> json) => SearchIndexEntry(
        recipeId: json['recipe_id'] as String,
        tokens: (json['tokens'] as Map<String, dynamic>).map(
          (lang, value) => MapEntry(lang, (value as List).cast<String>()),
        ),
      );
}

/// Build-time-generated, chunked search index. Tokenizes title, tags and
/// ingredient names per language. A search session visits partitions in
/// manifest order (launch partitions first), loading chunks on demand.
class SearchEngine {
  final Corpus corpus;
  final Matcher matcher;

  SearchEngine({required this.corpus, required this.matcher});

  final Map<String, List<SearchIndexEntry>> _chunks = {};

  Future<List<SearchIndexEntry>> _chunk(String partitionId) async {
    final cached = _chunks[partitionId];
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/search/$partitionId.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (json['entries'] as List)
        .map((e) => SearchIndexEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    _chunks[partitionId] = entries;
    return entries;
  }

  static List<String> tokenize(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-zäöüßà-ÿ0-9]+'))
      .where((t) => t.length >= 2)
      .toList();

  /// All matching recipe ids for [query], in partition order. Profile filters
  /// apply post-match. Tag filters (diet/effort/… ids) narrow further.
  Future<List<String>> matchingIds(
    String query, {
    required UserProfile profile,
    Set<String> tagFilters = const {},
    bool ignoreCalorieTarget = false,
  }) async {
    final queryTokens = tokenize(query);
    final results = <String>[];
    for (final partition in corpus.manifest.orderedPartitions) {
      final entries = await _chunk(partition.id);
      for (final entry in entries) {
        final recipe = await corpus.loadRecipe(entry.recipeId);
        if (recipe == null) continue;
        if (!matcher.isVisible(recipe, profile,
            ignoreCalorieTarget: ignoreCalorieTarget)) {
          continue;
        }
        if (tagFilters.isNotEmpty &&
            !tagFilters.every((t) => recipe.tags.contains(t) || recipe.diet == t)) {
          continue;
        }
        if (queryTokens.isEmpty) {
          results.add(recipe.id);
          continue;
        }
        // Match against tokens in the profile language plus every language, so
        // "döner" finds the dish and "knoblauch" finds garlic.
        final allTokens = entry.tokens.values.expand((t) => t).toSet();
        final hit = queryTokens.every(
          (qt) => allTokens.any((t) => t.startsWith(qt) || t.contains(qt)),
        );
        if (hit) results.add(recipe.id);
      }
    }
    return results;
  }

  /// Cursor-based search: 20 items per page, infinite scroll with prefetch.
  /// The cursor is an opaque offset into the matching-id list.
  Future<Page<Recipe>> search(
    String query, {
    required UserProfile profile,
    Set<String> tagFilters = const {},
    String? cursor,
    int pageSize = 20,
    bool ignoreCalorieTarget = false,
  }) async {
    final ids = await matchingIds(query,
        profile: profile, tagFilters: tagFilters, ignoreCalorieTarget: ignoreCalorieTarget);
    final start = cursor == null ? 0 : int.tryParse(cursor) ?? 0;
    final end = (start + pageSize).clamp(0, ids.length);
    final pageIds = ids.sublist(start, end);
    final recipes = <Recipe>[];
    for (final id in pageIds) {
      final recipe = await corpus.loadRecipe(id);
      if (recipe != null) recipes.add(recipe);
    }
    final hasMore = end < ids.length;
    return Page(items: recipes, nextCursor: hasMore ? end.toString() : null);
  }

  PaginationController<Recipe> searchController(
    String query, {
    required UserProfile profile,
    Set<String> tagFilters = const {},
    int pageSize = 20,
    bool ignoreCalorieTarget = false,
  }) {
    String? cursor;
    return PaginationController<Recipe>(
      pageSize: pageSize,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetcher: (page, _) async {
        final result = await search(query,
            profile: profile,
            tagFilters: tagFilters,
            cursor: cursor,
            pageSize: pageSize,
            ignoreCalorieTarget: ignoreCalorieTarget);
        cursor = result.nextCursor;
        return result;
      },
    );
  }
}
