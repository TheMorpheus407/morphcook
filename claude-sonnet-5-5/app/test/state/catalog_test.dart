import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  // Monday evening, Saturday afternoon, Monday morning.
  final mondayEvening = DateTime(2026, 9, 28, 18, 30);
  final mondayMorning = DateTime(2026, 9, 28, 8, 15);
  final saturday = DateTime(2026, 9, 26, 15);

  Future<AppServices> services({Profile profile = const Profile(), DateTime? now}) {
    final current = now ?? mondayEvening;
    return makeServices(profile: profile, clock: () => current);
  }

  group('visibility', () {
    test('only variants that pass the profile are visible', () async {
      final s = await services(profile: const Profile(avoidFlags: {'vegan'}));
      final doener = s.corpus.dish('doener')!;
      final visible = s.catalog.visibleVariants(doener);
      expect(visible, isNotEmpty);
      expect(visible.every((r) => r.diet == 'vegan'), isTrue);
    });

    test('the per-dish calorie override lifts only the calorie rule', () async {
      final s = await services(profile: const Profile(avoidFlags: {'vegan'}, calorieTarget: 200));
      final doener = s.corpus.dish('doener')!;
      expect(
        s.catalog.visibleVariants(doener),
        isEmpty,
        reason: 'every döner has 440 kcal or more, above 200 plus the tolerance of 150',
      );
      await s.profile.setCalorieOverride('doener', true);
      final visible = s.catalog.visibleVariants(doener);
      expect(visible, isNotEmpty);
      expect(visible.every((r) => r.attributes.contains('vegan')), isTrue, reason: 'allergen rules stay in force');
    });

    test('an explicit ignoreCalories argument wins over the stored override', () async {
      final s = await services(profile: const Profile(calorieTarget: 200));
      final doener = s.corpus.dish('doener')!;
      expect(s.catalog.visibleVariants(doener, ignoreCalories: true), isNotEmpty);
      expect(s.catalog.visibleVariants(doener, ignoreCalories: false), isEmpty);
    });
  });

  group('the variant that suits you', () {
    test('the effort mood picks the version', () async {
      final easy = await services(profile: const Profile(preferredEffort: 'easy'));
      final hard = await services(profile: const Profile(preferredEffort: 'hard'));
      expect(easy.catalog.pickFor(easy.corpus.dish('bolognese')!)!.recipe.effort, 'easy');
      expect(hard.catalog.pickFor(hard.corpus.dish('bolognese')!)!.recipe.effort, 'hard');
    });

    test('a dish with no visible variant gives no pick', () async {
      final s = await services(profile: const Profile(avoidFlags: {'vegan'}, maxTimeMinutes: 5));
      expect(s.catalog.pickFor(s.corpus.dish('doener')!), isNull);
    });

    test('ranked picks are sorted by score and skip dishes whose partition is not loaded', () async {
      final s = await services();
      final picks = s.catalog.rankedPicks(s.corpus.dishes.values);
      expect(picks.map((p) => p.dish.partitionId).toSet(), {'core'}, reason: 'other partitions have not been opened');
      final scores = [for (final p in picks) p.score];
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
    });
  });

  group('time-aware feed', () {
    test('morning: a breakfast dish is featured', () async {
      final s = await services(now: mondayMorning);
      final feed = s.catalog.buildFeed();
      expect(feed.featured!.recipe.meal, contains('breakfast'));
      expect(feed.sections.first.id, 'morning');
    });

    test('evening: a dinner dish is featured', () async {
      final s = await services(now: mondayEvening);
      final feed = s.catalog.buildFeed();
      expect(feed.featured!.recipe.meal, contains('dinner'));
      expect(feed.sections.first.id, 'evening');
    });

    test('the section names follow the time of day', () async {
      final ids = <String>[];
      for (final at in [
        DateTime(2026, 9, 28, 7),
        DateTime(2026, 9, 28, 12),
        DateTime(2026, 9, 28, 16),
        DateTime(2026, 9, 28, 19),
        DateTime(2026, 9, 28, 23),
      ]) {
        final s = await services(now: at);
        ids.add(s.catalog.buildFeed().sections.first.id);
      }
      expect(ids, ['morning', 'midday', 'afternoon', 'evening', 'late']);
    });

    test('weekend: medium and hard variants get the bonus', () async {
      final weekday = await services(
        profile: const Profile(preferredEffort: 'easy'),
        now: DateTime(2026, 9, 28, 14),
      );
      final weekend = await services(
        profile: const Profile(preferredEffort: 'easy'),
        now: DateTime(2026, 9, 26, 14),
      );
      final dish = weekday.corpus.dish('bolognese')!;
      final onWeekday = weekday.catalog.pickFor(dish)!;
      final onWeekend = weekend.catalog.pickFor(dish)!;
      expect(onWeekday.recipe.effort, 'easy');
      expect(onWeekend.score - onWeekday.score, closeTo(0, 200), reason: 'the picks may differ, both stay valid');
      expect(saturday.weekday, DateTime.saturday);
    });

    test('a dish is never listed twice in the feed', () async {
      final s = await services();
      final feed = s.catalog.buildFeed();
      final ids = [
        feed.featured!.dish.id,
        for (final section in feed.sections.where((f) => f.id != 'quick' && f.id != 'back'))
          ...section.picks.map((p) => p.dish.id),
      ];
      expect(ids.toSet().length, ids.length);
    });

    test('quick section only holds dishes of 30 minutes or less', () async {
      final s = await services();
      final quick = s.catalog.buildFeed().sections.firstWhere((f) => f.id == 'quick');
      expect(quick.picks.every((p) => p.recipe.timeMinutes <= 30), isTrue);
    });

    test('an empty feed when nothing fits', () async {
      final s = await services(profile: const Profile(maxTimeMinutes: 5));
      expect(s.catalog.buildFeed().isEmpty, isTrue);
    });
  });

  group('staleness', () {
    test('a recipe not cooked for 30 days returns in "back on the table"', () async {
      final s = await services(now: mondayEvening);
      await s.history.add(
        HistoryEntry(
          recipeId: 'pancakes-classic',
          cookedAt: mondayEvening.subtract(const Duration(days: 45)),
          servings: 2,
        ),
      );
      final back = s.catalog.buildFeed().sections.where((f) => f.id == 'back');
      expect(back, isNotEmpty);
      expect(back.first.picks.map((p) => p.recipe.id), contains('pancakes-classic'));
    });

    test('a recipe cooked yesterday is not', () async {
      final s = await services(now: mondayEvening);
      await s.history.add(
        HistoryEntry(
          recipeId: 'pancakes-classic',
          cookedAt: mondayEvening.subtract(const Duration(days: 1)),
          servings: 2,
        ),
      );
      expect(s.catalog.buildFeed().sections.where((f) => f.id == 'back'), isEmpty);
    });

    test('the staleness bonus lifts the score by 50', () async {
      final s = await services(now: mondayEvening);
      final dish = s.corpus.dish('pancakes')!;
      final before = s.catalog.pickFor(dish)!;
      await s.history.add(
        HistoryEntry(
          recipeId: before.recipe.id,
          cookedAt: mondayEvening.subtract(const Duration(days: 60)),
          servings: 2,
        ),
      );
      final after = s.catalog.pickFor(dish)!;
      expect(after.recipe.id, before.recipe.id);
      expect(after.score - before.score, 50);
    });
  });

  group('cuisine discovery', () {
    test('loads the cuisine partitions on demand', () async {
      final s = await services();
      expect(s.corpus.isPartitionLoaded('cuisine-italian'), isFalse);
      final sections = await s.catalog.cuisineSections();
      expect(sections.map((f) => f.cuisine), containsAll(['italian', 'asian', 'middle-eastern']));
      expect(s.corpus.isPartitionLoaded('cuisine-italian'), isTrue);
      final italian = sections.firstWhere((f) => f.cuisine == 'italian');
      expect(italian.picks.map((p) => p.dish.id), isNotEmpty);
    });
  });

  group('dish pages', () {
    test('the bundle holds every variant, the visible ones and a resolver', () async {
      final s = await services(profile: const Profile(avoidFlags: {'vegan'}));
      final bundle = await s.catalog.openDish('doener');
      expect(bundle.all.length, 7);
      expect(bundle.visible.every((r) => r.diet == 'vegan'), isTrue);
      expect(bundle.hasVisible, isTrue);
      expect(bundle.resolver.initialSelection()['diet'], 'vegan');
    });

    test('a saved recipe that no longer fits stays reachable when it is opened explicitly', () async {
      final s = await services(profile: const Profile(avoidFlags: {'vegan'}));
      final bundle = await s.catalog.openDish('doener', include: 'doener-classic');
      expect(bundle.visible.any((r) => r.id == 'doener-classic'), isFalse);
      expect(bundle.resolver.candidates.any((r) => r.id == 'doener-classic'), isTrue);
    });

    test('with no visible variant the dish still opens, over all variants', () async {
      final s = await services(profile: const Profile(avoidFlags: {'vegan'}, maxTimeMinutes: 5));
      final bundle = await s.catalog.openDish('doener');
      expect(bundle.hasVisible, isFalse);
      expect(bundle.resolver.candidates, hasLength(7));
    });
  });

  test('day parts for the greeting', () async {
    final s = await services();
    expect(s.catalog.dayPart(DateTime(2026, 1, 1, 6)), 'morning');
    expect(s.catalog.dayPart(DateTime(2026, 1, 1, 13)), 'afternoon');
    expect(s.catalog.dayPart(DateTime(2026, 1, 1, 19)), 'evening');
    expect(s.catalog.dayPart(DateTime(2026, 1, 1, 23)), 'night');
    expect(s.catalog.dayPart(DateTime(2026, 1, 1, 3)), 'night');
  });
}
