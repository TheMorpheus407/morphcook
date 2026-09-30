import 'dart:convert';

import '../../core/text/text_fold.dart';
import '../../data/corpus.dart';
import '../../data/models/dish.dart';
import '../../data/models/profile.dart';
import '../matching.dart';
import '../ranking.dart';
import 'search_index.dart';

/// Tag filters: attributes must all match (AND), meals and cuisines match any.
class SearchFilters {
  const SearchFilters({
    this.attributes = const <String>{},
    this.meals = const <String>{},
    this.cuisines = const <String>{},
  });

  final Set<String> attributes;
  final Set<String> meals;
  final Set<String> cuisines;

  bool get isEmpty => attributes.isEmpty && meals.isEmpty && cuisines.isEmpty;
  int get count => attributes.length + meals.length + cuisines.length;

  SearchFilters copyWith({Set<String>? attributes, Set<String>? meals, Set<String>? cuisines}) => SearchFilters(
    attributes: attributes ?? this.attributes,
    meals: meals ?? this.meals,
    cuisines: cuisines ?? this.cuisines,
  );
}

/// One result row: a dish shown through its best matching variant.
class SearchHit {
  const SearchHit({required this.dish, required this.entry, required this.textScore, required this.rankScore});

  final Dish dish;
  final IndexEntry entry;
  final double textScore;
  final double rankScore;
}

class SearchPage {
  const SearchPage({required this.hits, required this.nextCursor});

  final List<SearchHit> hits;

  /// `null` when every partition has been searched.
  final String? nextCursor;
}

/// Scores a free-text query against index entries.
class QueryMatcher {
  QueryMatcher(String query) : _variants = [for (final word in TextFold.words(query)) TextFold.variants(word)];

  final List<Set<String>> _variants;

  bool get isEmpty => _variants.isEmpty;

  /// Every query word has to match some token as a prefix (title beats tags
  /// beat ingredients; exact tokens beat prefixes; the interface language
  /// beats other languages). Returns 0 when a word finds nothing.
  double score(IndexEntry entry, String lang) {
    if (_variants.isEmpty) return 1;
    var total = 0.0;
    for (final variants in _variants) {
      var best = 0.0;
      for (final MapEntry(key: entryLang, value: tokens) in entry.tokens.entries) {
        final languageWeight = entryLang == lang ? 1.0 : 0.5;
        best = _best(best, variants, tokens.title, 3 * languageWeight);
        best = _best(best, variants, tokens.tags, 2 * languageWeight);
        best = _best(best, variants, tokens.ingredients, 1 * languageWeight);
      }
      if (best == 0) return 0;
      total += best;
    }
    return total;
  }

  /// Exact token 2x weight, prefix 1x, and for longer words also a match inside
  /// a token at 0.5x, so "spätzle" finds "Käsespätzle" (German compounds).
  static double _best(double current, Set<String> variants, Set<String> tokens, double weight) {
    if (weight * 2 <= current) return current;
    for (final v in variants) {
      if (tokens.contains(v)) return weight * 2;
    }
    if (weight > current) {
      for (final v in variants) {
        for (final token in tokens) {
          if (token.startsWith(v)) return weight;
        }
      }
    }
    if (weight / 2 > current) {
      for (final v in variants) {
        if (v.length < _infixMinLength) continue;
        for (final token in tokens) {
          if (token.contains(v)) return weight / 2;
        }
      }
    }
    return current;
  }

  static const int _infixMinLength = 4;
}

/// Searches the bundled index chunk by chunk: the `core` chunk answers first,
/// the others are fetched on demand as the reader scrolls on.
class SearchService {
  SearchService({required this.corpus, this.ranking = const Ranking()});

  final Corpus corpus;
  final Ranking ranking;
  final Map<String, Future<List<IndexEntry>>> _chunks = <String, Future<List<IndexEntry>>>{};

  /// Loads one partition's index chunk once.
  Future<List<IndexEntry>> chunk(String partitionId) {
    return _chunks.putIfAbsent(partitionId, () async {
      final info = corpus.manifest.partition(partitionId)!;
      final json = await corpus.source.loadJson(info.searchIndex);
      return [for (final e in (json['entries'] as List)) IndexEntry.fromJson((e as Map).cast<String, dynamic>())];
    });
  }

  bool isChunkLoaded(String partitionId) => _chunks.containsKey(partitionId);

  SearchSession session({
    required String query,
    required SearchFilters filters,
    required Profile profile,
    required RankingContext context,
  }) {
    return SearchSession(service: this, query: query, filters: filters, profile: profile, context: context);
  }
}

/// One query with its filters. Pages are addressed by an opaque cursor that
/// encodes the partition and the offset inside it.
class SearchSession {
  SearchSession({
    required this.service,
    required this.query,
    required this.filters,
    required this.profile,
    required this.context,
  }) : _matcher = QueryMatcher(query),
       _filter = ProfileFilter.compile(profile, service.corpus.ontology, service.corpus.ingredients),
       _order = [
         ...service.corpus.manifest.launchOrder,
         for (final p in service.corpus.manifest.partitions)
           if (!service.corpus.manifest.launchOrder.contains(p.id)) p.id,
       ];

  final SearchService service;
  final String query;
  final SearchFilters filters;
  final Profile profile;
  final RankingContext context;
  final QueryMatcher _matcher;
  final ProfileFilter _filter;
  final List<String> _order;
  final Map<int, List<SearchHit>> _results = <int, List<SearchHit>>{};

  /// Partitions whose index chunk this session has touched so far.
  int get partitionsSearched => _results.length;

  static String encodeCursor(int partition, int offset) =>
      base64Url.encode(utf8.encode(jsonEncode(<String, int>{'p': partition, 'o': offset})));

  static (int, int) decodeCursor(String? cursor) {
    if (cursor == null) return (0, 0);
    final map = jsonDecode(utf8.decode(base64Url.decode(cursor))) as Map<String, dynamic>;
    return ((map['p'] as num).toInt(), (map['o'] as num).toInt());
  }

  /// Returns up to [limit] hits. Keeps reading further partitions until the
  /// page is full or everything has been searched, so an empty first page means
  /// the query really matched nothing anywhere.
  Future<SearchPage> fetch({String? cursor, int limit = 20}) async {
    var (partition, offset) = decodeCursor(cursor);
    final hits = <SearchHit>[];
    while (hits.length < limit && partition < _order.length) {
      final results = await _resultsFor(partition);
      if (offset >= results.length) {
        partition++;
        offset = 0;
        continue;
      }
      final take = (limit - hits.length).clamp(0, results.length - offset);
      hits.addAll(results.sublist(offset, offset + take));
      offset += take;
      if (offset >= results.length) {
        partition++;
        offset = 0;
      }
    }
    return SearchPage(hits: hits, nextCursor: partition < _order.length ? encodeCursor(partition, offset) : null);
  }

  Future<List<SearchHit>> _resultsFor(int partitionIndex) async {
    final cached = _results[partitionIndex];
    if (cached != null) return cached;
    final entries = await service.chunk(_order[partitionIndex]);
    final lang = profile.lang;
    final best = <String, SearchHit>{};
    for (final entry in entries) {
      final dish = service.corpus.dishes[entry.dishId];
      if (dish == null) continue;
      if (!_filter.isVisible(entry)) continue;
      if (!filters.attributes.every(entry.attributes.contains)) continue;
      if (filters.meals.isNotEmpty && !filters.meals.any(entry.meal.contains)) continue;
      if (filters.cuisines.isNotEmpty && !filters.cuisines.any(dish.cuisineTags.contains)) continue;
      final text = _matcher.score(entry, lang);
      if (text == 0) continue;
      final hit = SearchHit(
        dish: dish,
        entry: entry,
        textScore: text,
        rankScore: service.ranking.score(entry, profile, context),
      );
      final current = best[dish.id];
      if (current == null || _isBetter(hit, current)) best[dish.id] = hit;
    }
    final list = best.values.toList()
      ..sort((a, b) {
        final byText = b.textScore.compareTo(a.textScore);
        if (byText != 0) return byText;
        final byRank = b.rankScore.compareTo(a.rankScore);
        if (byRank != 0) return byRank;
        return a.dish.name.resolve(lang).compareTo(b.dish.name.resolve(lang));
      });
    _results[partitionIndex] = list;
    return list;
  }

  static bool _isBetter(SearchHit a, SearchHit b) {
    if (a.textScore != b.textScore) return a.textScore > b.textScore;
    if (a.rankScore != b.rankScore) return a.rankScore > b.rankScore;
    return a.entry.id.compareTo(b.entry.id) < 0;
  }
}
