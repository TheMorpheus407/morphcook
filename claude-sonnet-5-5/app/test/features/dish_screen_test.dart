import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/features/cook/cook_screen.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  final evening = DateTime(2026, 9, 28, 18, 30);

  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Jo'),
    String dish = 'doener',
    String? recipe,
    String ready = 'START COOKING',
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: evening);
    await pumpApp(
      tester,
      services,
      home: DishScreen(dishId: dish, initialRecipeId: recipe),
    );
    await pumpUntilFound(tester, find.text(ready));
    await settleAsync(tester, rounds: 6); // the kitchen reference loads right after the page
    return services;
  }

  Future<void> openRow(WidgetTester tester, String label) async {
    await tester.tap(find.textContaining('— ${label.toUpperCase()}'));
    await settle(tester);
  }

  /// The ingredient list sits below the fold and is built lazily: scroll to it.
  Future<void> showIngredients(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await settle(tester);
  }

  /// Ingredient lines are rich text (name plus an italic note).
  Finder rich(String text) => find.textContaining(text, findRichText: true);

  group('defaults come from the profile', () {
    testWidgets('a vegan profile lands on the vegan variant', (tester) async {
      await open(tester, profile: const Profile(avoidFlags: {'vegan'}));
      expect(find.text('vegan döner'), findsOneWidget);
    });

    testWidgets('the effort mood picks the version', (tester) async {
      await open(
        tester,
        dish: 'bolognese',
        profile: const Profile(preferredEffort: 'easy'),
      );
      expect(find.text('easy'), findsWidgets);
      expect(find.textContaining('35 MIN'), findsOneWidget);
    });

    testWidgets('a saved variant opens exactly as saved', (tester) async {
      await open(tester, recipe: 'doener-keto');
      expect(find.text('keto döner bowl'), findsOneWidget);
    });
  });

  group('per-dimension variant switchers', () {
    testWidgets('one row per dimension, collapsed to the current value', (tester) async {
      await open(tester);
      expect(find.textContaining('— DIET'), findsOneWidget);
      expect(find.textContaining('— EFFORT'), findsOneWidget);
      expect(find.textContaining('— CALORIE LEVEL'), findsOneWidget);
      // Collapsed: the alternatives are not shown yet.
      expect(find.text('halal'), findsNothing);
      expect(find.text('keto'), findsNothing);
    });

    testWidgets('the calorie row shows an approximate figure', (tester) async {
      await open(tester);
      expect(find.text('~740'), findsOneWidget);
    });

    testWidgets('tapping a row reveals the alternatives, tapping again hides them', (tester) async {
      await open(tester);
      await openRow(tester, 'diet');
      for (final diet in ['classic', 'vegan', 'halal', 'gluten-free', 'keto']) {
        expect(find.text(diet), findsWidgets, reason: diet);
      }
      await openRow(tester, 'diet');
      expect(find.text('gluten-free'), findsNothing);
    });

    testWidgets('switching happens in place and the title and ingredients follow', (tester) async {
      await open(tester);
      expect(find.text('classic döner kebab'), findsOneWidget);
      await openRow(tester, 'diet');
      await tester.tap(find.text('vegan').last);
      await settle(tester);
      expect(find.text('vegan döner'), findsOneWidget);
      expect(find.text('classic döner kebab'), findsNothing);
      await showIngredients(tester);
      expect(rich('oyster mushrooms, torn'), findsOneWidget);
      expect(rich('lamb shoulder'), findsNothing);
    });

    testWidgets('unreachable combinations are disabled with a note, not hidden', (tester) async {
      await open(tester);
      await openRow(tester, 'effort');
      await tester.tap(find.text('easy').last);
      await settle(tester);
      expect(find.text('weeknight döner pan'), findsOneWidget);
      await openRow(tester, 'diet');
      // vegan, halal, gluten-free and keto exist, but not at "easy" effort.
      for (final diet in ['vegan', 'halal', 'gluten-free', 'keto']) {
        expect(find.text(diet), findsWidgets, reason: '$diet stays visible');
      }
      // The first three notes are printed, the rest is one tap away.
      expect(find.text('no vegan × easy version yet'), findsOneWidget);
      expect(find.text('no halal × easy version yet'), findsOneWidget);
      expect(find.text('no gluten-free × easy version yet'), findsOneWidget);
    });

    testWidgets('tapping a disabled option explains why and changes nothing', (tester) async {
      await open(tester);
      await openRow(tester, 'effort');
      await tester.tap(find.text('easy').last);
      await settle(tester);
      await openRow(tester, 'diet');
      await tester.tap(find.text('keto').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('weeknight döner pan'), findsOneWidget);
      expect(find.text('no keto × easy version yet'), findsOneWidget, reason: 'shown in a snack bar');
    });

    testWidgets('the ingredients flash where the variant changed', (tester) async {
      await open(tester);
      await openRow(tester, 'diet');
      await tester.tap(find.text('vegan').last);
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Animate), findsWidgets, reason: 'highlight flash on the changed lines');
      await settle(tester, frames: 15);
    });

    testWidgets('with reduceMotion the flash is skipped', (tester) async {
      await open(tester, profile: const Profile(reduceMotion: true));
      await openRow(tester, 'diet');
      await tester.tap(find.text('vegan').last);
      await settle(tester);
      expect(find.text('vegan döner'), findsOneWidget, reason: 'the switch itself still works');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(Animate), findsNothing);
    });

    testWidgets('the row labels follow the language', (tester) async {
      await open(
        tester,
        profile: const Profile(lang: 'de'),
        ready: 'LOS KOCHEN',
      );
      expect(find.textContaining('— ERNÄHRUNG'), findsOneWidget);
      expect(find.textContaining('— AUFWAND'), findsOneWidget);
      expect(find.textContaining('— KALORIENSTUFE'), findsOneWidget);
      expect(find.text('klassischer döner kebab'), findsOneWidget);
    });
  });

  group('calorie target and the per-dish override', () {
    testWidgets('the switch is offered when a calorie target is set', (tester) async {
      await open(tester, profile: const Profile(calorieTarget: 200));
      expect(find.textContaining('show versions outside my ~200 kcal target'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('no switch without a calorie target', (tester) async {
      await open(tester);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('a variant outside the target says so, and the override lifts it for this dish only', (tester) async {
      final services = await open(tester, profile: const Profile(calorieTarget: 200));
      expect(find.text('this one sits outside your profile'), findsOneWidget);
      expect(find.text('outside your calorie target'), findsOneWidget);
      expect(services.profile.calorieOverrideFor('doener'), isFalse);
      await tester.tap(find.byType(Switch));
      await settle(tester);
      expect(services.profile.calorieOverrideFor('doener'), isTrue);
      expect(services.profile.calorieOverrideFor('pancakes'), isFalse);
      expect(
        find.text('this one sits outside your profile'),
        findsNothing,
        reason: 'no longer outside once the override is on',
      );
    });
  });

  group('outside the profile', () {
    testWidgets('a saved variant that no longer fits names what clashes, most specific first', (tester) async {
      await open(
        tester,
        profile: const Profile(avoidFlags: {'vegan'}),
        recipe: 'doener-classic',
      );
      expect(find.text('this one sits outside your profile'), findsOneWidget);
      expect(find.textContaining('contains'), findsWidgets);
      final note = tester.widget<Text>(find.textContaining('contains ').first).data!;
      expect(note, contains('lamb'));
      expect(note, isNot(contains('meat')), reason: 'the class flag is not repeated next to its specifics');
    });

    testWidgets('the note links to the help entry on recipe visibility', (tester) async {
      await open(
        tester,
        profile: const Profile(avoidFlags: {'vegan'}),
        recipe: 'doener-classic',
      );
      await tester.tap(find.textContaining('why am I seeing this'));
      await settle(tester, frames: 20);
      await pumpUntilFound(tester, find.byType(FaqScreen));
      expect(find.byType(FaqScreen), findsOneWidget);
    });
  });

  group('tabs', () {
    testWidgets('ingredients, method and macros', (tester) async {
      await open(tester, profile: const Profile(avoidFlags: {'vegan'}));
      await showIngredients(tester);
      expect(find.text('MARINADE'), findsOneWidget);
      await tester.tap(find.text('METHOD'));
      await settle(tester);
      expect(find.textContaining('Tear the mushrooms lengthwise'), findsOneWidget);
      await tester.tap(find.text('MACROS'));
      await settle(tester);
      expect(find.text('640'), findsWidgets);
      expect(find.textContaining('kcal per serving'), findsOneWidget);
    });

    testWidgets('the variant tags can be turned off', (tester) async {
      await open(tester, profile: const Profile(showVariantTags: false));
      expect(find.text('740 KCAL'), findsNothing);
    });
  });

  group('servings scaler', () {
    testWidgets('amounts follow the number of people', (tester) async {
      await open(tester, dish: 'pancakes', recipe: 'pancakes-classic');
      await showIngredients(tester);
      expect(find.text('2 people'), findsOneWidget);
      expect(find.text('150 g'), findsOneWidget);
      await tester.tap(find.byTooltip('more servings'));
      await tester.pump();
      await tester.tap(find.byTooltip('more servings'));
      await tester.pump();
      expect(find.text('4 people'), findsOneWidget);
      expect(find.text('300 g'), findsOneWidget);
      expect(find.text('150 g'), findsNothing);
      await tester.tap(find.byTooltip('fewer servings'));
      await tester.pump();
      expect(find.text('225 g'), findsOneWidget);
    });

    testWidgets('fractions read like a cook would say them', (tester) async {
      await open(tester, dish: 'pancakes', recipe: 'pancakes-classic');
      await showIngredients(tester);
      // 1 pinch of salt at 3 people is 1½ pinches.
      await tester.tap(find.byTooltip('more servings'));
      await tester.pump();
      expect(find.text('1½ pinches'), findsOneWidget);
    });
  });

  group('actions', () {
    testWidgets('saving stores the specific variant, not the dish', (tester) async {
      final services = await open(tester, recipe: 'doener-keto');
      await tester.tap(find.byTooltip('save to cookbook'));
      await settle(tester);
      expect(services.cookbook.isSaved('doener-keto'), isTrue);
      expect(services.cookbook.isSaved('doener-classic'), isFalse);
      await tester.tap(find.byTooltip('remove from cookbook'));
      await settle(tester);
      expect(services.cookbook.isSaved('doener-keto'), isFalse);
    });

    testWidgets('add to the shopping list keeps the chosen servings', (tester) async {
      final services = await open(tester, dish: 'pancakes', recipe: 'pancakes-classic');
      await showIngredients(tester);
      await tester.tap(find.byTooltip('more servings'));
      await tester.pump();
      await tester.tap(find.byTooltip('more servings'));
      await tester.pump();
      await tester.tap(find.byTooltip('add to shopping list'));
      await settle(tester);
      expect(services.shopping.sources.single.recipeId, 'pancakes-classic');
      expect(services.shopping.sources.single.servings, 4);
      expect(find.text('added to your list'), findsOneWidget);
      expect(find.text('view list'), findsOneWidget);
    });

    testWidgets('start cooking opens cook mode for this variant', (tester) async {
      await open(tester, recipe: 'doener-keto');
      await tester.tap(find.text('START COOKING'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(CookScreen));
      expect(find.byType(CookScreen), findsOneWidget);
    });

    testWidgets('plan puts the variant into a slot of the week', (tester) async {
      final services = await open(tester, recipe: 'doener-keto');
      await tester.tap(find.byTooltip('add to plan'));
      await settle(tester);
      expect(find.text('which day?'), findsOneWidget);
      await tester.tap(find.text('THU'));
      await tester.tap(find.text('lunch'));
      await tester.pump();
      await tester.tap(find.text('ADD TO PLAN'));
      await settle(tester);
      expect(services.mealPlan.recipeAt(WeekKey.fromDate(DateTime(2026, 10, 1)), 'thu.lunch'), 'doener-keto');
      expect(find.text('added to your plan'), findsOneWidget);
    });
  });

  group('kitchen reference', () {
    testWidgets('"learn more" explains an unfamiliar ingredient', (tester) async {
      await open(tester, profile: const Profile(avoidFlags: {'vegan'}));
      await showIngredients(tester);
      final button = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'learn more: tahini');
      await tester.scrollUntilVisible(button, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(button);
      await settle(tester);
      await pumpUntilFound(tester, find.textContaining('A smooth paste of ground toasted sesame seeds'));
      expect(find.text('tahini'), findsWidgets);
      expect(find.textContaining('Whisk with lemon juice'), findsOneWidget);
    });
  });
}
