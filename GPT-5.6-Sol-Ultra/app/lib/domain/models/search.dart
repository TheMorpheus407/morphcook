import 'package:collection/collection.dart';

import 'recipe.dart';

class SearchQuery {
  SearchQuery({
    this.text = '',
    this.languageCode = 'en',
    Set<String> tags = const {},
    Set<String> cuisineTags = const {},
    Set<String> mealTypes = const {},
    this.cursor,
    int pageSize = 20,
  }) : tags = UnmodifiableSetView(Set.of(tags)),
       cuisineTags = UnmodifiableSetView(Set.of(cuisineTags)),
       mealTypes = UnmodifiableSetView(Set.of(mealTypes)),
       pageSize = pageSize.clamp(1, 20);

  final String text;
  final String languageCode;
  final Set<String> tags;
  final Set<String> cuisineTags;
  final Set<String> mealTypes;
  final String? cursor;
  final int pageSize;

  SearchQuery copyWith({
    String? text,
    String? languageCode,
    Set<String>? tags,
    Set<String>? cuisineTags,
    Set<String>? mealTypes,
    Object? cursor = _unset,
    int? pageSize,
  }) => SearchQuery(
    text: text ?? this.text,
    languageCode: languageCode ?? this.languageCode,
    tags: tags ?? this.tags,
    cuisineTags: cuisineTags ?? this.cuisineTags,
    mealTypes: mealTypes ?? this.mealTypes,
    cursor: identical(cursor, _unset) ? this.cursor : cursor as String?,
    pageSize: pageSize ?? this.pageSize,
  );
}

class RecipeSearchResult {
  RecipeSearchResult({
    required this.recipe,
    required this.textScore,
    Iterable<String> matchedTokens = const [],
  }) : matchedTokens = UnmodifiableSetView(Set.of(matchedTokens));

  final Recipe recipe;
  final int textScore;
  final Set<String> matchedTokens;
}

class SearchPage {
  SearchPage({
    Iterable<RecipeSearchResult> items = const [],
    required this.nextCursor,
    required this.totalMatches,
    Iterable<String> loadedPartitionIds = const [],
  }) : items = UnmodifiableListView(List.of(items)),
       loadedPartitionIds = UnmodifiableSetView(Set.of(loadedPartitionIds));

  final List<RecipeSearchResult> items;
  final String? nextCursor;
  final int totalMatches;
  final Set<String> loadedPartitionIds;

  bool get hasMore => nextCursor != null;
  bool get isEmpty => items.isEmpty;
}

const _unset = Object();
