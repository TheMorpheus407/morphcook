import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/feed.dart';
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/logic/variant_selector.dart';
import 'package:morphcook/models/profile.dart';

import 'support.dart';

void main() {
  final c = Corpus.instance;
  // 2026-09-22 is a Tuesday; 2026-09-26 a Saturday.
  final tueMorning = DateTime(2026, 9, 22, 8);
  final tueEvening = DateTime(2026, 9, 22, 19);
  final tueAfternoon = DateTime(2026, 9, 22, 14);
  final satAfternoon = DateTime(2026, 9, 26, 14);

  group('time-aware ranking', () {
    test('morning: breakfast +200', () {
      expect(timeContextBonus(c.r('pancakes-classic'), tueMorning), 200);
      expect(timeContextBonus(c.r('chili-weeknight'), tueMorning), 0);
    });

    test('evening: dinner +90', () {
      expect(timeContextBonus(c.r('chili-weeknight'), tueEvening), 90);
      expect(timeContextBonus(c.r('pancakes-classic'), tueEvening), 0);
    });

    test('weekend: medium & hard effort +90', () {
      expect(timeContextBonus(c.r('chili-classic'), satAfternoon), 90); // medium
      expect(timeContextBonus(c.r('chili-slow'), satAfternoon), 90); // hard
      expect(timeContextBonus(c.r('chili-weeknight'), satAfternoon), 0); // easy
      expect(timeContextBonus(c.r('chili-classic'), tueAfternoon), 0);
    });

    test('bonus windows are half-open (5–11, 17–21)', () {
      final r = c.r('pancakes-classic');
      expect(timeContextBonus(r, DateTime(2026, 9, 22, 4, 59)), 0);
      expect(timeContextBonus(r, DateTime(2026, 9, 22, 5)), 200);
      expect(timeContextBonus(r, DateTime(2026, 9, 22, 11)), 0);
      final d = c.r('chili-weeknight');
      expect(timeContextBonus(d, DateTime(2026, 9, 22, 17)), 90);
      expect(timeContextBonus(d, DateTime(2026, 9, 22, 21)), 0);
    });
  });

  group('staleness', () {
    final now = DateTime(2026, 9, 22);
    test('30+ days since last cooked → +50', () {
      expect(stalenessBonus(now.subtract(const Duration(days: 30)), now), 50);
      expect(stalenessBonus(now.subtract(const Duration(days: 90)), now), 50);
    });
    test('recently cooked or never cooked → 0', () {
      expect(stalenessBonus(now.subtract(const Duration(days: 29)), now), 0);
      expect(stalenessBonus(null, now), 0);
    });
    test('bonuses stack on top of the base score', () {
      final r = c.r('pancakes-classic');
      const p = Profile();
      final base = baseScore(r, p);
      expect(rankScore(r, p, tueMorning, lastCooked: DateTime(2026, 7, 1)), base + 200 + 50);
    });
  });

  group('dimension rows', () {
    List<DimensionRow> rows(String selected, Profile p, {bool ignoreCalories = false}) {
      final recipe = c.r(selected);
      return computeDimensionRows(
        recipes: c.variants(recipe.dishId),
        selected: recipe,
        ontology: c.ontology,
        profile: p,
        ctx: c.ctx(p),
        ignoreCalories: ignoreCalories,
      );
    }

    DimensionOption opt(List<DimensionRow> rs, String dim, String value) =>
        rs.firstWhere((r) => r.def.id == dim).options.firstWhere((o) => o.value == value);

    test('one row per ontology dimension, current value shown', () {
      final rs = rows('doener-classic', const Profile());
      expect(rs.map((r) => r.def.id), ['diet', 'effort', 'calorie_level']);
      expect(rs[0].current, 'classic');
      expect(rs[1].current, 'medium');
      expect(rs[2].current, '<=800');
    });

    test('diet chips switch to the matching recipe', () {
      final rs = rows('doener-classic', const Profile());
      expect(opt(rs, 'diet', 'vegan').state, OptionState.available);
      expect(opt(rs, 'diet', 'vegan').targetId, 'doener-vegan');
      expect(opt(rs, 'diet', 'keto').targetId, 'doener-keto-bowl');
    });

    test('unreachable combinations are disabled, not hidden', () {
      // vegan döner is medium; there is no vegan × easy döner
      final rs = rows('doener-vegan', const Profile());
      final easy = opt(rs, 'effort', 'easy');
      expect(easy.state, OptionState.unwritten);
      expect(easy.fixed, ['vegan']);
    });

    test('profile-blocked variants are disabled with a reason', () {
      const p = Profile(avoidFlags: {'vegan'});
      final rs = rows('doener-vegan', p);
      final classic = opt(rs, 'diet', 'classic');
      expect(classic.state, OptionState.blocked);
      expect(classic.block!.reasons, contains(BlockReason.avoidedFlag));
    });

    test('lower rows narrow to the chosen upper values', () {
      // classic pad thai exists as medium and easy
      final rs = rows('pad-thai-classic', const Profile());
      expect(opt(rs, 'effort', 'easy').targetId, 'pad-thai-weeknight');
      final vegan = rows('pad-thai-vegan', const Profile());
      expect(opt(vegan, 'effort', 'easy').state, OptionState.unwritten);
    });

    test('calorie level switches within the same diet × effort', () {
      final rs = rows('alfredo-classic', const Profile());
      expect(opt(rs, 'calorie_level', '<=600').targetId, 'alfredo-light');
    });

    test('calorie-blocked variant becomes available with the override', () {
      const p = Profile(calorieTarget: 500, calorieTolerance: 150);
      final blocked = rows('alfredo-light', p);
      expect(opt(blocked, 'calorie_level', '<=800').state, OptionState.blocked);
      expect(opt(blocked, 'calorie_level', '<=800').block!.onlyCalories, isTrue);
      final lifted = rows('alfredo-light', p, ignoreCalories: true);
      expect(opt(lifted, 'calorie_level', '<=800').state, OptionState.available);
    });
  });

  group('home feed', () {
    Feed feed(Profile p, DateTime now, {Map<String, DateTime> cooked = const {}, List<String> saved = const []}) =>
        buildFeed(
          dishes: c.dishes.values,
          variantsOf: c.variants,
          recipeById: (id) => c.recipes[id],
          profile: p,
          ctx: c.ctx(p),
          now: now,
          lastCooked: cooked,
          savedNewestFirst: saved,
          calorieOverride: (_) => false,
          lang: 'en',
        );

    test('one variant per dish, all visible for the profile', () {
      const p = Profile(avoidFlags: {'vegan'});
      final f = feed(p, tueAfternoon);
      final ids = f.all.map((i) => i.dish.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final i in f.all) {
        expect(isVisible(i.recipe, c.ctx(p)), isTrue);
      }
      expect(f.all.firstWhere((i) => i.dish.id == 'doener').recipe.id, 'doener-vegan');
    });

    test('mornings surface breakfast in "right now"', () {
      final f = feed(const Profile(), tueMorning);
      expect(f.now, isNotEmpty);
      expect(f.now.every((i) => i.recipe.mealTypes.contains('breakfast')), isTrue);
    });

    test('rediscover lists recipes cooked 30+ days ago', () {
      final f = feed(
        const Profile(),
        tueAfternoon,
        cooked: {'risotto-classic': DateTime(2026, 7, 1), 'chili-classic': DateTime(2026, 9, 20)},
      );
      expect(f.rediscover.map((i) => i.recipe.id), ['risotto-classic']);
    });

    test('empty when nothing fits', () {
      const p = Profile(maxTimeMinutes: 5);
      expect(feed(p, tueAfternoon).isEmpty, isTrue);
    });
  });
}
