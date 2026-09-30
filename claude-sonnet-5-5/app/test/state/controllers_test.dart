import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/domain/shopping/aggregator.dart';
import 'package:morphcook/domain/shopping/insights.dart';
import 'package:morphcook/platform/platform_services.dart';
import 'package:morphcook/state/controllers/content_request_log.dart';
import 'package:morphcook/state/controllers/cookbook_controller.dart';
import 'package:morphcook/state/controllers/history_controller.dart';
import 'package:morphcook/state/controllers/meal_plan_controller.dart';
import 'package:morphcook/state/controllers/one_handed_cook_mode_controller.dart';
import 'package:morphcook/state/controllers/profile_controller.dart';
import 'package:morphcook/state/controllers/shopping_controller.dart';
import 'package:morphcook/state/storage/storage.dart';

import '../support/fixtures.dart';

void main() {
  late Corpus corpus;
  setUpAll(() async => corpus = await loadCorpus());

  group('ProfileController', () {
    ProfileController make(AppStorage storage, {Profile initial = const Profile()}) =>
        ProfileController(storage.prefs, ontology: corpus.ontology, ingredients: corpus.ingredients, initial: initial);

    test('starts with the initial profile, not onboarded', () {
      final c = make(AppStorage.memory(), initial: const Profile(lang: 'de'));
      expect(c.profile.lang, 'de');
      expect(c.lang, 'de');
      expect(c.onboarded, isFalse);
      expect(c.settings, const AppSettings());
    });

    test('a profile change is stored and read back by a new controller', () async {
      final storage = AppStorage.memory();
      final c = make(storage);
      await c.setProfile(const Profile(name: 'Sam', avoidFlags: {'dairy'}, calorieTarget: 500, maxTimeMinutes: 30));
      final again = make(storage);
      expect(again.profile.name, 'Sam');
      expect(again.profile.avoidFlags, {'dairy'});
      expect(again.profile.calorieTarget, 500);
      expect(again.profile.maxTimeMinutes, 30);
    });

    test('the profile is stored with the field names of the specification', () async {
      final storage = AppStorage.memory();
      await make(
        storage,
      ).setProfile(const Profile(avoidFlags: {'nuts'}, avoidIngredients: {'apples'}, maxTimeMinutes: 20));
      final raw = storage.prefs.getString(ProfileController.profileKey)!;
      for (final key in [
        'name',
        'lang',
        'avoid_flags',
        'avoid_ingredients',
        'required_attributes',
        'max_time_minutes',
        'calorie_target',
        'preferred_effort',
        'show_variant_tags',
        'reduceMotion',
      ]) {
        expect(raw, contains('"$key"'));
      }
    });

    test('listeners hear about changes, and the compiled filter follows', () async {
      final c = make(AppStorage.memory());
      var heard = 0;
      c.addListener(() => heard++);
      final before = c.filter;
      await c.updateProfile((p) => p.copyWith(avoidFlags: {'vegan'}));
      expect(heard, greaterThan(0));
      expect(identical(c.filter, before), isFalse);
      expect(c.filter.avoidFlags, contains('egg'));
    });

    test('setting an equal profile does nothing', () async {
      final c = make(AppStorage.memory());
      var heard = 0;
      c.addListener(() => heard++);
      await c.setProfile(c.profile);
      expect(heard, 0);
    });

    test('settings are separate from the profile', () async {
      final storage = AppStorage.memory();
      final c = make(storage);
      await c.updateSettings((s) => s.copyWith(visualAlertEnabled: false, quickNextTapEnabled: true));
      final again = make(storage);
      expect(again.settings.visualAlertEnabled, isFalse);
      expect(again.settings.quickNextTapEnabled, isTrue);
      expect(again.profile, const Profile());
    });

    test('onboarding is remembered', () async {
      final storage = AppStorage.memory();
      await make(storage).completeOnboarding(const Profile(name: 'Kim'));
      final again = make(storage);
      expect(again.onboarded, isTrue);
      expect(again.profile.name, 'Kim');
    });

    test('the calorie override is per dish and persists', () async {
      final storage = AppStorage.memory();
      final c = make(storage);
      expect(c.calorieOverrideFor('doener'), isFalse);
      await c.setCalorieOverride('doener', true);
      expect(c.calorieOverrideFor('doener'), isTrue);
      expect(c.calorieOverrideFor('pancakes'), isFalse);
      expect(make(storage).calorieOverrideFor('doener'), isTrue);
      await c.setCalorieOverride('doener', false);
      expect(make(storage).calorieOverrideFor('doener'), isFalse);
    });

    test('damaged stored data falls back to defaults instead of crashing', () async {
      final storage = AppStorage.memory();
      await storage.prefs.setString(ProfileController.profileKey, '{not json');
      await storage.prefs.setString(ProfileController.settingsKey, '[1,2');
      final c = make(storage, initial: const Profile(name: 'Fallback'));
      expect(c.profile.name, 'Fallback');
      expect(c.settings, const AppSettings());
    });

    test('resetAll returns to a fresh install and keeps the language', () async {
      final storage = AppStorage.memory();
      final c = make(storage);
      await c.completeOnboarding(const Profile(name: 'Sam', lang: 'de', avoidFlags: {'vegan'}));
      await c.setCalorieOverride('doener', true);
      await c.resetAll();
      expect(c.onboarded, isFalse);
      expect(c.profile.avoidFlags, isEmpty);
      expect(c.profile.lang, 'de');
      expect(c.calorieOverrideFor('doener'), isFalse);
      expect(make(storage).onboarded, isFalse);
    });

    test('reduceMotion is null (follow the system) until the person decides', () async {
      final c = make(AppStorage.memory());
      expect(c.profile.reduceMotion, isNull);
      await c.updateProfile((p) => p.copyWith(reduceMotion: true));
      expect(c.profile.reduceMotion, isTrue);
      await c.updateProfile((p) => p.copyWith(reduceMotion: null));
      expect(c.profile.reduceMotion, isNull);
    });
  });

  group('CookbookController', () {
    test('saves a specific variant, newest first', () async {
      final c = await CookbookController.open(AppStorage.memory());
      await c.save('doener-vegan', at: DateTime(2026, 9, 1));
      await c.save('doener-keto', at: DateTime(2026, 9, 2));
      expect(c.saved.map((s) => s.recipeId), ['doener-keto', 'doener-vegan']);
      expect(c.isSaved('doener-vegan'), isTrue);
      expect(c.isSaved('doener-classic'), isFalse, reason: 'you save your Döner, not the dish');
      expect(c.count, 2);
    });

    test('saving twice keeps one entry, toggle removes it', () async {
      final c = await CookbookController.open(AppStorage.memory());
      await c.save('a-1');
      await c.save('a-1');
      expect(c.count, 1);
      await c.toggle('a-1');
      expect(c.count, 0);
      await c.toggle('a-1');
      expect(c.count, 1);
    });

    test('survives a restart', () async {
      final storage = AppStorage.memory();
      final c = await CookbookController.open(storage);
      await c.save('x-1', at: DateTime(2026, 5, 5));
      final again = await CookbookController.open(storage);
      expect(again.saved.single.recipeId, 'x-1');
      expect(again.saved.single.savedAt, DateTime(2026, 5, 5));
    });

    test('offset pages: 30 at a time, with a total', () async {
      final c = await CookbookController.open(AppStorage.memory());
      for (var i = 0; i < 65; i++) {
        await c.save('r-$i', at: DateTime(2026, 1, 1).add(Duration(hours: i)));
      }
      final first = c.page(0, 30);
      expect(first.items, hasLength(30));
      expect(first.total, 65);
      expect(first.items.first.recipeId, 'r-64', reason: 'newest first');
      expect(c.page(60, 30).items, hasLength(5));
      expect(c.page(200, 30).items, isEmpty);
    });

    test('merge keeps local entries, replace swaps everything', () async {
      final c = await CookbookController.open(AppStorage.memory());
      await c.save('mine', at: DateTime(2026, 1, 1));
      await c.restore([
        SavedRecipe(recipeId: 'mine', savedAt: DateTime(2020)),
        SavedRecipe(recipeId: 'theirs', savedAt: DateTime(2026, 2, 1)),
      ], replace: false);
      expect(c.saved.map((s) => s.recipeId), unorderedEquals(['mine', 'theirs']));
      expect(
        c.saved.firstWhere((s) => s.recipeId == 'mine').savedAt,
        DateTime(2026, 1, 1),
        reason: 'never overwritten',
      );
      await c.restore([SavedRecipe(recipeId: 'only', savedAt: DateTime(2026, 3, 1))], replace: true);
      expect(c.saved.map((s) => s.recipeId), ['only']);
    });

    test('clear empties the cookbook', () async {
      final storage = AppStorage.memory();
      final c = await CookbookController.open(storage);
      await c.save('a-1');
      await c.clear();
      expect(c.count, 0);
      expect((await CookbookController.open(storage)).count, 0);
    });
  });

  group('HistoryController', () {
    HistoryEntry entry(String id, DateTime at) => HistoryEntry(recipeId: id, cookedAt: at, servings: 2);

    test('lists what was cooked, newest first, and remembers the last time per recipe', () async {
      final c = await HistoryController.open(AppStorage.memory());
      await c.add(entry('a-1', DateTime(2026, 8, 1)));
      await c.add(entry('a-1', DateTime(2026, 9, 1)));
      await c.add(entry('b-1', DateTime(2026, 8, 15)));
      expect(c.entries.map((e) => e.recipeId), ['a-1', 'b-1', 'a-1']);
      expect(c.lastCooked['a-1'], DateTime(2026, 9, 1));
      expect(c.lastCooked['b-1'], DateTime(2026, 8, 15));
    });

    test('the same entry is not added twice, and removing works', () async {
      final c = await HistoryController.open(AppStorage.memory());
      final e = entry('a-1', DateTime(2026, 8, 1));
      await c.add(e);
      await c.add(e);
      expect(c.count, 1);
      await c.remove(e);
      expect(c.count, 0);
    });

    test('week ordinals start on Monday', () {
      expect(weekOrdinal(DateTime(2026, 9, 28)), weekOrdinal(DateTime(2026, 10, 4)));
      expect(weekOrdinal(DateTime(2026, 10, 5)), weekOrdinal(DateTime(2026, 9, 28)) + 1);
    });

    test('time pages cover seven weeks each and say whether there is more', () async {
      final c = await HistoryController.open(AppStorage.memory());
      final now = DateTime(2026, 9, 30); // a Wednesday
      await c.add(entry('this-week', DateTime(2026, 9, 29)));
      await c.add(entry('six-weeks', now.subtract(const Duration(days: 41))));
      await c.add(entry('eight-weeks', now.subtract(const Duration(days: 56))));
      await c.add(entry('very-old', now.subtract(const Duration(days: 400))));
      final first = c.pageOfWeeks(0, 7, now);
      expect(first.items.map((e) => e.recipeId), ['this-week', 'six-weeks']);
      expect(first.hasMore, isTrue);
      final second = c.pageOfWeeks(1, 7, now);
      expect(second.items.map((e) => e.recipeId), ['eight-weeks']);
      expect(second.hasMore, isTrue);
      expect(c.pageOfWeeks(20, 7, now).hasMore, isFalse);
    });

    test('merge and replace on import', () async {
      final c = await HistoryController.open(AppStorage.memory());
      await c.add(entry('mine', DateTime(2026, 1, 1)));
      await c.restore([entry('mine', DateTime(2026, 1, 1)), entry('theirs', DateTime(2026, 2, 1))], replace: false);
      expect(c.count, 2);
      await c.restore([entry('only', DateTime(2026, 3, 1))], replace: true);
      expect(c.entries.map((e) => e.recipeId), ['only']);
    });

    test('survives a restart', () async {
      final storage = AppStorage.memory();
      await (await HistoryController.open(storage)).add(entry('a-1', DateTime(2026, 8, 1)));
      expect((await HistoryController.open(storage)).entries.single.recipeId, 'a-1');
    });
  });

  group('MealPlanController', () {
    final week = WeekKey.parse('2026-W40');

    test('assign, clear and move persist per week', () async {
      final storage = AppStorage.memory();
      final c = await MealPlanController.open(storage);
      await c.assign(week, 'mon.dinner', 'a-1');
      await c.assign(week, 'tue.lunch', 'b-1');
      await c.move(week, 'mon.dinner', week, 'wed.dinner');
      await c.clear(week, 'tue.lunch');
      final again = await MealPlanController.open(storage);
      expect(again.recipeAt(week, 'wed.dinner'), 'a-1');
      expect(again.recipeAt(week, 'mon.dinner'), isNull);
      expect(again.recipeAt(week, 'tue.lunch'), isNull);
    });

    test('an emptied week leaves no record behind', () async {
      final storage = AppStorage.memory();
      final c = await MealPlanController.open(storage);
      await c.assign(week, 'mon.dinner', 'a-1');
      await c.clear(week, 'mon.dinner');
      final box = await storage.records.open(Boxes.mealPlan);
      expect(box.length, 0);
    });

    test('the stored format is the backup format: week key, then slot to recipe id', () async {
      final storage = AppStorage.memory();
      await (await MealPlanController.open(storage)).assign(week, 'mon.dinner', 'recipe-id-3');
      final box = await storage.records.open(Boxes.mealPlan);
      expect(box.getJson('2026-W40'), {'mon.dinner': 'recipe-id-3'});
    });

    test('clearWeek removes every slot of one week only', () async {
      final c = await MealPlanController.open(AppStorage.memory());
      await c.assign(week, 'mon.dinner', 'a-1');
      await c.assign(week, 'sun.lunch', 'b-1');
      await c.assign(week.plusWeeks(1), 'mon.dinner', 'c-1');
      await c.clearWeek(week);
      expect(c.plan.slotsOf(week), isEmpty);
      expect(c.recipeAt(week.plusWeeks(1), 'mon.dinner'), 'c-1');
    });

    test('merge fills empty slots only, replace swaps the plan', () async {
      final c = await MealPlanController.open(AppStorage.memory());
      await c.assign(week, 'mon.dinner', 'mine');
      await c.restore(
        MealPlan().assign(week, 'mon.dinner', 'theirs').assign(week, 'tue.dinner', 'theirs-2'),
        replace: false,
      );
      expect(c.recipeAt(week, 'mon.dinner'), 'mine');
      expect(c.recipeAt(week, 'tue.dinner'), 'theirs-2');
      await c.restore(MealPlan().assign(week, 'fri.dinner', 'only'), replace: true);
      expect(c.plan.slotsOf(week), {'fri.dinner': 'only'});
    });

    test('records that are not weeks are ignored on load', () async {
      final storage = AppStorage.memory();
      final box = await storage.records.open(Boxes.mealPlan);
      await box.putJson('garbage', {'mon.dinner': 'x'});
      expect((await MealPlanController.open(storage)).plan.isEmpty, isTrue);
    });
  });

  group('ContentRequestLog', () {
    test('logs a search that found nothing', () async {
      final c = await ContentRequestLog.open(AppStorage.memory());
      await c.add('pad thai');
      await c.add('sushi');
      expect(c.queries, ['pad thai', 'sushi']);
    });

    test('the same query in another spelling is one entry', () async {
      final c = await ContentRequestLog.open(AppStorage.memory());
      await c.add('Pad  Thai');
      await c.add('pad thai');
      expect(c.count, 1);
    });

    test('a more specific query replaces the shorter one typed on the way', () async {
      final c = await ContentRequestLog.open(AppStorage.memory());
      await c.add('pad');
      await c.add('pad thai');
      expect(c.queries, ['pad thai']);
      await c.add('pad');
      expect(c.queries, ['pad thai'], reason: 'the longer request already covers it');
    });

    test('too short queries are ignored', () async {
      final c = await ContentRequestLog.open(AppStorage.memory());
      await c.add('a');
      await c.add('  ');
      expect(c.count, 0);
    });

    test('keeps at most 200, dropping the oldest', () async {
      final c = await ContentRequestLog.open(AppStorage.memory());
      for (var i = 0; i < 210; i++) {
        await c.add(
          'zz${String.fromCharCode(97 + i % 26)}${String.fromCharCode(97 + (i ~/ 26) % 26)}x$i',
          at: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        );
      }
      expect(c.count, ContentRequestLog.maxEntries);
    });

    test('survives a restart, and merges or replaces on import', () async {
      final storage = AppStorage.memory();
      final c = await ContentRequestLog.open(storage);
      await c.add('sushi');
      final again = await ContentRequestLog.open(storage);
      expect(again.queries, ['sushi']);
      await again.restore(['ramen bowl'], replace: false);
      expect(again.queries, unorderedEquals(['sushi', 'ramen bowl']));
      await again.restore(['tacos'], replace: true);
      expect(again.queries, ['tacos']);
    });
  });

  group('ShoppingController', () {
    Future<ShoppingController> open([AppStorage? storage]) =>
        ShoppingController.open(storage ?? AppStorage.memory(), corpus.ingredients);

    test('adding a recipe puts it on the list with its servings and logs every ingredient', () async {
      final c = await open();
      final recipe = (await corpus.loadRecipe('doener-vegan'))!;
      await c.addRecipe(recipe, at: DateTime(2026, 9, 1));
      expect(c.sources.single.recipeId, 'doener-vegan');
      expect(c.sources.single.servings, recipe.servings);
      expect(c.events, hasLength(recipe.ingredients.where((i) => corpus.ingredients.includeInShopping(i.id)).length));
      expect(c.events.first.recipeId, 'doener-vegan');
    });

    test('adding the same recipe again adds servings', () async {
      final c = await open();
      final recipe = (await corpus.loadRecipe('pancakes-vegan'))!;
      await c.addRecipe(recipe, servings: 2);
      await c.addRecipe(recipe, servings: 3);
      expect(c.sources.single.servings, 5);
    });

    test('servings can be changed within limits, and a recipe removed', () async {
      final c = await open();
      final recipe = (await corpus.loadRecipe('pancakes-vegan'))!;
      await c.addRecipe(recipe);
      await c.setServings(recipe.id, 100);
      expect(c.sources.single.servings, 24);
      await c.setServings(recipe.id, 0);
      expect(c.sources.single.servings, 0.5);
      await c.removeRecipe(recipe.id);
      expect(c.isEmpty, isTrue);
    });

    test('manual items are logged for the insights only when they name a dictionary ingredient', () async {
      final c = await open();
      await c.addManual(const ManualItem(id: 'm1', label: 'oat milk', ingredientId: 'oat-milk', amount: 1, unit: 'l'));
      await c.addManual(const ManualItem(id: 'm2', label: 'candles'));
      expect(c.manualItems, hasLength(2));
      expect(c.events.map((e) => e.ingredientId), ['oat-milk']);
    });

    test('ticking off, dismissing and clearing ticked lines', () async {
      final c = await open();
      await c.addManual(const ManualItem(id: 'm2', label: 'candles'));
      await c.toggleChecked('manual:m2');
      expect(c.isChecked('manual:m2'), isTrue);
      await c.toggleChecked('manual:m2');
      expect(c.isChecked('manual:m2'), isFalse);
      await c.toggleChecked('manual:m2');
      await c.toggleChecked('garlic');
      await c.clearChecked();
      expect(c.manualItems, isEmpty, reason: 'ticked manual lines are removed for good');
      expect(c.dismissed, contains('garlic'), reason: 'recipe lines are hidden');
      expect(c.checked, isEmpty);
    });

    test('a swiped-away ingredient comes back when a recipe with it is added', () async {
      final c = await open();
      await c.dismiss('garlic');
      expect(c.dismissed, contains('garlic'));
      await c.addRecipe((await corpus.loadRecipe('doener-vegan'))!);
      expect(c.dismissed, isNot(contains('garlic')));
    });

    test('a new list keeps the insights, clearing everything forgets them', () async {
      final c = await open();
      await c.addRecipe((await corpus.loadRecipe('pancakes-vegan'))!);
      await c.clearList();
      expect(c.isEmpty, isTrue);
      expect(c.events, isNotEmpty);
      await c.clearAll();
      expect(c.events, isEmpty);
      expect(c.insights.isEmpty, isTrue);
    });

    test('the insights follow the event log', () async {
      final c = await open();
      await c.addRecipe((await corpus.loadRecipe('pancakes-vegan'))!, at: DateTime(2026, 3, 1));
      await c.addRecipe((await corpus.loadRecipe('chili-vegan'))!, at: DateTime(2026, 7, 1));
      final insights = c.insights;
      expect(insights.varietyScore, greaterThan(10));
      expect(insights.months[2].count, greaterThan(0));
      expect(insights.months[6].count, greaterThan(0));
      expect(insights.months[0].count, 0);
    });

    test('everything survives a restart', () async {
      final storage = AppStorage.memory();
      final c = await open(storage);
      await c.addRecipe((await corpus.loadRecipe('pancakes-vegan'))!, servings: 4, at: DateTime(2026, 4, 4));
      await c.addManual(const ManualItem(id: 'm1', label: 'candles'));
      await c.toggleChecked('manual:m1');
      final again = await open(storage);
      expect(again.sources.single.servings, 4);
      expect(again.manualItems.single.label, 'candles');
      expect(again.isChecked('manual:m1'), isTrue);
      expect(again.events, isNotEmpty);
    });

    test('export and restore: merge adds, replace swaps', () async {
      final source = await open();
      await source.addRecipe((await corpus.loadRecipe('pancakes-vegan'))!, servings: 4, at: DateTime(2026, 4, 4));
      await source.addManual(const ManualItem(id: 'm1', label: 'candles'));
      final state = source.exportState();
      final events = source.events;

      final target = await open();
      await target.addRecipe((await corpus.loadRecipe('chili-vegan'))!);
      await target.restore(state, events, replace: false);
      expect(target.sources.map((s) => s.recipeId), unorderedEquals(['chili-vegan', 'pancakes-vegan']));
      expect(target.manualItems.single.label, 'candles');

      await target.restore(state, events, replace: true);
      expect(target.sources.map((s) => s.recipeId), ['pancakes-vegan']);
      expect(target.events.length, events.length);
    });

    test('restoring events twice does not double count', () async {
      final c = await open();
      final events = [ShoppingEvent(ingredientId: 'garlic', at: DateTime(2026, 5, 5))];
      await c.restore(null, events, replace: false);
      await c.restore(null, events, replace: false);
      expect(c.events, hasLength(1));
    });
  });

  group('OneHandedCookModeController (quick tap)', () {
    late ProfileController profile;
    late FakeHaptics haptics;
    var now = DateTime(2026, 9, 28, 12);
    var reduceMotion = false;

    OneHandedCookModeController make() {
      profile = ProfileController(
        AppStorage.memory().prefs,
        ontology: corpus.ontology,
        ingredients: corpus.ingredients,
      );
      haptics = FakeHaptics();
      now = DateTime(2026, 9, 28, 12);
      reduceMotion = false;
      return OneHandedCookModeController(
        profile: profile,
        haptics: haptics,
        reduceMotion: () => reduceMotion,
        clock: () => now,
      );
    }

    test('is opt-in: off by default, taps do nothing', () {
      final c = make();
      expect(c.quickNextTapEnabled, isFalse);
      var advanced = 0;
      expect(c.handleQuickTap(() => advanced++), isFalse);
      expect(advanced, 0);
      expect(haptics.taps, 0);
    });

    test('a single tap advances with haptic feedback once enabled', () async {
      final c = make();
      c.quickNextTapEnabled = true;
      await Future<void>.delayed(Duration.zero);
      expect(c.quickNextTapEnabled, isTrue);
      var advanced = 0;
      expect(c.handleQuickTap(() => advanced++), isTrue);
      expect(advanced, 1);
      expect(haptics.taps, 1);
    });

    test('taps within 300 ms are ignored (debounce), later ones count', () {
      final c = make();
      c.quickNextTapEnabled = true;
      var advanced = 0;
      c.handleQuickTap(() => advanced++);
      now = now.add(const Duration(milliseconds: 299));
      expect(c.handleQuickTap(() => advanced++), isFalse);
      expect(advanced, 1);
      now = now.add(const Duration(milliseconds: 2));
      expect(c.handleQuickTap(() => advanced++), isTrue);
      expect(advanced, 2);
      expect(haptics.taps, 2, reason: 'ignored taps give no feedback');
      expect(OneHandedCookModeController.debounce, const Duration(milliseconds: 300));
    });

    test('a rejected tap does not extend the debounce window', () {
      final c = make();
      c.quickNextTapEnabled = true;
      var advanced = 0;
      c.handleQuickTap(() => advanced++);
      now = now.add(const Duration(milliseconds: 200));
      c.handleQuickTap(() => advanced++);
      now = now.add(const Duration(milliseconds: 150));
      expect(c.handleQuickTap(() => advanced++), isTrue, reason: '350 ms after the last accepted tap');
    });

    test('respects reduceMotion by turning step changes into plain swaps', () {
      final c = make();
      expect(c.animateTransitions, isTrue);
      reduceMotion = true;
      expect(c.animateTransitions, isFalse);
    });

    test('the switch is stored with the device settings', () async {
      final c = make();
      c.quickNextTapEnabled = true;
      await Future<void>.delayed(Duration.zero);
      expect(profile.settings.quickNextTapEnabled, isTrue);
      c.quickNextTapEnabled = false;
      await Future<void>.delayed(Duration.zero);
      expect(profile.settings.quickNextTapEnabled, isFalse);
    });
  });
}
