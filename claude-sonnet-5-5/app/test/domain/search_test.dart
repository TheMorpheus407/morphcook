import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/asset_source.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/ranking.dart';
import 'package:morphcook/domain/search/search_index.dart';
import 'package:morphcook/domain/search/search_service.dart';

void main() {
  late Corpus corpus;
  late SearchService service;
  final context = RankingContext(now: DateTime(2026, 9, 28, 13));

  setUp(() async {
    // A fresh service per test, so on-demand loading can be observed from zero.
    corpus = await Corpus.load(const FileAssetSource('assets'));
    service = SearchService(corpus: corpus);
  });

  SearchSession session(
    String query, {
    Profile profile = const Profile(),
    SearchFilters filters = const SearchFilters(),
  }) => service.session(query: query, filters: filters, profile: profile, context: context);

  Future<List<SearchHit>> all(SearchSession s, {int limit = 20}) async {
    final hits = <SearchHit>[];
    String? cursor;
    do {
      final page = await s.fetch(cursor: cursor, limit: limit);
      hits.addAll(page.hits);
      cursor = page.nextCursor;
    } while (cursor != null);
    return hits;
  }

  List<String> dishIds(Iterable<SearchHit> hits) => [for (final h in hits) h.dish.id];

  group('free text', () {
    test('finds a dish by its name, in either language', () async {
      expect(dishIds(await all(session('döner'))), contains('doener'));
      expect(dishIds(await all(session('doener'))), contains('doener'));
      expect(dishIds(await all(session('doner'))), contains('doener'));
      expect(dishIds(await all(session('Spätzle', profile: const Profile(lang: 'de')))), contains('kaesespaetzle'));
      expect(dishIds(await all(session('spaetzle'))), contains('kaesespaetzle'));
    });

    test('prefixes match while typing', () async {
      expect(dishIds(await all(session('carbo'))), contains('carbonara'));
      expect(dishIds(await all(session('tira'))), contains('tiramisu'));
    });

    test('matches ingredient names, in the interface language and in the other one', () async {
      expect(dishIds(await all(session('chickpeas'))), containsAll(['falafel', 'hummus']));
      expect(
        dishIds(await all(session('Kichererbsen', profile: const Profile(lang: 'de')))),
        containsAll(['falafel', 'hummus']),
      );
      expect(
        dishIds(await all(session('Kichererbsen'))),
        containsAll(['falafel', 'hummus']),
        reason: 'the other language still finds it',
      );
    });

    test('matches tags and diets', () async {
      expect(dishIds(await all(session('vegan'))), isNotEmpty);
      expect((await all(session('comfort'))).length, greaterThan(3));
      expect(dishIds(await all(session('italian'))), containsAll(['carbonara', 'lasagne', 'tiramisu']));
    });

    test('every word has to match: a query narrows down', () async {
      final wide = await all(session('pasta'));
      final narrow = await all(session('pasta mushroom'));
      expect(narrow.length, lessThanOrEqualTo(wide.length));
      expect(narrow, isNotEmpty);
      expect(await all(session('pasta zzzzqq')), isEmpty);
    });

    test('title matches outrank ingredient matches', () async {
      final hits = await all(session('tomato'));
      final soup = hits.indexWhere((h) => h.dish.id == 'tomato-soup');
      final other = hits.indexWhere((h) => h.dish.id != 'tomato-soup');
      expect(soup, greaterThanOrEqualTo(0));
      expect(soup, lessThan(other));
    });

    test('an empty query lists everything the profile allows', () async {
      final hits = await all(session(''));
      expect(hits.length, corpus.dishes.length);
    });

    test('a query that matches nothing finds nothing anywhere', () async {
      final page = await session('sushi').fetch();
      expect(page.hits, isEmpty);
      expect(page.nextCursor, isNull);
    });

    test('shows one row per dish, through its best variant', () async {
      final hits = await all(session('bolognese'));
      expect(dishIds(hits).where((id) => id == 'bolognese'), hasLength(1));
    });
  });

  group('profile filters apply to results', () {
    test('a vegan profile only sees vegan variants', () async {
      final hits = await all(session('bolognese', profile: const Profile(avoidFlags: {'vegan'})));
      expect(hits, hasLength(1));
      expect(hits.single.entry.id, 'bolognese-vegan');
    });

    test('avoided ingredients never show up', () async {
      final without = await all(session('pad thai', profile: const Profile(avoidIngredients: {'peanuts'})));
      expect(without, isNotEmpty);
      for (final hit in without) {
        expect(hit.entry.ingredientIds, isNot(contains('peanuts')));
      }
    });

    test('the time budget is a hard filter', () async {
      final hits = await all(session('', profile: const Profile(maxTimeMinutes: 20)));
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.entry.timeMinutes <= 20), isTrue);
    });

    test('the calorie target is a hard filter with tolerance', () async {
      final hits = await all(session('', profile: const Profile(calorieTarget: 400)));
      expect(hits, isNotEmpty);
      expect(hits.every((h) => (h.entry.caloriesPerServing - 400).abs() <= 150), isTrue);
    });

    test('a dish without a matching variant disappears from the results', () async {
      final hits = await all(session('tiramisu', profile: const Profile(avoidFlags: {'gluten', 'dairy'})));
      expect(hits, isEmpty);
    });
  });

  group('tag filters', () {
    test('attributes all have to match', () async {
      final hits = await all(session('', filters: const SearchFilters(attributes: {'vegan', 'easy'})));
      expect(hits, isNotEmpty);
      for (final hit in hits) {
        expect(hit.entry.attributes, containsAll(['vegan', 'easy']));
      }
    });

    test('meals match any', () async {
      final hits = await all(session('', filters: const SearchFilters(meals: {'breakfast', 'dessert'})));
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.entry.meal.contains('breakfast') || h.entry.meal.contains('dessert')), isTrue);
      expect(dishIds(hits), containsAll(['pancakes', 'tiramisu']));
    });

    test('cuisines match the dish', () async {
      final hits = await all(session('', filters: const SearchFilters(cuisines: {'asian'})));
      expect(dishIds(hits), containsAll(['pad-thai', 'ramen', 'green-curry']));
      expect(dishIds(hits), isNot(contains('carbonara')));
    });

    test('filters combine with the query', () async {
      final hits = await all(session('rice', filters: const SearchFilters(attributes: {'vegan'})));
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.entry.attributes.contains('vegan')), isTrue);
    });

    test('filter bookkeeping', () {
      const filters = SearchFilters(attributes: {'vegan'}, meals: {'lunch'}, cuisines: {'italian'});
      expect(filters.count, 3);
      expect(filters.isEmpty, isFalse);
      expect(const SearchFilters().isEmpty, isTrue);
      expect(filters.copyWith(attributes: const <String>{}).count, 2);
    });
  });

  group('pagination is cursor based', () {
    test('a page holds at most the requested number of items', () async {
      final page = await session('').fetch(limit: 20);
      expect(page.hits, hasLength(20));
      expect(page.nextCursor, isNotNull);
    });

    test('the cursor continues where the page ended, without repeats', () async {
      final s = session('');
      final first = await s.fetch(limit: 10);
      final second = await s.fetch(cursor: first.nextCursor, limit: 10);
      final third = await s.fetch(cursor: second.nextCursor, limit: 10);
      final ids = [...dishIds(first.hits), ...dishIds(second.hits), ...dishIds(third.hits)];
      expect(ids.toSet().length, ids.length);
      expect(ids.length, 28);
      expect(third.nextCursor, isNull);
    });

    test('the cursor is stable: the same cursor returns the same page', () async {
      final s = session('');
      final first = await s.fetch(limit: 7);
      final a = await s.fetch(cursor: first.nextCursor, limit: 7);
      final b = await session('').fetch(cursor: first.nextCursor, limit: 7);
      expect(dishIds(a.hits), dishIds(b.hits));
    });

    test('a cursor is opaque text that encodes partition and offset', () {
      final cursor = SearchSession.encodeCursor(2, 15);
      expect(cursor, isNot(contains('{')));
      expect(SearchSession.decodeCursor(cursor), (2, 15));
      expect(SearchSession.decodeCursor(null), (0, 0));
    });
  });

  group('partitions load on demand', () {
    test('the core chunk answers first and other chunks stay closed while it fills the page', () async {
      expect(service.isChunkLoaded('core'), isFalse);
      final page = await session('').fetch(limit: 5);
      expect(page.hits, hasLength(5));
      expect(service.isChunkLoaded('core'), isTrue);
      expect(service.isChunkLoaded('cuisine-asian'), isFalse);
      expect(service.isChunkLoaded('cuisine-italian'), isFalse);
      expect(service.isChunkLoaded('cuisine-middle-eastern'), isFalse);
      expect(service.isChunkLoaded('extended'), isFalse);
    });

    test('a query for a dish outside core fetches the chunk that holds it', () async {
      final hits = await all(session('ramen'));
      expect(dishIds(hits), ['ramen']);
      expect(service.isChunkLoaded('cuisine-asian'), isTrue);
    });

    test('scrolling past the last core result continues into the next chunks', () async {
      final s = session('');
      final coreCount = corpus.dishes.values.where((d) => d.partitionId == 'core').length;
      final first = await s.fetch(limit: coreCount);
      expect(first.hits.every((h) => h.dish.partitionId == 'core'), isTrue);
      expect(first.nextCursor, isNotNull);
      final next = await s.fetch(cursor: first.nextCursor, limit: 50);
      expect(next.hits, isNotEmpty);
      expect(next.hits.every((h) => h.dish.partitionId != 'core'), isTrue);
      expect(service.isChunkLoaded('cuisine-italian'), isTrue);
    });

    test('each chunk is read only once', () async {
      final a = await service.chunk('core');
      final b = await service.chunk('core');
      expect(identical(a, b), isTrue);
    });
  });

  group('the query matcher', () {
    late List<IndexEntry> entries;

    setUp(() async => entries = await service.chunk('core'));

    IndexEntry entry(String id) => entries.firstWhere((e) => e.id == id);

    test('an empty query matches everything with a neutral score', () {
      expect(QueryMatcher('').isEmpty, isTrue);
      expect(QueryMatcher('').score(entry('doener-vegan'), 'en'), 1);
    });

    test('a title word scores higher than the same word in an ingredient', () {
      final title = QueryMatcher('bolognese').score(entry('bolognese-classic'), 'en');
      final ingredient = QueryMatcher('carrot').score(entry('bolognese-classic'), 'en');
      expect(title, greaterThan(ingredient));
      expect(ingredient, greaterThan(0));
    });

    test('exact tokens outrank prefixes', () {
      final exact = QueryMatcher('rice').score(entry('fried-rice-vegan'), 'en');
      final prefix = QueryMatcher('ric').score(entry('fried-rice-vegan'), 'en');
      expect(exact, greaterThan(prefix));
    });

    test('the interface language outranks the other one', () {
      final en = QueryMatcher('cheese').score(entry('alfredo-classic'), 'en');
      final de = QueryMatcher('cheese').score(entry('alfredo-classic'), 'de');
      expect(en, greaterThanOrEqualTo(de));
    });

    test('a word nothing matches scores zero', () {
      expect(QueryMatcher('zzzz').score(entry('doener-vegan'), 'en'), 0);
    });
  });

  group('ranking inside results', () {
    test('with equal text relevance the better ranked variant represents the dish', () async {
      final easy = await all(session('bolognese', profile: const Profile(preferredEffort: 'easy')));
      final hard = await all(session('bolognese', profile: const Profile(preferredEffort: 'hard')));
      expect(easy.single.entry.effort, 'easy');
      expect(hard.single.entry.effort, 'hard');
    });
  });
}
