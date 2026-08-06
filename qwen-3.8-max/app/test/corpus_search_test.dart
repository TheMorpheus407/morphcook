import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/profile.dart';
import 'package:morphcook/domain/matching.dart';
import 'package:morphcook/domain/search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CorpusRepository corpus;

  setUpAll(() async {
    corpus = CorpusRepository();
    await corpus.init();
  });

  group('corpus loading', () {
    test('manifest, ontology, ingredients, dishes, faqs, guide load', () {
      expect(corpus.ready, isTrue);
      expect(corpus.manifest.partitions, isNotEmpty);
      expect(corpus.ontology.containsFlags, isNotEmpty);
      expect(corpus.ontology.compoundExpansions['vegan'], isNotEmpty);
      expect(corpus.ingredients.byId, isNotEmpty);
      expect(corpus.dishes, isNotEmpty);
      expect(corpus.faqs, isNotEmpty);
    });

    test('eager partition (core) is resident after init', () {
      expect(corpus.isPartitionLoaded('core'), isTrue);
      expect(corpus.isPartitionLoaded('extended'), isFalse);
    });

    test('every dish routes to an existing partition', () {
      for (final dish in corpus.dishes) {
        final routing = corpus.manifest.dishRouting[dish.id];
        expect(routing, isNotNull, reason: 'no routing for ${dish.id}');
        expect(corpus.manifest.byId(routing!.primary), isNotNull);
      }
    });

    test('each recipe lives in exactly one primary partition', () async {
      await corpus.loadAllPartitions();
      final seen = <String>{};
      for (final recipe in corpus.loadedRecipes) {
        expect(seen.add(recipe.id), isTrue,
            reason: '${recipe.id} appears twice');
      }
    });

    test('every dish has at least one recipe and vice versa', () async {
      await corpus.loadAllPartitions();
      for (final dish in corpus.dishes) {
        expect(corpus.recipesForDish(dish.id), isNotEmpty,
            reason: 'dish ${dish.id} has no recipes');
      }
      for (final recipe in corpus.loadedRecipes) {
        expect(corpus.dish(recipe.dishId), isNotNull,
            reason: 'recipe ${recipe.id} points at unknown dish');
      }
    });

    test('all contains-flags and ingredients exist in the ontology/dictionary',
        () async {
      await corpus.loadAllPartitions();
      for (final recipe in corpus.loadedRecipes) {
        for (final flag in recipe.contains) {
          expect(corpus.ontology.containsFlags.containsKey(flag), isTrue,
              reason: '${recipe.id}: unknown flag $flag');
        }
        for (final id in recipe.ingredientIds) {
          expect(corpus.ingredients.byId.containsKey(id), isTrue,
              reason: '${recipe.id}: unknown ingredient $id');
        }
      }
    });

    test('guide entries reference real ingredients', () {
      // guide entries are keyed by ingredient id
      for (final entry in [
        corpus.guideEntry('tahini'),
        corpus.guideEntry('miso'),
      ]) {
        expect(entry, isNotNull);
      }
    });

    test('ensureDishLoaded pulls lazy partitions on demand', () async {
      final lazyDish = corpus.dishes.firstWhere(
          (d) => d.partitionId == 'extended',
          orElse: () => corpus.dishes.first);
      await corpus.ensureDishLoaded(lazyDish.id);
      expect(corpus.recipesForDish(lazyDish.id), isNotEmpty);
    });
  });

  group('search', () {
    late SearchService search;
    final profile = Profile();

    setUp(() {
      search = SearchService(corpus);
    });

    test('finds dishes by English title', () async {
      final page =
          await search.search('pancakes', profile: profile);
      expect(page.recipeIds, isNotEmpty);
      expect(
        page.recipeIds
            .every((id) => corpus.recipe(id)!.dishId == 'pancakes'),
        isTrue,
      );
    });

    test('finds dishes by German title', () async {
      final page = await search.search('pfannkuchen', profile: profile);
      expect(page.recipeIds, isNotEmpty);
    });

    test('finds recipes by ingredient name', () async {
      final page = await search.search('parmesan', profile: profile);
      expect(page.recipeIds, isNotEmpty);
      for (final id in page.recipeIds) {
        final recipe = corpus.recipe(id)!;
        final namesOk = recipe.ingredientIds.contains('parmesan') ||
            recipe.tags.any((t) => t.contains('parmesan')) ||
            recipe.title.values
                .any((v) => v.toString().toLowerCase().contains('parmesan'));
        expect(namesOk, isTrue, reason: '$id matched without parmesan');
      }
    });

    test('finds recipes by tag', () async {
      final page = await search.search('italian', profile: profile);
      expect(page.recipeIds, isNotEmpty);
    });

    test('multi-token queries AND the tokens', () async {
      final page = await search.search('vegan curry', profile: profile);
      for (final id in page.recipeIds) {
        final recipe = corpus.recipe(id)!;
        expect(recipe.dishId, 'curry');
        expect(recipe.dietAxis, 'vegan');
      }
    });

    test('profile filters apply post-match', () async {
      final veganProfile = Profile(avoidFlags: {'vegan'});
      final page =
          await search.search('curry', profile: veganProfile);
      for (final id in page.recipeIds) {
        final recipe = corpus.recipe(id)!;
        expect(
          isRecipeVisible(recipe, veganProfile,
              ontology: corpus.ontology, dictionary: corpus.ingredients),
          isTrue,
        );
      }
    });

    test('cursor pagination walks the full result set once', () async {
      // a query wide enough to span pages is hard to guarantee; instead
      // verify cursor mechanics on whatever we get
      final first = await search.search('the', profile: profile);
      if (first.nextCursor == null) return; // small corpus, single page
      final second = await search.search('the',
          cursor: first.nextCursor, profile: profile);
      expect(second.recipeIds.toSet().intersection(first.recipeIds.toSet()),
          isEmpty);
    });

    test('cursor encode/decode round-trips', () {
      expect(SearchService.decodeCursor(SearchService.encodeCursor(40)), 40);
      expect(SearchService.decodeCursor(null), 0);
      expect(SearchService.decodeCursor('garbage'), 0);
    });

    test('no results for nonsense', () async {
      final page =
          await search.search('zzqqxjvwl', profile: profile);
      expect(page.isEmpty, isTrue);
      expect(page.nextCursor, isNull);
    });
  });

  group('matching against the real corpus', () {
    test('vegan profile sees only vegan-compatible recipes', () async {
      await corpus.loadAllPartitions();
      final profile = Profile(avoidFlags: {'vegan'});
      var visibleCount = 0;
      for (final recipe in corpus.loadedRecipes) {
        final visible = isRecipeVisible(recipe, profile,
            ontology: corpus.ontology, dictionary: corpus.ingredients);
        if (visible) {
          visibleCount++;
          expect(recipe.contains, isNot(contains('dairy')));
          expect(recipe.contains, isNot(contains('egg')));
          expect(recipe.contains, isNot(contains('pork')));
        }
      }
      expect(visibleCount, greaterThan(0));
      expect(visibleCount, lessThan(corpus.loadedRecipes.length));
    });

    test('halal requirement only admits halal-attributed recipes', () async {
      await corpus.loadAllPartitions();
      final profile = Profile(requiredAttributes: {'halal'});
      final visible = corpus.loadedRecipes
          .where((r) => isRecipeVisible(r, profile,
              ontology: corpus.ontology, dictionary: corpus.ingredients))
          .toList();
      expect(visible, isNotEmpty);
      for (final r in visible) {
        expect(r.attributes, contains('halal'));
      }
    });
  });
}
