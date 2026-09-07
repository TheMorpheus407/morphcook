import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/search_engine.dart';
import 'package:morphcook/domain/search_tokenizer.dart';

import 'helpers.dart';

void main() {
  late CorpusRepository repo;
  late SearchEngine engine;
  setUpAll(() async {
    repo = await loadRepo();
    engine = SearchEngine(repo);
  });

  test('tokenizer folds diacritics and splits', () {
    expect(tokenize('Veganer Döner, Käsespätzle!'), ['veganer', 'doner', 'kasespatzle']);
    expect(tokenize('a bb'), ['bb']);
  });

  test('finds döner with and without umlaut, in both languages', () async {
    final ctx = ctxFor(repo, const Profile());
    for (final q in ['döner', 'doner', 'Doener']) {
      final page = await engine.search(SearchQuery(text: q), lang: 'en', ctx: ctx);
      expect(page.items.map((h) => h.dish.id).toSet(), contains('doener'), reason: q);
    }
    final de = await engine.search(const SearchQuery(text: 'veganer döner'), lang: 'de', ctx: ctx);
    expect(de.items.first.recipe.id, 'doener-vegan-easy');
  });

  test('results respect the profile after matching', () async {
    final vegan = ctxFor(repo, const Profile(avoidFlags: {'vegan'}));
    final page = await engine.search(const SearchQuery(text: 'döner'), lang: 'en', ctx: vegan);
    expect(page.items.map((h) => h.recipe.id), ['doener-vegan-easy']);
    expect(page.totalCandidates, greaterThan(1));
  });

  test('cursor pagination walks the whole candidate list', () async {
    final ctx = ctxFor(repo, const Profile());
    final all = <String>[];
    String? cursor;
    var pages = 0;
    do {
      final page = await engine.search(const SearchQuery(text: 'easy'), lang: 'en', ctx: ctx, cursor: cursor, pageSize: 7);
      all.addAll(page.items.map((h) => h.recipe.id));
      cursor = page.nextCursor;
      pages++;
    } while (cursor != null && pages < 50);
    expect(pages, greaterThan(1));
    expect(all.toSet().length, all.length);
  });

  test('tag filters narrow results and partitions load on demand', () async {
    final fresh = await loadRepo();
    final freshEngine = SearchEngine(fresh);
    final ctx = ctxFor(fresh, const Profile());
    expect(fresh.loadedPartitions, {'core'});
    final page = await freshEngine.search(const SearchQuery(text: 'tiramisu'), lang: 'en', ctx: ctx);
    expect(page.items, isNotEmpty);
    expect(fresh.loadedPartitions, contains('extended'));
    final tagged = await engine.search(const SearchQuery(text: 'rice', tags: {'korean'}), lang: 'en', ctx: ctx);
    expect(tagged.items.every((h) => h.dish.cuisineTags.contains('korean')), isTrue);
  });

  test('zero results report zero candidates so the query can be logged', () async {
    final ctx = ctxFor(repo, const Profile());
    final page = await engine.search(const SearchQuery(text: 'sushi burrito xyz'), lang: 'en', ctx: ctx);
    expect(page.items, isEmpty);
    expect(page.totalCandidates, 0);
  });
}
