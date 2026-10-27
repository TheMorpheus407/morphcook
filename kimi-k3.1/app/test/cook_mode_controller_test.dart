import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/controllers/cook_mode_controller.dart';
import 'package:morphcook/models/user_data.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quick-next is opt-in, haptic-capable and debounced for 300ms', () {
    var now = DateTime.utc(2026, 4, 18, 12);
    var calls = 0;
    final quick = OneHandedCookModeController(
      quickNextTapEnabled: true,
      reduceMotion: false,
      onNext: () => calls++,
      clock: () => now,
    );
    expect(quick.handleTap(), isTrue);
    expect(calls, 1);
    now = now.add(const Duration(milliseconds: 299));
    expect(quick.handleTap(), isFalse);
    expect(calls, 1);
    now = now.add(const Duration(milliseconds: 1));
    expect(quick.handleTap(), isTrue);
    expect(calls, 2);
    final reduced = OneHandedCookModeController(
      quickNextTapEnabled: true,
      reduceMotion: true,
      onNext: () => calls++,
    );
    expect(reduced.handleTap(), isFalse);
    final disabled = OneHandedCookModeController(
      quickNextTapEnabled: false,
      reduceMotion: false,
      onNext: () => calls++,
    );
    expect(disabled.handleTap(), isFalse);
    expect(calls, 2);
  });

  test('timer pauses, resumes, persists and flashes when complete', () {
    fakeAsync((async) {
      final saved = <CookProgress>[];
      final controller = CookModeController(
        recipe: testRecipe(),
        initialProgress: null,
        visualAlertEnabled: true,
        reduceMotion: false,
        onPersist: (progress, notify) => saved.add(progress),
        onCompleted: (id, servings) {},
      );
      controller.resume();
      async.elapse(const Duration(seconds: 30));
      controller.pause();
      expect(controller.remainingSeconds, 30);
      async.elapse(const Duration(seconds: 5));
      expect(controller.remainingSeconds, 30);
      controller.resume();
      async.elapse(const Duration(seconds: 30));
      expect(controller.remainingSeconds, 0);
      expect(controller.isRunning, isFalse);
      expect(controller.alertVisible, isTrue);
      expect(saved, isNotEmpty);
      expect(saved.last.isRunning, isFalse);
      async.elapse(const Duration(milliseconds: 350));
      expect(controller.alertPhase, greaterThan(0));
      controller.dismissAlert();
      expect(controller.alertVisible, isFalse);
      controller.dispose();
    });
  });

  test(
    'reduced motion keeps timer alert static and alerts can be disabled',
    () {
      fakeAsync((async) {
        final controller = CookModeController(
          recipe: testRecipe(),
          initialProgress: null,
          reduceMotion: true,
          onPersist: (progress, notify) {},
          onCompleted: (id, servings) {},
        );
        controller.resume();
        async.elapse(const Duration(seconds: 61));
        expect(controller.alertVisible, isTrue);
        expect(controller.alertPhase, 0);
        controller.dispose();
        final silent = CookModeController(
          recipe: testRecipe(),
          initialProgress: null,
          visualAlertEnabled: false,
          onPersist: (progress, notify) {},
          onCompleted: (id, servings) {},
        );
        silent.resume();
        async.elapse(const Duration(seconds: 61));
        expect(silent.alertVisible, isFalse);
        silent.dispose();
      });
    },
  );

  test('restores running progress using elapsed wall time', () {
    final now = DateTime.utc(2026, 4, 18, 12);
    final controller = CookModeController(
      recipe: testRecipe(),
      initialProgress: CookProgress(
        recipeId: 'r1',
        stepIndex: 0,
        remainingSeconds: 50,
        servings: 4,
        isRunning: true,
        updatedAt: now.subtract(const Duration(seconds: 10)),
      ),
      clock: () => now,
      onPersist: (progress, notify) {},
      onCompleted: (id, servings) {},
    );
    expect(controller.remainingSeconds, 40);
    expect(controller.servings, 4);
    expect(controller.isRunning, isTrue);
    controller.dispose();
  });

  test('completion is recorded once with selected servings', () {
    var completions = 0;
    var completedServings = 0;
    final controller = CookModeController(
      recipe: testRecipe(),
      initialProgress: null,
      onPersist: (progress, notify) {},
      onCompleted: (id, servings) {
        completions++;
        completedServings = servings;
      },
    );
    controller.setServings(5);
    controller.next();
    controller.next();
    expect(controller.completed, isTrue);
    expect(controller.progress, 1);
    expect(completions, 1);
    expect(completedServings, 5);
    controller.dispose();
  });
}
