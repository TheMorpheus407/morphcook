import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/model/localized.dart';
import 'package:morphcook/core/model/recipe.dart';
import 'package:morphcook/state/cook_controller.dart';
import 'package:morphcook/state/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cook mode: navigation, servings scaler, per-step timer, pause/resume with
/// progress persistence, and the opt-in one-handed quick-tap gesture.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('morphcook_cook_test_');
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await AppStorage.resetForTest();
    await AppStorage.initForTest(tempDir.path);
  });

  Recipe recipeWithSteps(int steps, {int? timerMinutes, int servings = 2}) => Recipe(
        id: 'r',
        dishId: 'd',
        title: const LocalizedText({'en': 'dish'}),
        subtitle: const LocalizedText({'en': 'sub'}),
        diet: 'classic',
        effort: 'easy',
        timeMinutes: 20,
        caloriesPerServing: 500,
        servings: servings,
        contains: const {},
        attributes: const {},
        tags: const [],
        mealType: 'dinner',
        ingredients: const [
          IngredientLine(ingredientId: 'garlic', amount: 2, unit: 'cloves'),
        ],
        steps: [
          for (var i = 0; i < steps; i++)
            CookStep(
              text: LocalizedText({'en': 'step ${i + 1}'}),
              timerMinutes: timerMinutes,
            ),
        ],
        macros: const Macros(kcal: 500, proteinG: 20, carbsG: 50, fatG: 18),
      );

  group('navigation', () {
    test('next/previous walk the steps', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(3),
        persistProgress: false,
      );
      expect(c.step, 0);
      expect(c.stepCount, 3);
      c.next();
      expect(c.step, 1);
      c.next();
      expect(c.step, 2);
      c.previous();
      expect(c.step, 1);
      c.previous();
      c.previous(); // already at the start: no-op
      expect(c.step, 0);
      c.dispose();
    });

    test('next on the last step finishes exactly once', () {
      var finished = 0;
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(2),
        persistProgress: false,
        onFinished: () => finished++,
      );
      c.next();
      c.next();
      expect(c.isFinished, true);
      expect(finished, 1);
      c.next();
      expect(finished, 1);
      c.dispose();
    });

    test('goTo clamps into range', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(3),
        persistProgress: false,
      );
      c.goTo(99);
      expect(c.step, 2);
      c.goTo(-5);
      expect(c.step, 0);
      c.dispose();
    });

    test('exit fires onExited', () {
      var exited = 0;
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(2),
        persistProgress: false,
        onExited: () => exited++,
      );
      c.exit();
      expect(exited, 1);
      c.dispose();
    });
  });

  group('servings scaler', () {
    test('clamps to 1..99 and scales the ingredient amounts', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(1, servings: 2),
        persistProgress: false,
      );
      expect(c.scaledIngredients.single.amount, 2); // base: 2 servings
      c.setServings(4);
      expect(c.scaledIngredients.single.amount, 4);
      c.setServings(0);
      expect(c.servings, 1);
      c.setServings(500);
      expect(c.servings, 99);
      expect(c.scaledIngredients.single.amount, 99);
      c.dispose();
    });
  });

  group('quick-tap gesture (one-handed cook mode)', () {
    test('is opt-in: disabled by default and does not advance', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(3),
        persistProgress: false,
        reduceMotion: true,
      );
      expect(c.quickNextTapEnabled, false);
      expect(c.quickTapAdvance(), false);
      expect(c.step, 0);
      c.dispose();
    });

    test('advances one step per tap when enabled', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(3),
        persistProgress: false,
        reduceMotion: true,
        quickNextTapEnabled: true,
      );
      expect(c.quickTapAdvance(), true);
      expect(c.step, 1);
      c.dispose();
    });

    test('haptic feedback fires when reduce-motion is off (mocked platform)', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(3),
        persistProgress: false,
        reduceMotion: false,
        quickNextTapEnabled: true,
      );
      expect(c.quickTapAdvance(), true); // must not throw without a real device
      expect(c.step, 1);
      c.dispose();
    });

    test('is debounced by 300 ms to prevent accidental triggers', () async {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(3),
        persistProgress: false,
        reduceMotion: true,
        quickNextTapEnabled: true,
      );
      expect(OneHandedCookModeController.quickTapDebounce.inMilliseconds, 300);
      expect(c.quickTapAdvance(), true);
      expect(c.quickTapAdvance(), false); // inside the debounce window
      expect(c.step, 1);
      await Future<void>.delayed(const Duration(milliseconds: 320));
      expect(c.quickTapAdvance(), true);
      expect(c.step, 2);
      c.dispose();
    });
  });

  group('timer', () {
    testWidgets('counts down, pauses, resumes and completes with a visual flash',
        (tester) async {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(2, timerMinutes: 1),
        persistProgress: false,
        reduceMotion: true,
        visualAlertEnabled: true,
      );
      expect(c.hasTimer, true);
      c.startTimer();
      expect(c.remainingSeconds, 60);
      expect(c.isRunning, true);
      await tester.pump(const Duration(seconds: 1));
      expect(c.remainingSeconds, 59);
      c.pauseTimer();
      expect(c.isPaused, true);
      await tester.pump(const Duration(seconds: 5));
      expect(c.remainingSeconds, 59); // paused: no countdown
      c.resumeTimer();
      expect(c.isPaused, false);
      await tester.pump(const Duration(seconds: 59));
      expect(c.remainingSeconds, 0);
      expect(c.isRunning, false);
      // coral/teal visual flash for deaf / hard-of-hearing users
      expect(c.flash.value, 1.0);
      c.clearFlash();
      expect(c.flash.value, 0.0);
      c.dispose();
    });

    testWidgets('steps without a timer have none', (tester) async {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(2),
        persistProgress: false,
      );
      expect(c.hasTimer, false);
      c.startTimer();
      expect(c.isRunning, false);
      expect(c.remainingSeconds, isNull);
      c.dispose();
    });

    testWidgets('visual alert can be disabled; completion still stops the timer',
        (tester) async {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(1, timerMinutes: 1),
        persistProgress: false,
        reduceMotion: true,
        visualAlertEnabled: false,
      );
      c.startTimer();
      await tester.pump(const Duration(seconds: 61));
      expect(c.remainingSeconds, 0);
      expect(c.isRunning, false);
      expect(c.flash.value, 0.0); // no flash when the setting is off
      c.dispose();
    });

    testWidgets('navigating to another step resets the timer', (tester) async {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(2, timerMinutes: 1),
        persistProgress: false,
      );
      c.startTimer();
      await tester.pump(const Duration(seconds: 10));
      expect(c.remainingSeconds, 50);
      c.next();
      expect(c.remainingSeconds, isNull);
      expect(c.isRunning, false);
      c.dispose();
    });

    test('formatRemaining renders mm:ss', () {
      final c = OneHandedCookModeController(
        recipe: recipeWithSteps(1, timerMinutes: 1),
        persistProgress: false,
        reduceMotion: true,
      );
      c.startTimer();
      expect(c.formatRemaining(), '01:00');
      c.dispose();
    });
  });

  group('progress persistence', () {
    test('step, servings and a paused timer survive a restart', () async {
      final r = recipeWithSteps(3, timerMinutes: 1);
      final c1 = OneHandedCookModeController(recipe: r, persistProgress: true);
      c1.goTo(2);
      c1.setServings(4);
      c1.startTimer();
      c1.pauseTimer();
      await AppStorage.cookProgressBox.flush();
      c1.dispose();

      final c2 = OneHandedCookModeController(recipe: r, persistProgress: true);
      expect(c2.step, 2);
      expect(c2.servings, 4);
      expect(c2.remainingSeconds, 60);
      expect(c2.isRunning, false); // paused timers do not auto-resume
      c2.dispose();
    });

    test('a running timer resumes where it left off', () async {
      final r = recipeWithSteps(2, timerMinutes: 1);
      final c1 = OneHandedCookModeController(recipe: r, persistProgress: true);
      c1.startTimer();
      await AppStorage.cookProgressBox.flush();
      c1.dispose();

      final c2 = OneHandedCookModeController(recipe: r, persistProgress: true);
      expect(c2.isRunning, true);
      expect(c2.remainingSeconds, 60);
      c2.dispose(); // cancels the restored ticker
    });

    test('persistProgress: false never touches storage', () async {
      final r = recipeWithSteps(2, timerMinutes: 1);
      final c = OneHandedCookModeController(recipe: r, persistProgress: false);
      c.goTo(1);
      c.setServings(3);
      await AppStorage.cookProgressBox.flush();
      expect(AppStorage.cookProgressBox.keys, isEmpty);
      c.dispose();
    });
  });
}
