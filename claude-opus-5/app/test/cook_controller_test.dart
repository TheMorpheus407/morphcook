import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/screens/cook/cook_controller.dart';

import 'support/fixtures.dart';

RecipeStep stepSaying(String text) =>
    RecipeStep(text: Localized({'en': text, 'de': text}), timerSeconds: null);

void main() {
  group('StepTimer', () {
    test('a step without a timer reports no timer', () {
      final timer = StepTimer()..configure(null);
      expect(timer.hasTimer, isFalse);
      timer.start();
      expect(timer.running, isFalse);
      timer.dispose();
    });

    test('counts down and finishes exactly once', () {
      fakeAsync((async) {
        var finished = 0;
        final timer = StepTimer()..configure(3);
        timer.onFinished = () {
          finished++;
        };

        expect(timer.remaining, 3);
        timer.start();
        expect(timer.running, isTrue);

        async.elapse(const Duration(seconds: 2));
        expect(timer.remaining, 1);
        expect(timer.finished, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(timer.remaining, 0);
        expect(timer.finished, isTrue);
        expect(timer.running, isFalse);
        expect(finished, 1);

        async.elapse(const Duration(seconds: 5));
        expect(finished, 1);
        timer.dispose();
      });
    });

    test('pause holds the remaining time', () {
      fakeAsync((async) {
        final timer = StepTimer()..configure(10);
        timer.start();
        async.elapse(const Duration(seconds: 3));
        timer.pause();
        final held = timer.remaining;
        async.elapse(const Duration(seconds: 5));
        expect(timer.remaining, held);
        expect(timer.running, isFalse);
        timer.dispose();
      });
    });

    test('resume continues from where it stopped', () {
      fakeAsync((async) {
        final timer = StepTimer()..configure(10);
        timer.start();
        async.elapse(const Duration(seconds: 4));
        timer.pause();
        timer.start();
        async.elapse(const Duration(seconds: 2));
        expect(timer.remaining, 4);
        timer.dispose();
      });
    });

    test('reset restores the full duration', () {
      fakeAsync((async) {
        final timer = StepTimer()..configure(10);
        timer.start();
        async.elapse(const Duration(seconds: 6));
        timer.reset();
        expect(timer.remaining, 10);
        expect(timer.running, isFalse);
        expect(timer.finished, isFalse);
        timer.dispose();
      });
    });

    test('toggle flips between running and paused', () {
      fakeAsync((async) {
        final timer = StepTimer()..configure(10);
        timer.toggle();
        expect(timer.running, isTrue);
        timer.toggle();
        expect(timer.running, isFalse);
        timer.dispose();
      });
    });

    test('configure with resumeAt restores a persisted position', () {
      final timer = StepTimer()..configure(120, resumeAt: 45);
      expect(timer.total, 120);
      expect(timer.remaining, 45);
      expect(timer.progress, closeTo(0.625, 0.001));
      timer.dispose();
    });

    test('a resumeAt beyond the total is clamped', () {
      final timer = StepTimer()..configure(60, resumeAt: 900);
      expect(timer.remaining, 60);
      timer.dispose();
    });

    test('progress runs from 0 to 1', () {
      fakeAsync((async) {
        final timer = StepTimer()..configure(4);
        expect(timer.progress, 0);
        timer.start();
        async.elapse(const Duration(seconds: 2));
        expect(timer.progress, closeTo(0.5, 0.001));
        async.elapse(const Duration(seconds: 2));
        expect(timer.progress, 1);
        timer.dispose();
      });
    });

    test('reconfiguring for the next step cancels the old ticker', () {
      fakeAsync((async) {
        var finished = 0;
        final timer = StepTimer()..configure(3);
        timer.onFinished = () {
          finished++;
        };
        timer.start();
        async.elapse(const Duration(seconds: 1));
        timer.configure(60);
        async.elapse(const Duration(seconds: 10));
        expect(finished, 0);
        expect(timer.remaining, 60);
        timer.dispose();
      });
    });
  });

  group('OneHandedCookModeController', () {
    final t0 = DateTime(2026, 7, 26, 12, 0, 0);

    test('is inert when the gesture is not opted into', () {
      final c = OneHandedCookModeController();
      expect(c.isActive, isFalse);
      expect(c.registerTap(t0), isFalse);
    });

    test('accepts a tap once enabled', () {
      final c = OneHandedCookModeController(quickNextTapEnabled: true);
      expect(c.isActive, isTrue);
      expect(c.registerTap(t0), isTrue);
    });

    test('debounces for 300 ms', () {
      final c = OneHandedCookModeController(quickNextTapEnabled: true);
      expect(c.registerTap(t0), isTrue);
      expect(c.registerTap(t0.add(const Duration(milliseconds: 100))), isFalse);
      expect(c.registerTap(t0.add(const Duration(milliseconds: 299))), isFalse);
      expect(c.registerTap(t0.add(const Duration(milliseconds: 300))), isTrue);
    });

    test('the debounce window restarts from the accepted tap', () {
      final c = OneHandedCookModeController(quickNextTapEnabled: true);
      c.registerTap(t0);
      c.registerTap(t0.add(const Duration(milliseconds: 200))); // rejected
      expect(
        c.registerTap(t0.add(const Duration(milliseconds: 350))),
        isTrue,
        reason: 'measured from the accepted tap, not the rejected one',
      );
    });

    test('reduced motion switches the gesture off', () {
      final c = OneHandedCookModeController(
        quickNextTapEnabled: true,
        reduceMotion: true,
      );
      expect(c.isActive, isFalse);
      expect(c.registerTap(t0), isFalse);
    });

    test('reset clears the debounce', () {
      final c = OneHandedCookModeController(quickNextTapEnabled: true);
      c.registerTap(t0);
      c.reset();
      expect(c.registerTap(t0.add(const Duration(milliseconds: 10))), isTrue);
    });
  });

  group('ingredientsMentionedIn', () {
    test('matches an ingredient named in the step text', () {
      final recipe = makeRecipe(id: 'r', ingredientIds: {'garlic', 'parmesan'});
      final match = ingredientsMentionedIn(
        stepSaying('Grate the parmesan over the top.'),
        recipe,
        testIngredients(),
        'en',
      );
      expect(match.map((e) => e.ingredientId), contains('parmesan'));
      expect(match.map((e) => e.ingredientId), isNot(contains('garlic')));
    });

    test('a plural in the text still matches the singular label', () {
      final recipe = makeRecipe(id: 'r', ingredientIds: {'apple'});
      final match = ingredientsMentionedIn(
        stepSaying('Core the apples and slice them thin.'),
        recipe,
        testIngredients(),
        'en',
      );
      expect(match, hasLength(1));
    });

    test('short words do not produce spurious matches', () {
      final recipe = makeRecipe(id: 'r', ingredientIds: {'garlic'});
      final match = ingredientsMentionedIn(
        stepSaying('Heat the pan until it is very hot.'),
        recipe,
        testIngredients(),
        'en',
      );
      expect(match, isEmpty);
    });

    test('a multi-word label matches on its distinctive word', () {
      final recipe = makeRecipe(id: 'r', ingredientIds: {'olive-oil'});
      final match = ingredientsMentionedIn(
        stepSaying('Warm the olive oil in a wide pan.'),
        recipe,
        testIngredients(),
        'en',
      );
      expect(match, hasLength(1));
    });
  });
}
