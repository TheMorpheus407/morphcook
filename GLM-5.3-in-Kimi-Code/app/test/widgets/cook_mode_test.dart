import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models.dart';
import 'package:morphcook/screens/cook_mode_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;
  late Recipe recipe;

  setUpAll(() async {
    corpus = await Corpus.load();
    recipe = corpus.recipes['doener-vegan']!;
  });

  OneHandedCookModeController make({bool quickTap = false}) =>
      OneHandedCookModeController(
        recipe: recipe,
        quickNextTapEnabled: quickTap,
        reduceMotion: false,
        visualAlertEnabled: true,
        initialStep: 0,
        initialServings: recipe.servings,
      );

  group('navigation', () {
    test('next advances and completes on last step', () {
      final c = make();
      final steps = recipe.steps.length;
      for (var i = 0; i < steps - 1; i++) {
        c.next();
      }
      expect(c.stepIndex, steps - 1);
      expect(c.completed, isFalse);
      c.next();
      expect(c.completed, isTrue);
      c.dispose();
    });

    test('previous never underflows', () {
      final c = make();
      c.previous();
      expect(c.stepIndex, 0);
      c.dispose();
    });

    test('jumpTo clamps to valid range', () {
      final c = make();
      c.jumpTo(2);
      expect(c.stepIndex, 2);
      c.jumpTo(-1);
      expect(c.stepIndex, 2);
      c.dispose();
    });
  });

  group('quick-tap', () {
    test('disabled controller ignores taps', () {
      final c = make(quickTap: false);
      expect(c.handleContentTap(), isFalse);
      expect(c.stepIndex, 0);
      c.dispose();
    });

    test('enabled controller advances on tap', () {
      final c = make(quickTap: true);
      expect(c.handleContentTap(), isTrue);
      expect(c.stepIndex, 1);
      c.dispose();
    });

    test('300ms debounce blocks rapid double-taps', () {
      final c = make(quickTap: true);
      expect(c.handleContentTap(), isTrue);
      // second tap within 300ms is swallowed
      expect(c.handleContentTap(), isFalse);
      expect(c.stepIndex, 1);
      c.dispose();
    });

    test('no quick-tap after completion', () {
      final c = make(quickTap: true);
      for (var i = 0; i < recipe.steps.length; i++) {
        c.next();
      }
      expect(c.completed, isTrue);
      expect(c.handleContentTap(), isFalse);
      c.dispose();
    });
  });

  group('servings scaler', () {
    test('setServings clamps to 1..24', () {
      final c = make();
      c.setServings(0);
      expect(c.servings, recipe.servings);
      c.setServings(25);
      expect(c.servings, recipe.servings);
      c.setServings(6);
      expect(c.servings, 6);
      c.dispose();
    });
  });

  group('progress persistence', () {
    test('serialize captures step and servings', () {
      final c = make();
      c.jumpTo(2);
      c.setServings(4);
      final s = c.serialize();
      expect(s['step'], 2);
      expect(s['servings'], 4);
      c.dispose();
    });

    test('restores from persisted values', () {
      final c = OneHandedCookModeController(
        recipe: recipe,
        quickNextTapEnabled: false,
        reduceMotion: false,
        visualAlertEnabled: true,
        initialStep: 3,
        initialServings: 6,
      );
      expect(c.stepIndex, 3);
      expect(c.servings, 6);
      c.dispose();
    });
  });

  group('timers', () {
    test('steps with timer_seconds expose hasTimer', () {
      final c = make();
      expect(recipe.steps.any((s) => s.timerSeconds != null), isTrue);
      expect(c.hasTimer, recipe.steps.first.timerSeconds != null);
      c.dispose();
    });

    test('restartTimer resets remaining seconds', () {
      final c = make();
      if (!c.hasTimer) c.jumpTo(_firstTimerStep(recipe));
      final seconds = c.currentStep.timerSeconds!;
      c.restartTimer();
      expect(c.remainingSeconds, seconds);
      expect(c.timerRunning, isTrue);
      c.dispose();
    });

    test('pauseTimer stops the countdown and marks paused', () {
      final c = make();
      if (!c.hasTimer) c.jumpTo(_firstTimerStep(recipe));
      c.startTimer();
      c.pauseTimer();
      expect(c.timerRunning, isFalse);
      expect(c.paused, isTrue);
      c.dispose();
    });
  });
}

int _firstTimerStep(Recipe r) {
  for (var i = 0; i < r.steps.length; i++) {
    if (r.steps[i].timerSeconds != null) return i;
  }
  return 0;
}
