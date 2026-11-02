import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/cook_mode_controller.dart';
import 'package:morphcook/src/models/localized_text.dart';
import 'package:morphcook/src/models/recipe.dart';
import 'package:morphcook/src/state/local_store.dart';

import 'support/fixtures.dart';

/// A recipe with four steps and a timer on the second one.
Recipe buildCookRecipe() {
  return Recipe(
    id: 'cook-recipe',
    dishId: 'dish',
    title: en('Cook'),
    heroText: en('hero'),
    capCaption: en('caption'),
    stripeColor: '#C4694D',
    ingredients: const <RecipeIngredient>[],
    steps: const <RecipeStep>[
      RecipeStep(instruction: L10nText(<String, String>{'en': 'one'})),
      RecipeStep(
        instruction: L10nText(<String, String>{'en': 'two'}),
        timerSeconds: 90,
      ),
      RecipeStep(instruction: L10nText(<String, String>{'en': 'three'})),
      RecipeStep(instruction: L10nText(<String, String>{'en': 'four'})),
    ],
    contains: const <String>{},
    attributes: const <String, List<String>>{},
    diet: 'classic',
    timeMinutes: 20,
    calories: 500,
    macros: const Nutrition(calories: 500, protein: 20, carbs: 50, fat: 15),
    servings: 4,
    tags: en('tag'),
    mealSlots: const <String>['dinner'],
    partitionId: 'core',
  );
}

void main() {
  group('steps', () {
    test('moves forward and backward', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      expect(controller.currentStep, 0);
      expect(controller.next(), isTrue);
      expect(controller.currentStep, 1);
      expect(controller.previous(), isTrue);
      expect(controller.currentStep, 0);
    });

    test('stops at the last step', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      for (var i = 0; i < 10; i++) {
        controller.next();
      }

      expect(controller.currentStep, 3);
      expect(controller.isLastStep, isTrue);
      expect(controller.next(), isFalse);
    });
  });

  group('quick tap', () {
    test('does nothing until it is switched on', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      expect(controller.quickNextTapEnabled, isFalse);
      expect(controller.handleQuickTap(), isFalse);
      expect(controller.currentStep, 0);
    });

    test('advances the step once switched on', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      )..quickNextTapEnabled = true;

      expect(controller.handleQuickTap(), isTrue);
      expect(controller.currentStep, 1);
    });

    test('is debounced so a double tap skips only one step', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      )..quickNextTapEnabled = true;

      expect(controller.handleQuickTap(), isTrue);
      expect(controller.handleQuickTap(), isFalse);
      expect(controller.currentStep, 1);
    });

    test('the debounce window is 300 milliseconds', () {
      expect(OneHandedCookModeController.quickTapDebounceMs, 300);
    });
  });

  group('servings', () {
    test('scaling changes the multiplier', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      expect(controller.servings, 4);
      expect(controller.servingScale, 1);

      controller.scaleServings(2);

      expect(controller.servings, 6);
      expect(controller.servingScale, 1.5);
    });

    test('scaling is clamped to a sane range', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      controller.scaleServings(-100);
      expect(controller.servings, 1);

      controller.scaleServings(100);
      expect(controller.servings, 24);
    });

    test('quantities scale with the servings', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      controller.setServings(8);

      expect(controller.scaledQuantity(100), 200);
    });
  });

  group('the timer', () {
    test('picks up the timer of the current step', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );

      expect(controller.hasTimer, isFalse);

      controller.next();

      expect(controller.hasTimer, isTrue);
      expect(controller.timerTotal, 90);
      expect(controller.timerRemaining, 90);
    });

    test('pausing and resuming keeps the remaining time', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );
      controller.next();

      controller.startTimer();
      expect(controller.timerRunning, isTrue);

      controller.pauseTimer();
      expect(controller.timerRunning, isFalse);
      expect(controller.timerRemaining, greaterThan(0));

      controller.resumeTimer();
      expect(controller.timerRunning, isTrue);
    });

    test('resetting puts the timer back to the start', () {
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: MemoryStore(),
      );
      controller.next();
      controller.startTimer();

      controller.resetTimer();

      expect(controller.timerRemaining, 90);
      expect(controller.timerRunning, isFalse);
    });
  });

  group('persistence', () {
    test('the progress is written on every change', () {
      final store = MemoryStore();
      final controller = OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: store,
      );

      controller.next();

      expect(store.contains('cook.progress'), isTrue);
      expect(store.readMap('cook.progress')['step'], 1);
    });

    test('a saved progress block is restored', () {
      final store = MemoryStore();
      OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: store,
        initialStep: 2,
        initialServings: 6,
      );

      final restored = OneHandedCookModeController.restore(store, 'cook-recipe');

      expect(restored?['step'], 2);
      expect(restored?['servings'], 6);
    });

    test('a block for another recipe is ignored', () {
      final store = MemoryStore();
      OneHandedCookModeController(
        recipe: buildCookRecipe(),
        store: store,
        initialStep: 2,
      );

      expect(
        OneHandedCookModeController.restore(store, 'another-recipe'),
        isNull,
      );
    });
  });
}
