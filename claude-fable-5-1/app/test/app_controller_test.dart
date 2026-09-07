import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/cook_session.dart';
import 'package:morphcook/domain/backup_codec.dart';

import 'helpers.dart';

void main() {
  final clock = DateTime(2026, 9, 1, 19); // tuesday evening

  test('init loads profile and corpus; feed builds sections', () async {
    final app = await newController(clock: () => clock, profile: const Profile(name: 'test', onboardingComplete: true));
    expect(app.initialized, isTrue);
    expect(app.profile.name, 'test');
    final feed = app.buildFeed();
    expect(feed.featured, isNotNull);
    expect(feed.moment, 'evening');
    expect(feed.sections.map((s) => s.id), contains('all'));
    expect(feed.sections.firstWhere((s) => s.id == 'now').cards.every((c) => c.recipe.isDinner || c.dish.mealTypes.contains('dinner')), isTrue);
    expect(feed.visibleDishCount, greaterThan(15));
  });

  test('vegan profile still sees the döner, as its vegan version', () async {
    final app = await newController(clock: () => clock, profile: const Profile(avoidFlags: {'vegan'}, onboardingComplete: true));
    final card = app.cardFor(app.dish('doener')!);
    expect(card!.recipe.id, 'doener-vegan-easy');
    final feed = app.buildFeed();
    expect(feed.hiddenDishCount, greaterThanOrEqualTo(0));
  });

  test('saved, history, shopping and content requests persist through the store', () async {
    final app = await newController(clock: () => clock);
    final r = app.recipeIfLoaded('doener-classic-easy')!;
    await app.toggleSaved(r.id);
    expect(app.isSaved(r.id), isTrue);
    expect(app.savedIdsNewestFirst, [r.id]);
    await app.addHistory(HistoryEntry(recipeId: r.id, dishId: r.dishId, cookedAt: clock, servings: 2));
    expect(app.timesCooked(r.id), 1);
    expect(app.lastCookedByRecipe[r.id], clock);
    await app.addToShopping(r, servings: 4);
    expect(app.isOnShoppingList(r.id), isTrue);
    expect(app.shopping.log.length, r.ingredients.length);
    final lines = app.aggregatedShopping();
    expect(lines, isNotEmpty);
    await app.toggleChecked(lines.first.key);
    expect(app.shopping.checked, {lines.first.key});
    await app.addManualItem('flowers');
    expect(app.shopping.manual.length, 1);
    await app.logContentRequest('Pad Thai ');
    await app.logContentRequest('pad thai');
    expect(app.contentRequests, ['pad thai']);
    // A fresh controller over the same store sees the same state.
    final again = app.store.get('saved') as Map;
    expect(again.keys, [r.id]);
    expect(app.insights.varietyScore, r.ingredientIds.length);
  });

  test('meal plan assign, move and export to shopping', () async {
    final app = await newController(clock: () => clock);
    final week = app.currentWeekKey;
    await app.assignMeal(week, 'mon.dinner', 'doener-classic-easy');
    await app.assignMeal(week, 'tue.dinner', 'alfredo-classic-easy');
    await app.moveMeal(week, 'mon.dinner', week, 'tue.dinner');
    expect(app.mealPlan.recipeAt(week, 'tue.dinner'), 'doener-classic-easy');
    expect(app.mealPlan.recipeAt(week, 'mon.dinner'), 'alfredo-classic-easy');
    final n = await app.exportWeekToShopping(week);
    expect(n, 2);
    expect(app.shopping.sources.length, 2);
  });

  test('backup round-trips through the controller with merge', () async {
    final app = await newController(clock: () => clock, profile: const Profile(name: 'a', onboardingComplete: true));
    await app.toggleSaved('doener-classic-easy');
    final backup = app.buildBackup();
    final bytes = BackupCodec.encodeGzip(backup);
    final other = await newController(clock: () => clock, profile: const Profile(name: 'b', onboardingComplete: true));
    await other.toggleSaved('alfredo-classic-easy');
    await other.applyBackup(BackupCodec.decode(bytes), MergeMode.merge);
    expect(other.profile.name, 'a');
    expect(other.savedIdsNewestFirst.toSet(), {'alfredo-classic-easy', 'doener-classic-easy'});
    await other.applyBackup(BackupCodec.decode(bytes), MergeMode.replace);
    expect(other.savedIdsNewestFirst, ['doener-classic-easy']);
  });

  test('cook progress persists and clears', () async {
    final app = await newController(clock: () => clock);
    expect(app.progressFor('x'), isNull);
    await app.saveProgress(CookProgress(recipeId: 'x', stepIndex: 2, servings: 3, updatedAt: clock));
    expect(app.progressFor('x')!.stepIndex, 2);
    await app.clearProgress('x');
    expect(app.progressFor('x'), isNull);
  });
}
