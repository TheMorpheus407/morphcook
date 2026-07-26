import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/backup_service.dart';
import 'package:morphcook/domain/collections.dart';
import 'package:morphcook/domain/profile.dart';
import 'package:morphcook/state/app_state.dart';

import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  final now = DateTime(2026, 7, 26, 12);

  setUp(() async => state = await buildAppState(now: now));

  group('initialisation', () {
    test('the corpus, ontology and services are wired up', () {
      expect(state.isReady, isTrue);
      expect(state.initError, isNull);
      expect(state.repository.dishes, isNotEmpty);
      expect(state.repository.ontology.containsFlags, isNotEmpty);
    });

    test('a fresh install has not completed onboarding', () {
      expect(state.profile.onboardingComplete, isFalse);
      expect(state.saved, isEmpty);
      expect(state.history, isEmpty);
      expect(state.plan.isEmpty, isTrue);
      expect(state.shopping, isEmpty);
    });
  });

  group('profile', () {
    test('a change persists and is readable back', () async {
      await state.updateProfile(
        state.profile.copyWith(name: 'Cedric', lang: 'de'),
      );
      expect(state.profileStore.load().name, 'Cedric');
      expect(state.lang, 'de');
    });

    test('completing onboarding sets the flag', () async {
      await state.completeOnboarding(const Profile(name: 'x'));
      expect(state.profile.onboardingComplete, isTrue);
    });

    test('an identical profile does not notify', () async {
      var notifications = 0;
      state.addListener(() => notifications++);
      await state.updateProfile(state.profile);
      expect(notifications, 0);
    });
  });

  group('preferredVariant', () {
    test('an unfiltered profile gets a variant of every core dish', () {
      for (final dish in state.repository.dishes) {
        expect(state.preferredVariant(dish.id), isNotNull, reason: dish.id);
      }
    });

    test('a vegan profile is served a vegan-compatible variant', () async {
      await state.updateProfile(const Profile(avoidFlags: {'vegan'}));
      final pick = state.preferredVariant('doener');
      expect(pick, isNotNull);
      expect(pick!.contains, isNot(contains('poultry')));
      expect(pick.contains, isNot(contains('dairy')));
    });

    test('a profile that excludes everything for a dish gets null', () async {
      // Nothing in the corpus is free of every single flag at once.
      final everyFlag = state.repository.ontology.containsFlags.keys.toSet();
      await state.updateProfile(Profile(avoidFlags: everyFlag));
      expect(state.preferredVariant('doener'), isNull);
    });

    test('the calorie override brings a variant back', () async {
      await state.updateProfile(
        const Profile(calorieTarget: 100, calorieTolerance: 10),
      );
      expect(state.preferredVariant('doener'), isNull);
      expect(
        state.preferredVariant('doener', ignoreCalorieTarget: true),
        isNotNull,
      );
    });
  });

  group('saved', () {
    test('toggling saves and unsaves the exact variant', () async {
      await state.toggleSaved('doener-vegan');
      expect(state.isSaved('doener-vegan'), isTrue);
      expect(state.isSaved('doener-classic'), isFalse);
      await state.toggleSaved('doener-vegan');
      expect(state.isSaved('doener-vegan'), isFalse);
    });

    test('two variants of the same dish can be saved side by side', () async {
      await state.toggleSaved('doener-vegan');
      await state.toggleSaved('doener-classic');
      expect(state.saved, hasLength(2));
    });

    test('sorting by name uses the current language', () async {
      await state.toggleSaved('alfredo-classic');
      await state.toggleSaved('doener-vegan');
      final byName = state.savedSorted(byName: true, lang: 'en');
      final titles = byName
          .map((e) => state.repository.recipe(e.recipeId)!.title('en'))
          .toList();
      expect(titles, orderedEquals(List.of(titles)..sort()));
    });

    test('the default sort is most recently saved first', () async {
      await state.toggleSaved('alfredo-classic');
      await state.toggleSaved('doener-vegan');
      expect(state.savedSorted().first.recipeId, 'doener-vegan');
    });
  });

  group('history and staleness', () {
    test('logging a cook records it and feeds lastCookedByRecipe', () async {
      await state.logCooked('ramen-vegan', servings: 3);
      expect(state.history.single.recipeId, 'ramen-vegan');
      expect(state.history.single.servings, 3);
      expect(state.lastCookedByRecipe['ramen-vegan'], now);
    });

    test('lastCookedByRecipe keeps the most recent of several', () async {
      state = await buildAppState(now: DateTime(2026, 1, 1));
      await state.logCooked('ramen-vegan', servings: 2);
      state = await buildAppState(now: now);
      await state.logCooked('ramen-vegan', servings: 2);
      expect(state.lastCookedByRecipe['ramen-vegan'], now);
    });
  });

  group('meal plan', () {
    test('assign, move and clear round-trip through the store', () async {
      const week = IsoWeek(2026, 30);
      const monday = PlanSlot('mon', 'dinner');
      const tuesday = PlanSlot('tue', 'lunch');

      await state.assignSlot(week, monday, 'chili-vegan');
      expect(state.plan.recipeAt(week, monday), 'chili-vegan');

      await state.moveSlot(week, monday, week, tuesday);
      expect(state.plan.recipeAt(week, monday), isNull);
      expect(state.plan.recipeAt(week, tuesday), 'chili-vegan');

      await state.clearSlot(week, tuesday);
      expect(state.plan.isEmpty, isTrue);
    });

    test('moving onto an occupied slot swaps the two', () async {
      const week = IsoWeek(2026, 30);
      const a = PlanSlot('mon', 'dinner');
      const b = PlanSlot('tue', 'dinner');
      await state.assignSlot(week, a, 'chili-vegan');
      await state.assignSlot(week, b, 'ramen-vegan');
      await state.moveSlot(week, a, week, b);
      expect(state.plan.recipeAt(week, b), 'chili-vegan');
      expect(state.plan.recipeAt(week, a), 'ramen-vegan');
    });
  });

  group('shopping list', () {
    test('adding a recipe expands and merges its ingredients', () async {
      await state.addRecipesToShoppingList(['doener-classic']);
      expect(state.shopping, isNotEmpty);
      final recipe = state.repository.recipe('doener-classic')!;
      final required = recipe.ingredients.where((i) => !i.optional).length;
      expect(state.shopping, hasLength(required));
    });

    test(
      'two recipes sharing an ingredient produce one merged entry',
      () async {
        await state.addRecipesToShoppingList([
          'doener-classic',
          'doener-halal',
        ]);
        final salt = state.shopping.where((e) => e.ingredientId == 'salt');
        expect(salt, hasLength(1));
      },
    );

    test('adding the same recipe twice does not double anything', () async {
      await state.addRecipesToShoppingList(['doener-classic']);
      final before = state.shopping
          .map((e) => (e.ingredientId, e.qty))
          .toList();
      await state.addRecipesToShoppingList(['doener-classic']);
      final after = state.shopping.map((e) => (e.ingredientId, e.qty)).toList();
      expect(after, orderedEquals(before));
    });

    test('checking and clearing behave', () async {
      await state.addRecipesToShoppingList(['doener-classic']);
      final id = state.shopping.first.ingredientId;
      await state.setShoppingChecked(id, true);
      expect(
        state.shopping.firstWhere((e) => e.ingredientId == id).checked,
        isTrue,
      );
      await state.clearCheckedShopping();
      expect(state.shopping.any((e) => e.ingredientId == id), isFalse);
    });

    test('a manual item lands on the list', () async {
      await state.addManualShoppingItem('garlic', 3, 'clove');
      expect(state.shopping.single.ingredientId, 'garlic');
      expect(state.shopping.single.manual, isTrue);
    });

    test('insights read the list', () async {
      await state.addRecipesToShoppingList(['doener-classic']);
      expect(state.insights.varietyScore, greaterThan(5));
      expect(state.insights.byMonth, hasLength(1));
    });
  });

  group('content requests', () {
    test('an empty search is recorded once and then counted', () async {
      await state.recordEmptySearch('sushi');
      await state.recordEmptySearch('Sushi');
      expect(state.contentRequests, hasLength(1));
      expect(state.contentRequests.single.count, 2);
    });

    test('blank queries are ignored', () async {
      await state.recordEmptySearch('   ');
      expect(state.contentRequests, isEmpty);
    });

    test('they can be forgotten', () async {
      await state.recordEmptySearch('sushi');
      await state.clearContentRequests();
      expect(state.contentRequests, isEmpty);
    });
  });

  group('search', () {
    test('a dish name finds its variants', () async {
      final outcome = await state.searchService.search(
        'doner',
        lang: 'en',
        context: state.matchContext(),
      );
      expect(outcome.hits, isNotEmpty);
      expect(outcome.hits.map((h) => h.recipe.dishId), contains('doener'));
    });

    test('an ingredient name finds recipes using it', () async {
      final outcome = await state.searchService.search(
        'tahini',
        lang: 'en',
        context: state.matchContext(),
      );
      expect(outcome.hits, isNotEmpty);
    });

    test('a German query works against the German index', () async {
      final outcome = await state.searchService.search(
        'kichererbsen',
        lang: 'de',
        context: state.matchContext(),
      );
      expect(outcome.hits, isNotEmpty);
    });

    test('hidden matches are counted, not silently dropped', () async {
      await state.updateProfile(const Profile(avoidFlags: {'vegan'}));
      final outcome = await state.searchService.search(
        'doner',
        lang: 'en',
        context: state.matchContext(),
      );
      expect(outcome.hiddenCount, greaterThan(0));
      expect(outcome.hits.every((h) => h.visible), isTrue);
    });

    test(
      'includeHidden brings them back, sorted after the visible ones',
      () async {
        await state.updateProfile(const Profile(avoidFlags: {'vegan'}));
        final outcome = await state.searchService.search(
          'doner',
          lang: 'en',
          context: state.matchContext(),
          includeHidden: true,
        );
        expect(outcome.hits.any((h) => !h.visible), isTrue);
        final firstHidden = outcome.hits.indexWhere((h) => !h.visible);
        final lastVisible = outcome.hits.lastIndexWhere((h) => h.visible);
        expect(firstHidden, greaterThan(lastVisible));
      },
    );

    test('a diet filter narrows to that axis', () async {
      final outcome = await state.searchService.search(
        '',
        lang: 'en',
        context: state.matchContext(),
        dietFilters: {'vegan'},
      );
      expect(outcome.hits, isNotEmpty);
      expect(
        outcome.hits.every((h) => h.recipe.axes['diet'] == 'vegan'),
        isTrue,
      );
    });

    test('nonsense finds nothing', () async {
      final outcome = await state.searchService.search(
        'qwertyuiop',
        lang: 'en',
        context: state.matchContext(),
      );
      expect(outcome.hits, isEmpty);
      expect(outcome.hiddenCount, 0);
    });
  });

  group('backup through AppState', () {
    test('export then import restores the same collections', () async {
      await state.updateProfile(
        state.profile.copyWith(name: 'Cedric', avoidFlags: {'vegan'}),
      );
      await state.toggleSaved('doener-vegan');
      await state.logCooked('ramen-vegan', servings: 2);
      await state.assignSlot(
        const IsoWeek(2026, 30),
        const PlanSlot('mon', 'dinner'),
        'chili-vegan',
      );
      await state.recordEmptySearch('sushi');

      final bundle = state.exportBackup();

      final fresh = await buildAppState(now: now);
      final document = fresh.readBackup(bundle.jsonBytes);
      await fresh.applyImportedBackup(document, ImportMode.replace);

      expect(fresh.profile.name, 'Cedric');
      expect(fresh.profile.avoidFlags, contains('vegan'));
      expect(fresh.isSaved('doener-vegan'), isTrue);
      expect(fresh.history.single.recipeId, 'ramen-vegan');
      expect(
        fresh.plan.recipeAt(
          const IsoWeek(2026, 30),
          const PlanSlot('mon', 'dinner'),
        ),
        'chili-vegan',
      );
      expect(fresh.contentRequests.single.query, 'sushi');
    });

    test('an encrypted export round-trips through AppState', () async {
      await state.toggleSaved('doener-vegan');
      final bundle = state.exportBackup(password: 'hunter2');
      final fresh = await buildAppState(now: now);
      final document = fresh.readEncryptedBackup(bundle.jsonBytes, 'hunter2');
      await fresh.applyImportedBackup(document, ImportMode.merge);
      expect(fresh.isSaved('doener-vegan'), isTrue);
    });

    test(
      'importing marks onboarding complete so the user lands in the app',
      () async {
        await state.completeOnboarding(const Profile(name: 'Cedric'));
        final bundle = state.exportBackup();
        final fresh = await buildAppState(now: now);
        await fresh.applyImportedBackup(
          fresh.readBackup(bundle.jsonBytes),
          ImportMode.replace,
        );
        expect(fresh.profile.onboardingComplete, isTrue);
      },
    );
  });

  group('reset', () {
    test('wipes user data but leaves the corpus alone', () async {
      await state.toggleSaved('doener-vegan');
      await state.addRecipesToShoppingList(['doener-classic']);
      await state.updateProfile(state.profile.copyWith(name: 'Cedric'));

      await state.resetEverything();

      expect(state.saved, isEmpty);
      expect(state.shopping, isEmpty);
      expect(state.profile.name, isEmpty);
      expect(state.repository.dishes, isNotEmpty);
      expect(state.repository.recipe('doener-vegan'), isNotNull);
    });
  });
}
