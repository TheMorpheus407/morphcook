import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/cook/cook_controller.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/recipe.dart';

import 'helpers.dart';

Recipe timedRecipe() {
  final base = makeRecipe(id: 'cookable', servings: 2);
  return Recipe(
    id: base.id,
    dishId: base.dishId,
    title: base.title,
    caption: base.caption,
    intro: base.intro,
    variant: base.variant,
    contains: base.contains,
    attributes: base.attributes,
    meal: base.meal,
    timeMinutes: base.timeMinutes,
    servings: base.servings,
    caloriesPerServing: base.caloriesPerServing,
    macros: base.macros,
    ingredients: base.ingredients,
    steps: const [
      RecipeStep(text: LocalizedText({'en': 'prep', 'de': 'vorbereiten'})),
      RecipeStep(
          text: LocalizedText({'en': 'simmer', 'de': 'köcheln'}),
          timerMinutes: 1),
      RecipeStep(text: LocalizedText({'en': 'serve', 'de': 'servieren'})),
    ],
    tags: LocalizedList.empty,
  );
}

void main() {
  group('CookSessionController', () {
    test('navigates steps and persists progress', () {
      final saved = <CookProgress?>[];
      final session = CookSessionController(
          recipe: timedRecipe(), persist: saved.add);
      expect(session.stepIndex, 0);
      expect(session.remainingSeconds, isNull); // step 0 has no timer

      session.nextStep();
      expect(session.stepIndex, 1);
      expect(session.remainingSeconds, 60);
      expect(saved.last?.stepIndex, 1);

      session.previousStep();
      expect(session.stepIndex, 0);
      session.dispose();
    });

    test('timer counts down and flags completion for the flash alert', () {
      final session = CookSessionController(
          recipe: timedRecipe(), persist: (_) {});
      session.nextStep();
      session.startTimer();
      expect(session.isTimerRunning, isTrue);
      for (var i = 0; i < 59; i++) {
        session.tick();
      }
      expect(session.remainingSeconds, 1);
      expect(session.timerJustFinished, isFalse);
      session.tick();
      expect(session.remainingSeconds, 0);
      expect(session.isTimerRunning, isFalse);
      expect(session.timerJustFinished, isTrue);
      session.consumeTimerAlert();
      expect(session.timerJustFinished, isFalse);
      session.dispose();
    });

    test('pause/resume keeps remaining time and persists it', () {
      final saved = <CookProgress?>[];
      final session = CookSessionController(
          recipe: timedRecipe(), persist: saved.add);
      session.nextStep();
      session.startTimer();
      session.tick();
      session.tick();
      session.pauseTimer();
      expect(session.isTimerPaused, isTrue);
      expect(session.remainingSeconds, 58);
      expect(saved.last?.remainingTimerSeconds, 58);
      session.resumeTimer();
      expect(session.isTimerRunning, isTrue);
      session.dispose();
    });

    test('resumes a persisted session', () {
      final session = CookSessionController(
        recipe: timedRecipe(),
        persist: (_) {},
        resumeFrom: const CookProgress(
            recipeId: 'cookable',
            stepIndex: 1,
            servings: 4,
            remainingTimerSeconds: 30),
      );
      expect(session.stepIndex, 1);
      expect(session.servings, 4);
      expect(session.remainingSeconds, 30);
      expect(session.isTimerPaused, isTrue);
      session.dispose();
    });

    test('servings scaler clamps to 1..16 and scales factor', () {
      final session = CookSessionController(
          recipe: timedRecipe(), persist: (_) {});
      session.setServings(0);
      expect(session.servings, 2);
      session.setServings(4);
      expect(session.servings, 4);
      expect(session.scaleFactor, 2.0);
      session.setServings(17);
      expect(session.servings, 4);
      session.dispose();
    });

    test('completing clears persisted progress', () {
      final saved = <CookProgress?>[];
      final session = CookSessionController(
          recipe: timedRecipe(), persist: saved.add);
      session.nextStep();
      session.nextStep();
      expect(session.isLastStep, isTrue);
      final advanced = session.nextStep();
      expect(advanced, isFalse);
      expect(session.isCompleted, isTrue);
      expect(saved.last, isNull);
      session.dispose();
    });
  });

  group('OneHandedCookModeController', () {
    test('disabled by default — taps never advance', () {
      final controller = OneHandedCookModeController();
      expect(controller.handleTap(), isFalse);
    });

    test('debounces taps within 300 ms', () {
      var now = DateTime(2026, 1, 1, 12, 0, 0);
      final controller = OneHandedCookModeController(
          quickNextTapEnabled: true, now: () => now);
      expect(controller.handleTap(), isTrue);
      now = now.add(const Duration(milliseconds: 299));
      expect(controller.handleTap(), isFalse);
      now = now.add(const Duration(milliseconds: 2));
      expect(controller.handleTap(), isTrue);
    });
  });
}
