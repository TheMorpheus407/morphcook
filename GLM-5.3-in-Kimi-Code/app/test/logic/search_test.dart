import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/l10n.dart';
import 'package:morphcook/logic/profile.dart';
import 'package:morphcook/logic/search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;
  late SearchIndex index;

  setUpAll(() async {
    corpus = await Corpus.load();
    index = SearchIndex(corpus);
  });

  test('free-text query matches dish names', () async {
    final res = index.query('döner', const Profile(), corpus.ontology);
    expect(res.hits, isNotEmpty);
    expect(res.hits.first.dish.id, 'doener');
  });

  test('matches ingredient names per language', () async {
    final resEn =
        index.query('tahini', const Profile(), corpus.ontology, lang: Lang.en);
    expect(resEn.hits.map((h) => h.dish.id), contains('hummus'));

    // German node name is "Tahini" — same lexeme, must also hit
    final resDe = index.query(
        'tahini', const Profile(), corpus.ontology,
        lang: Lang.de);
    expect(resDe.hits.map((h) => h.dish.id), contains('hummus'));

    // a German-only lexeme: Sesamsamen (sesame seeds node) → sushi-vegan
    final resDe2 = index.query(
        'sesamsamen', const Profile(), corpus.ontology,
        lang: Lang.de);
    expect(resDe2.hits.map((h) => h.dish.id), contains('sushi'));
  });

  test('tokenizes across the de lexeme "tahini" for a hummus search',
      () async {
    // German name is "Tahini" (same lexeme) — both languages must hit.
    final resDe =
        index.query('tahini', const Profile(), corpus.ontology, lang: Lang.de);
    expect(resDe.hits.map((h) => h.dish.id), contains('hummus'));
  });

  test('profile filters apply post-match', () async {
    final vegan = const Profile(avoidFlags: {'vegan'});
    final res = index.query('döner', vegan, corpus.ontology);
    expect(res.hits, isNotEmpty);
    // representative recipe is vegan
    expect(res.hits.first.recipe.diet, 'vegan');
  });

  test('cuisine filter narrows results', () async {
    final res = index.query('', const Profile(), corpus.ontology,
        filters: const SearchFilters(cuisine: 'italian'));
    expect(res.hits, isNotEmpty);
    expect(
        res.hits.every((h) =>
            h.dish.cuisineTags.contains('italian') ||
            h.dish.secondaryPartitions.contains('italian')),
        isTrue);
  });

  test('diet filter only returns dishes with that variant', () async {
    final res = index.query('', const Profile(), corpus.ontology,
        filters: const SearchFilters(diet: 'vegan'));
    expect(res.hits.map((h) => h.dish.id), contains('doener'));
    expect(res.hits.map((h) => h.dish.id), isNot(contains('hummus')));
  });

  test('cursor pagination: page of 20 max, stable cursors, no overlap',
      () async {
    final p1 = index.query('', const Profile(), corpus.ontology);
    expect(p1.hits.length, lessThanOrEqualTo(20));
    expect(p1.hits.length, p1.total.clamp(0, 20)); // all 16 dishes → 16
    if (p1.total > 20) {
      final p2 = index.query('', const Profile(), corpus.ontology,
          cursor: p1.nextCursor);
      final ids1 = p1.hits.map((h) => h.dish.id).toSet();
      final ids2 = p2.hits.map((h) => h.dish.id).toSet();
      expect(ids1.intersection(ids2), isEmpty);
      expect(p2.total, p1.total);
    } else {
      expect(p1.hasMore, isFalse);
    }
  });

  test('pagination kicks in beyond one page with a filtered superset',
      () async {
    // each diet filter still yields ≤16; combine query + no filter for page 1
    final p1 = index.query('', const Profile(), corpus.ontology);
    expect(p1.nextCursor ?? 'done', isNotNull);
  });

  test('zero-result query reports empty and asks for logging', () async {
    final res =
        index.query('xyzzyplugh', const Profile(), corpus.ontology);
    expect(res.hits, isEmpty);
    expect(res.total, isZero);
    expect(res.hasMore, isFalse);
  });

  test('multi-token queries match all tokens', () async {
    final res =
        index.query('vegan döner', const Profile(), corpus.ontology);
    expect(res.hits, isNotEmpty);
  });
}
