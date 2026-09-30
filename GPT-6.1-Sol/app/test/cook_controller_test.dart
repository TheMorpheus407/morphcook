import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/cook_controller.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('timer follows wall time, pauses and resumes with persistence', () {
    var now = DateTime(2026, 9, 30, 12);
    Map<String, dynamic>? saved;
    final controller = CookController(
      recipe: makeRecipe(),
      clock: () => now,
      persist: (value) => saved = value,
    );
    controller.startTimer();
    expect(controller.running, isTrue);
    expect(saved!['deadline'], isNotNull);
    now = now.add(const Duration(seconds: 20));
    controller.tick();
    expect(controller.remainingSeconds, 40);
    controller.pauseTimer();
    expect(controller.running, isFalse);
    expect(saved!['deadline'], isNull);
    now = now.add(const Duration(minutes: 10));
    controller.resumeTimer();
    now = now.add(const Duration(seconds: 40));
    controller.tick();
    expect(controller.remainingSeconds, 0);
    expect(controller.timerCompleted, isTrue);
    expect(controller.running, isFalse);
    controller.dispose();
  });
  test('resuming a background deadline detects timer completion', () {
    final now = DateTime(2026, 9, 30, 12);
    final controller = CookController(
      recipe: makeRecipe(),
      clock: () => now,
      persist: (_) {},
      progress: {
        'step': 0,
        'servings': 4,
        'remaining_seconds': 60,
        'running': true,
        'deadline': now.subtract(const Duration(seconds: 10)).toIso8601String(),
      },
    );
    expect(controller.timerCompleted, isTrue);
    expect(controller.servings, 4);
    controller.dispose();
  });
  test('steps clear timers, bounds are safe, serving counts persist', () {
    final controller = CookController(recipe: makeRecipe(), persist: (_) {});
    controller.startTimer();
    controller.move(1);
    expect(controller.step, 1);
    expect(controller.running, isFalse);
    expect(controller.remainingSeconds, 0);
    controller.move(10);
    expect(controller.step, 1);
    controller.move(-10);
    expect(controller.step, 0);
    controller.scaleServings(-100);
    expect(controller.servings, 1);
    controller.scaleServings(100);
    expect(controller.servings, 20);
    controller.pauseSession();
    expect(controller.toJson()['servings'], 20);
    controller.dispose();
  });
  test('completed timer alert survives restart and its dismissal persists', () {
    final now = DateTime(2026, 9, 30, 12);
    Map<String, dynamic>? saved;
    final controller = CookController(
      recipe: makeRecipe(),
      clock: () => now,
      persist: (value) => saved = value,
      progress: {
        'step': 0,
        'servings': 2,
        'remaining_seconds': 0,
        'running': false,
        'timer_completed': true,
        'deadline': null,
      },
    );
    expect(controller.timerCompleted, isTrue);
    controller.dismissAlert();
    expect(saved!['timer_completed'], isFalse);
    controller.dispose();
  });
  test(
    'one-handed gesture is opt-in and debounces 300ms, also with reduced motion',
    () {
      final controller = OneHandedCookModeController(reduceMotion: true);
      final now = DateTime(2026, 9, 30, 12);
      expect(controller.acceptTap(now), isFalse);
      controller.quickNextTapEnabled = true;
      expect(controller.acceptTap(now), isTrue);
      expect(
        controller.acceptTap(now.add(const Duration(milliseconds: 299))),
        isFalse,
      );
      expect(
        controller.acceptTap(now.add(const Duration(milliseconds: 300))),
        isTrue,
      );
    },
  );
}
