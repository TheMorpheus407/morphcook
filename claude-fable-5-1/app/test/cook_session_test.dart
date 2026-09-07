import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/domain/cook_session.dart';

import 'helpers.dart';

void main() {
  late CorpusRepository repo;
  setUpAll(() async => repo = await loadRepo());

  test('steps, servings scaling and persistence snapshots', () {
    final r = recipeOf(repo, 'doener-classic-easy');
    final saved = <CookProgress>[];
    final c = CookModeController(recipe: r, onProgress: saved.add);
    expect(c.stepIndex, 0);
    expect(c.isFirst, isTrue);
    expect(c.next(), isTrue);
    expect(c.stepIndex, 1);
    expect(c.prev(), isTrue);
    expect(c.prev(), isFalse);
    c.setServings(4);
    expect(c.scale, 2);
    expect(c.scaledIngredients.first.amount, r.ingredients.first.amount! * 2);
    expect(saved.last.servings, 4);
    c.goTo(99);
    expect(c.isLast, isTrue);
    c.dispose();
  });

  test('timer counts down, finishes once, and bumps the alert count', () {
    final r = recipeOf(repo, 'doener-classic-easy');
    final c = CookModeController(recipe: r);
    expect(c.timer, isNotNull); // step 1 has a 10-minute marinade timer
    expect(c.timer!.total, 600);
    c.startTimer();
    expect(c.timer!.running, isTrue);
    c.tick(const Duration(seconds: 590));
    expect(c.timer!.remaining, 10);
    expect(c.alertCount, 0);
    c.tick(const Duration(seconds: 30));
    expect(c.timer!.done, isTrue);
    expect(c.timer!.running, isFalse);
    expect(c.alertCount, 1);
    c.tick(const Duration(seconds: 5));
    expect(c.alertCount, 1);
    c.resetTimer();
    expect(c.timer!.remaining, 600);
    c.dispose();
  });

  test('pause and resume keep the remaining time; custom timers work on any step', () {
    final r = recipeOf(repo, 'doener-classic-easy');
    final c = CookModeController(recipe: r);
    c.goTo(1);
    expect(c.timer, isNull);
    c.startTimer(120);
    c.tick(const Duration(seconds: 20));
    c.pauseTimer();
    c.tick(const Duration(seconds: 20));
    expect(c.timer!.remaining, 100);
    c.resumeTimer();
    c.tick(const Duration(seconds: 10));
    expect(c.timer!.remaining, 90);
    c.adjustTimer(60);
    expect(c.timer!.remaining, 150);
    c.pauseSession();
    expect(c.paused, isTrue);
    expect(c.timer!.running, isFalse);
    c.resumeSession();
    expect(c.paused, isFalse);
    c.dispose();
  });

  test('resumes from persisted progress', () {
    final r = recipeOf(repo, 'doener-classic-easy');
    final p = CookProgress(recipeId: r.id, stepIndex: 3, servings: 3, updatedAt: DateTime.now(), timerTotal: 480, timerRemaining: 200);
    final c = CookModeController(recipe: r, resume: p);
    expect(c.stepIndex, 3);
    expect(c.servings, 3);
    expect(c.timer!.remaining, 200);
    expect(c.timer!.running, isFalse);
    final json = CookProgress.fromJson(p.toJson());
    expect(json.stepIndex, 3);
    expect(json.timerRemaining, 200);
    c.dispose();
  });

  test('one-handed quick tap: opt-in, 300 ms debounce, haptic on advance', () {
    final r = recipeOf(repo, 'doener-classic-easy');
    final cook = CookModeController(recipe: r);
    final one = OneHandedCookModeController();
    var haptics = 0;
    final t0 = DateTime(2026, 9, 1, 12, 0, 0);
    expect(one.handleTap(cook, now: t0, haptic: () => haptics++), isFalse);
    expect(cook.stepIndex, 0);
    one.quickNextTapEnabled = true;
    expect(one.handleTap(cook, now: t0, haptic: () => haptics++), isTrue);
    expect(cook.stepIndex, 1);
    expect(one.handleTap(cook, now: t0.add(const Duration(milliseconds: 200)), haptic: () => haptics++), isFalse);
    expect(cook.stepIndex, 1);
    expect(one.handleTap(cook, now: t0.add(const Duration(milliseconds: 600)), haptic: () => haptics++), isTrue);
    expect(cook.stepIndex, 2);
    expect(haptics, 2);
    cook.goTo(r.steps.length - 1);
    expect(one.handleTap(cook, now: t0.add(const Duration(seconds: 5)), haptic: () => haptics++), isFalse);
    expect(haptics, 2);
    cook.dispose();
    one.dispose();
  });
}
