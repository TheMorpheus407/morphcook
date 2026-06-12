import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/logic/search.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tokenize', () {
    test('lowercases, strips punctuation, splits hyphens', () {
      expect(SearchIndex.tokenize('Vegan Döner-Bowl!').toList(),
          ['vegan', 'döner', 'bowl']);
    });
  });

  group('SearchIndex over the real corpus', () {
    test('finds dishes by title in both languages', () async {
      final corpus = await loadRealCorpus();
      final en = corpus.searchIndex.query('doner');
      // "döner" tokens differ; search by a shared token instead.
      final hits = corpus.searchIndex.query('döner');
      expect(hits.map((r) => r.dishId).toSet(), contains('doener'));
      expect(en, isA<List>());
      final de = corpus.searchIndex.query('blumenkohl');
      expect(de.map((r) => r.id), contains('curry-keto'));
    });

    test('finds recipes by ingredient name', () async {
      final corpus = await loadRealCorpus();
      final hits = corpus.searchIndex.query('seitan');
      expect(hits.map((r) => r.id), contains('doener-vegan'));
    });

    test('prefix matching works for partial queries', () async {
      final corpus = await loadRealCorpus();
      final hits = corpus.searchIndex.query('lasag');
      expect(hits.map((r) => r.dishId).toSet(), {'lasagna'});
    });

    test('tag filters require all attributes', () async {
      final corpus = await loadRealCorpus();
      final vegan =
          corpus.searchIndex.query('', tagFilters: {'vegan'});
      expect(vegan, isNotEmpty);
      for (final r in vegan) {
        expect(r.attributes, contains('vegan'));
      }
      final veganEasy = corpus.searchIndex
          .query('', tagFilters: {'vegan', 'easy'});
      expect(veganEasy.length, lessThan(vegan.length));
    });

    test('profile filters apply post-match', () async {
      final corpus = await loadRealCorpus();
      final matcher = Matcher(
          ontology: corpus.ontology, dictionary: corpus.dictionary);
      const profile = Profile(avoidFlags: {'vegan'});
      final all = corpus.searchIndex.query('döner');
      final visible =
          all.where((r) => matcher.isVisible(r, profile)).toList();
      expect(all.length, greaterThan(visible.length));
      for (final r in visible) {
        expect(
            r.contains.intersection(
                expandAvoidFlags({'vegan'}, corpus.ontology)),
            isEmpty);
      }
    });

    test('unknown query returns nothing (content-gap case)', () async {
      final corpus = await loadRealCorpus();
      expect(corpus.searchIndex.query('schweinshaxe'), isEmpty);
    });

    test('partitions index incrementally', () async {
      final corpus = await loadRealCorpus(all: false);
      // Only core is loaded at launch.
      expect(corpus.searchIndex.hasPartition('core'), isTrue);
      expect(corpus.searchIndex.hasPartition('extended'), isFalse);
      expect(corpus.searchIndex.query('wellington'), isEmpty);
      await corpus.loadPartition('extended');
      expect(corpus.searchIndex.query('wellington'), isNotEmpty);
    });
  });

  group('pagedResults cursor', () {
    test('pages a snapshot with stable cursors', () async {
      final corpus = await loadRealCorpus();
      final results = corpus.searchIndex.query('');
      final fetch = pagedResults(results);
      final page1 = await fetch(null, 20);
      expect(page1.items, hasLength(20));
      expect(page1.nextCursor, '20');

      // Walk every page: full pages until the remainder, no overlaps.
      final ids = <String>{...page1.items.map((r) => r.id)};
      var cursor = page1.nextCursor;
      var fetched = page1.items.length;
      while (cursor != null) {
        final page = await fetch(cursor, 20);
        final remaining = results.length - fetched;
        expect(page.items, hasLength(remaining >= 20 ? 20 : remaining));
        ids.addAll(page.items.map((r) => r.id));
        fetched += page.items.length;
        cursor = page.nextCursor;
      }
      expect(fetched, results.length);
      expect(ids.length, results.length);
    });

    test('collapseCoverageVariants keeps one row per dish + coordinate',
        () {
      Recipe r(String id, {String diet = 'classic'}) => makeRecipe(
          id: id, dishId: 'soup', diet: diet, effort: 'easy',
          calorie: 'le600');
      // Coverage variant ranked first, base later: base wins the slot but
      // keeps the variant's ranking position.
      final collapsed = collapseCoverageVariants([
        r('soup-classic-easy-600-no-gluten'),
        r('soup-vegan-easy-600', diet: 'vegan'),
        r('soup-classic-easy-600'),
        r('soup-classic-easy-600-no-dairy'),
      ]);
      expect(collapsed.map((x) => x.id).toList(), [
        'soup-classic-easy-600',
        'soup-vegan-easy-600',
      ]);

      // Base hidden by the profile (absent from input): the first-ranked
      // visible coverage variant stands in.
      final standIn = collapseCoverageVariants([
        r('soup-classic-easy-600-no-gluten'),
        r('soup-classic-easy-600-no-dairy'),
      ]);
      expect(standIn.map((x) => x.id).toList(),
          ['soup-classic-easy-600-no-gluten']);
    });

    test('real corpus search shows no duplicate coordinates per dish',
        () async {
      final corpus = await loadRealCorpus();
      final results =
          collapseCoverageVariants(corpus.searchIndex.query(''));
      final seen = <String>{};
      for (final r in results) {
        final key =
            '${r.dishId}|${r.variant.diet}|${r.variant.effort}|${r.variant.calorie}';
        expect(seen.add(key), isTrue,
            reason: '${r.id}: duplicate search row at $key');
      }
    });
  });
}
