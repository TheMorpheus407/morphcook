import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/cook.dart';

import 'helpers.dart';

void main() {
  test('servings scale and persist', () {
    CookProgress? stored;
    final session = CookSessionController(
      recipe: testRecipe(),
      persist: (p) => stored = p,
    );
    session.setServings(4);
    expect(session.scaleFactor, 2);
    expect(stored?.servings, 4);
    session.dispose();
  });

  test('timer ticks to completion and flags alert', () {
    final session = CookSessionController(
      recipe: testRecipe(timerMinutes: 1),
      persist: (_) {},
    );
    session.startTimer();
    expect(session.remainingSeconds, 60);
    for (var i = 0; i < 60; i++) {
      session.tick();
    }
    expect(session.remainingSeconds, 0);
    expect(session.timerJustFinished, isTrue);
    session.consumeTimerAlert();
    expect(session.timerJustFinished, isFalse);
    session.dispose();
  });

  test('pause persist remaining seconds', () {
    CookProgress? stored;
    final session = CookSessionController(
      recipe: testRecipe(timerMinutes: 1),
      persist: (p) => stored = p,
    );
    session.startTimer();
    session.tick();
    session.pauseTimer();
    expect(session.isTimerPaused, isTrue);
    expect(stored?.remainingTimerSeconds, 59);
    session.dispose();
  });

  test('next and previous step', () {
    final session = CookSessionController(
      recipe: testRecipe(),
      persist: (_) {},
    );
    expect(session.nextStep(), isTrue);
    expect(session.stepIndex, 1);
    session.previousStep();
    expect(session.stepIndex, 0);
    session.dispose();
  });

  test('completing last step clears progress', () {
    CookProgress? stored = const CookProgress(
      recipeId: 'x',
      stepIndex: 0,
      servings: 2,
    );
    final session = CookSessionController(
      recipe: testRecipe(),
      persist: (p) => stored = p,
    );
    session.nextStep();
    session.nextStep();
    expect(session.isCompleted, isTrue);
    expect(stored, isNull);
    session.dispose();
  });

  test('one handed tap debounce is 300ms', () {
    var now = DateTime(2026, 1, 1, 12);
    final ctl = OneHandedCookModeController(
      quickNextTapEnabled: true,
      now: () => now,
    );
    expect(ctl.handleTap(), isTrue);
    now = now.add(const Duration(milliseconds: 100));
    expect(ctl.handleTap(), isFalse);
    now = now.add(const Duration(milliseconds: 250));
    expect(ctl.handleTap(), isTrue);
  });

  test('one handed disabled never advances', () {
    final ctl = OneHandedCookModeController();
    expect(ctl.handleTap(), isFalse);
  });
}
