import 'dart:collection';
import 'dart:convert';

import 'matching.dart';
import 'models/dish.dart';
import 'models/ingredient.dart';
import 'models/local_state.dart';
import 'models/localized_text.dart';
import 'models/recipe.dart';
import 'models/search.dart';
import 'models/user_profile.dart';

class BilingualTokenizer {
  const BilingualTokenizer();

  List<String> tokenize(String value) {
    final folded = fold(value);
    return folded
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  String fold(String value) {
    const replacements = {
      'ä': 'a',
      'ö': 'o',
      'ü': 'u',
      'ß': 'ss',
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ý': 'y',
    };
    final result = StringBuffer();
    for (final rune in value.trim().toLowerCase().runes) {
      final character = String.fromCharCode(rune);
      result.write(replacements[character] ?? character);
    }
    return result
        .toString()
        .replaceAll('ae', 'a')
        .replaceAll('oe', 'o')
        .replaceAll('ue', 'u');
  }
}

class RecipeSearchEngine {
  RecipeSearchEngine({
    required Iterable<Recipe> recipes,
    required Iterable<Dish> dishes,
    required this.ingredients,
    required this.matcher,
    this.tokenizer = const BilingualTokenizer(),
  }) : recipes = UnmodifiableListView(List.of(recipes)),
       dishesById = UnmodifiableMapView({
         for (final dish in dishes) dish.id: dish,
       });

  final List<Recipe> recipes;
  final Map<String, Dish> dishesById;
  final IngredientDictionary ingredients;
  final RecipeMatcher matcher;
  final BilingualTokenizer tokenizer;

  SearchPage search(
    SearchQuery query,
    UserProfile profile, {
    Iterable<String> loadedPartitionIds = const [],
  }) {
    final language = normalizeLanguageCode(query.languageCode);
    final queryTokens = tokenizer.tokenize(query.text).toSet();
    final normalizedPhrase = tokenizer.fold(query.text);
    final matches = <RecipeSearchResult>[];

    for (final recipe in recipes) {
      if (!matcher.isVisible(recipe, profile)) continue;
      if (!recipe.tags.containsAll(query.tags)) continue;
      if (query.cuisineTags.isNotEmpty &&
          recipe.cuisineTags.intersection(query.cuisineTags).isEmpty) {
        continue;
      }
      if (query.mealTypes.isNotEmpty &&
          recipe.mealTypes.intersection(query.mealTypes).isEmpty) {
        continue;
      }

      final document = _documentFor(recipe, language);
      final matched = <String>{};
      var everyTokenMatches = true;
      for (final queryToken in queryTokens) {
        final tokenMatches = document.allTokens.any(
          (candidate) =>
              candidate == queryToken || candidate.startsWith(queryToken),
        );
        if (!tokenMatches) {
          everyTokenMatches = false;
          break;
        }
        matched.add(queryToken);
      }
      if (!everyTokenMatches) continue;

      var score = 0;
      if (normalizedPhrase.isNotEmpty) {
        if (document.primaryTitle == normalizedPhrase) {
          score += 1000;
        } else if (document.primaryTitle.startsWith(normalizedPhrase)) {
          score += 500;
        } else if (document.allTitles.contains(normalizedPhrase)) {
          score += 350;
        }
      }
      for (final token in queryTokens) {
        if (document.titleTokens.contains(token)) {
          score += 160;
        } else if (document.titleTokens.any(
          (value) => value.startsWith(token),
        )) {
          score += 120;
        } else if (document.ingredientTokens.contains(token)) {
          score += 80;
        } else {
          score += 40;
        }
      }
      // Empty searches remain deterministic and useful for tag-only browsing.
      score += recipe.tags.intersection(query.tags).length * 30;
      matches.add(
        RecipeSearchResult(
          recipe: recipe,
          textScore: score,
          matchedTokens: matched,
        ),
      );
    }

    matches.sort((a, b) {
      final byScore = b.textScore.compareTo(a.textScore);
      if (byScore != 0) return byScore;
      final byTitle = a.recipe.name
          .resolve(language)
          .compareTo(b.recipe.name.resolve(language));
      return byTitle != 0 ? byTitle : a.recipe.id.compareTo(b.recipe.id);
    });

    final signature = _signature(query);
    final offset = _decodeCursor(query.cursor, signature);
    final safeOffset = offset.clamp(0, matches.length);
    final end = (safeOffset + query.pageSize).clamp(0, matches.length);
    final nextCursor = end < matches.length
        ? _encodeCursor(end, signature)
        : null;
    return SearchPage(
      items: matches.sublist(safeOffset, end),
      nextCursor: nextCursor,
      totalMatches: matches.length,
      loadedPartitionIds: loadedPartitionIds,
    );
  }

  _SearchDocument _documentFor(Recipe recipe, String language) {
    final dish = dishesById[recipe.dishId];
    final primaryTitles = [
      recipe.name.resolve(language),
      if (dish != null) dish.name.resolve(language),
    ];
    final fallbackTitles = [
      recipe.name.resolve('en'),
      recipe.name.resolve('de'),
      if (dish != null) dish.name.resolve('en'),
      if (dish != null) dish.name.resolve('de'),
    ];
    final ingredientTokens = <String>{};
    for (final ingredientId in recipe.ingredientIds) {
      final ingredient = ingredients[ingredientId];
      ingredientTokens.addAll(tokenizer.tokenize(ingredientId));
      if (ingredient != null) {
        for (final text in ingredient.name.values.values) {
          ingredientTokens.addAll(tokenizer.tokenize(text));
        }
        for (final aliases in ingredient.aliases.values) {
          for (final alias in aliases) {
            ingredientTokens.addAll(tokenizer.tokenize(alias));
          }
        }
      }
    }
    final titleTokens = {
      for (final title in [...primaryTitles, ...fallbackTitles])
        ...tokenizer.tokenize(title),
    };
    final allTokens = <String>{
      ...titleTokens,
      ...ingredientTokens,
      ...recipe.tags.expand(tokenizer.tokenize),
      ...recipe.cuisineTags.expand(tokenizer.tokenize),
      ...recipe.mealTypes.expand(tokenizer.tokenize),
      for (final text in recipe.description.values.values)
        ...tokenizer.tokenize(text),
      if (dish != null)
        for (final text in dish.heroText.values.values)
          ...tokenizer.tokenize(text),
      for (final terms in recipe.searchTerms.values)
        for (final term in terms) ...tokenizer.tokenize(term),
    };
    return _SearchDocument(
      primaryTitle: tokenizer.fold(primaryTitles.first),
      allTitles: fallbackTitles.map(tokenizer.fold).toSet(),
      titleTokens: titleTokens,
      ingredientTokens: ingredientTokens,
      allTokens: allTokens,
    );
  }

  String _signature(SearchQuery query) {
    final fields = [
      tokenizer.fold(query.text),
      normalizeLanguageCode(query.languageCode),
      (query.tags.toList()..sort()).join(','),
      (query.cuisineTags.toList()..sort()).join(','),
      (query.mealTypes.toList()..sort()).join(','),
      '${query.pageSize}',
    ];
    return fields.join('|');
  }

  String _encodeCursor(int offset, String signature) =>
      base64Url.encode(utf8.encode(jsonEncode({'o': offset, 'q': signature})));

  int _decodeCursor(String? cursor, String signature) {
    if (cursor == null || cursor.isEmpty) return 0;
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(cursor)));
      if (decoded is Map && decoded['q'] == signature && decoded['o'] is int) {
        return decoded['o'] as int;
      }
    } on FormatException {
      // Invalid/stale cursors safely restart pagination.
    }
    return 0;
  }
}

class ContentGapTracker {
  ContentGapTracker([Iterable<ContentRequest> initial = const []]) {
    for (final request in initial) {
      _requests[_key(request.query, request.languageCode)] = request;
    }
  }

  final Map<String, ContentRequest> _requests = {};

  List<ContentRequest> get requests {
    final result = _requests.values.toList()
      ..sort((a, b) => b.lastSearchedAt.compareTo(a.lastSearchedAt));
    return UnmodifiableListView(result);
  }

  /// Records only meaningful, zero-result free-text searches.
  bool recordIfGap(SearchQuery query, SearchPage page, {DateTime? searchedAt}) {
    final text = query.text.trim();
    if (text.length < 2 || page.totalMatches != 0 || query.cursor != null) {
      return false;
    }
    final language = normalizeLanguageCode(query.languageCode);
    final key = _key(text, language);
    final previous = _requests[key];
    _requests[key] = ContentRequest(
      query: previous?.query ?? text,
      languageCode: language,
      lastSearchedAt: searchedAt ?? DateTime.now().toUtc(),
      count: (previous?.count ?? 0) + 1,
    );
    return true;
  }

  void clear() => _requests.clear();

  List<Object> toJson({bool humanReadable = false}) => humanReadable
      ? requests.map((request) => request.toJson()).toList()
      : requests.map((request) => request.query).toList();

  String _key(String query, String language) =>
      '$language:${tokenizerLikeFold(query)}';
}

class _SearchDocument {
  const _SearchDocument({
    required this.primaryTitle,
    required this.allTitles,
    required this.titleTokens,
    required this.ingredientTokens,
    required this.allTokens,
  });

  final String primaryTitle;
  final Set<String> allTitles;
  final Set<String> titleTokens;
  final Set<String> ingredientTokens;
  final Set<String> allTokens;
}

String tokenizerLikeFold(String value) => const BilingualTokenizer()
    .fold(value)
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
