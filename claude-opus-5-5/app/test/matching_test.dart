import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';

import 'support.dart';

Recipe fake({
  String id = 'x',
  Set<String> contains = const {},
  List<String> ingredientIds = const [],
  Set<String> attributes = const {},
  int time = 30,
  int kcal = 500,
  String effort = 'easy',
  String diet = 'classic',
}) => Recipe(
  id: id,
  dishId: 'd',
  title: LText.empty,
  blurb: LText.empty,
  note: LText.empty,
  cuisine: 'x',
  diet: diet,
  effort: effort,
  timeMinutes: time,
  timeBucket: '',
  servings: 2,
  calories: kcal,
  calorieBucket: '',
  protein: 0,
  carbs: 0,
  fat: 0,
  contains: contains,
  attributes: attributes,
  techniques: const [],
  mealTypes: const [],
  tags: const [],
  dimensions: {'diet': diet, 'effort': effort},
  ingredientIds: ingredientIds,
  ingredients: const [],
  steps: const [],
);

void main() {
  final c = Corpus.instance;

  group('ontology expansion', () {
    test('vegan expands to all animal-derived flags and their children', () {
      final flags = c.ontology.expandAvoidFlags({'vegan'});
      expect(
        flags,
        containsAll([
          'meat',
          'pork',
          'beef',
          'lamb',
          'poultry',
          'fish',
          'shellfish',
          'molluscs',
          'egg',
          'dairy',
          'lactose',
          'honey',
          'gelatin-non-halal',
        ]),
      );
      expect(flags, isNot(contains('gluten')));
    });

    test('halal = pork + alcohol + non-halal gelatin', () {
      expect(c.ontology.expandAvoidFlags({'halal'}), {'pork', 'alcohol', 'gelatin-non-halal'});
    });

    test('kosher includes the meat-dairy combination', () {
      expect(c.ontology.expandAvoidFlags({'kosher'}), containsAll(['pork', 'shellfish', 'meat-dairy-combo']));
    });

    test('tree-nuts class covers specific nuts', () {
      expect(c.ontology.expandAvoidFlags({'tree-nuts'}), containsAll(['almonds', 'walnuts', 'cashews']));
    });

    test('lactose-free is a subset of dairy', () {
      expect(c.ontology.expandAvoidFlags({'lactose-free'}), {'lactose'});
    });
  });

  group('visible()', () {
    test('open profile sees everything', () {
      for (final r in c.recipes.values) {
        expect(isVisible(r, MatchContext.open), isTrue, reason: r.id);
      }
    });

    test('vegan sees the vegan döner, not the classic', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'vegan'}));
      expect(isVisible(c.r('doener-vegan'), ctx), isTrue);
      expect(isVisible(c.r('doener-classic'), ctx), isFalse);
      expect(evaluate(c.r('doener-classic'), ctx).reasons, [BlockReason.avoidedFlag]);
      expect(evaluate(c.r('doener-classic'), ctx).flags, containsAll(['beef', 'dairy']));
    });

    test('every vegan-visible recipe is free of animal flags', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'vegan'}));
      final animal = c.ontology.expandAvoidFlags({'vegan'});
      for (final r in c.recipes.values.where((r) => isVisible(r, ctx))) {
        expect(r.contains.intersection(animal), isEmpty, reason: r.id);
      }
    });

    test('specific avoidance: apples hides the apple oats only', () {
      final ctx = c.ctx(const Profile(avoidIngredients: {'apples'}));
      expect(isVisible(c.r('oats-classic'), ctx), isFalse);
      expect(evaluate(c.r('oats-classic'), ctx).reasons, [BlockReason.avoidedIngredient]);
      expect(evaluate(c.r('oats-classic'), ctx).ingredients, {'apple'});
      expect(isVisible(c.r('oats-vegan'), ctx), isTrue);
    });

    test('specific avoidance propagates to descendants (cheese → parmesan)', () {
      final ctx = c.ctx(const Profile(avoidIngredients: {'cheese'}));
      expect(isVisible(c.r('alfredo-classic'), ctx), isFalse);
      expect(isVisible(c.r('alfredo-vegan'), ctx), isTrue);
    });

    test('class and specific avoidance combine; any match excludes', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'gluten'}, avoidIngredients: {'cilantro'}));
      expect(isVisible(c.r('alfredo-gluten-free'), ctx), isTrue);
      expect(isVisible(c.r('alfredo-classic'), ctx), isFalse); // gluten
      expect(isVisible(c.r('falafel-gluten-free'), ctx), isFalse); // cilantro
    });

    test('required attributes must be a subset', () {
      final ctx = c.ctx(const Profile(requiredAttributes: {'high-protein'}));
      expect(isVisible(c.r('pancakes-protein'), ctx), isTrue);
      expect(isVisible(c.r('pancakes-classic'), ctx), isFalse);
      expect(evaluate(c.r('pancakes-classic'), ctx).missingAttributes, {'high-protein'});
    });

    test('time budget is a hard filter', () {
      final ctx = c.ctx(const Profile(maxTimeMinutes: 30));
      expect(isVisible(c.r('chili-weeknight'), ctx), isTrue);
      expect(isVisible(c.r('chili-classic'), ctx), isFalse);
      expect(evaluate(c.r('chili-classic'), ctx).reasons, [BlockReason.overTime]);
    });

    test('calorie target with tolerance, and the override', () {
      final ctx = c.ctx(const Profile(calorieTarget: 500, calorieTolerance: 100));
      expect(isVisible(fake(kcal: 600), ctx), isTrue);
      expect(isVisible(fake(kcal: 400), ctx), isTrue);
      expect(isVisible(fake(kcal: 601), ctx), isFalse);
      expect(isVisible(fake(kcal: 399), ctx), isFalse);
      expect(evaluate(fake(kcal: 900), ctx).onlyCalories, isTrue);
      expect(isVisible(fake(kcal: 900), ctx, ignoreCalories: true), isTrue);
    });

    test('halal hides pork and alcohol, keeps the alcohol-free risotto', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'halal'}));
      expect(isVisible(c.r('bolognese-classic'), ctx), isFalse);
      expect(isVisible(c.r('risotto-classic'), ctx), isFalse);
      expect(isVisible(c.r('risotto-alcohol-free'), ctx), isTrue);
      expect(isVisible(c.r('schnitzel-chicken'), ctx), isTrue);
      expect(isVisible(c.r('schnitzel-classic'), ctx), isFalse);
    });

    test('kosher hides meat with dairy', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'kosher'}));
      expect(isVisible(c.r('doener-classic'), ctx), isFalse);
      expect(isVisible(c.r('doener-vegan'), ctx), isTrue);
      expect(isVisible(c.r('chili-slow'), ctx), isTrue); // beef without dairy
    });

    test('lactose-free keeps aged-cheese-only dishes', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'lactose-free'}));
      expect(isVisible(c.r('alfredo-classic'), ctx), isFalse); // butter & cream
      expect(isVisible(c.r('caesar-classic'), ctx), isTrue); // parmesan only
    });

    test('nut allergy via tree-nuts class hides almond recipes', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'tree-nuts'}));
      expect(isVisible(c.r('oats-vegan'), ctx), isFalse);
      expect(isVisible(c.r('brownies-sugar-free'), ctx), isFalse);
      expect(isVisible(c.r('oats-gluten-free'), ctx), isTrue);
    });

    test('pure set logic on synthetic recipes', () {
      final ctx = c.ctx(const Profile(avoidFlags: {'dairy'}));
      expect(isVisible(fake(contains: {'dairy', 'lactose'}), ctx), isFalse);
      expect(isVisible(fake(contains: {'lactose'}), ctx), isFalse, reason: 'lactose is a child of dairy');
      expect(isVisible(fake(contains: {'gluten'}), ctx), isTrue);
    });
  });

  group('variant ranking', () {
    test('required attribute matches rank first', () {
      const p = Profile(requiredAttributes: {'high-protein'}, preferredEffort: 'hard');
      final a = fake(id: 'a', attributes: {'high-protein'}, effort: 'easy');
      final b = fake(id: 'b', effort: 'hard');
      expect(rankVariants([b, a], p).first.id, 'a');
    });

    test('then effort match, then time closeness, then calorie closeness', () {
      const p = Profile(preferredEffort: 'medium', maxTimeMinutes: 45, calorieTarget: 600);
      final easy = fake(id: 'easy', effort: 'easy');
      final medium = fake(id: 'medium', effort: 'medium');
      expect(rankVariants([easy, medium], p).first.id, 'medium');
      final far = fake(id: 'far', effort: 'medium', time: 10);
      final near = fake(id: 'near', effort: 'medium', time: 40);
      expect(rankVariants([far, near], p).first.id, 'near');
      final cal1 = fake(id: 'c1', effort: 'medium', time: 40, kcal: 300);
      final cal2 = fake(id: 'c2', effort: 'medium', time: 40, kcal: 580);
      expect(rankVariants([cal1, cal2], p).first.id, 'c2');
    });

    test('ties keep the authored order (classic first)', () {
      final ranked = rankVariants(c.variants('alfredo').where((r) => r.effort == 'easy'), const Profile());
      expect(ranked.first.id, 'alfredo-classic');
    });

    test('best visible variant per profile', () {
      expect(
        bestVisibleVariant(
          c.variants('doener'),
          const Profile(avoidFlags: {'vegan'}),
          c.ctx(const Profile(avoidFlags: {'vegan'})),
        )!.id,
        'doener-vegan',
      );
      const halal = Profile(avoidFlags: {'halal'}, preferredEffort: 'easy');
      expect(bestVisibleVariant(c.variants('bolognese'), halal, c.ctx(halal))!.id, 'bolognese-weeknight');
      const none = Profile(avoidFlags: {'vegan'}, maxTimeMinutes: 15);
      expect(bestVisibleVariant(c.variants('chili'), none, c.ctx(none)), isNull);
    });
  });
}
