import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/state/controllers/cook_session_controller.dart';
import 'package:morphcook/state/storage/storage.dart';

import '../support/fixtures.dart';

void main() {
  var now = DateTime(2026, 9, 28, 18);
  DateTime clock() => now;

  // Step 1 has no timer, step 2 has 60 s, step 3 has 120 s, step 4 has none.
  final recipe = recipeFixture(
    id: 'test-recipe',
    servings: 2,
    steps: [step('Chop.'), step('Sear.', seconds: 60), step('Simmer.', seconds: 120), step('Serve.')],
  );

  Future<CookSessionController> open([AppStorage? storage]) async {
    now = DateTime(2026, 9, 28, 18);
    return CookSessionController.open(storage ?? AppStorage.memory(), clock: clock, autoTick: false);
  }

  Future<CookSessionController> started({AppStorage? storage, double? servings}) async {
    final c = await open(storage);
    await c.begin(recipe, servings: servings);
    return c;
  }

  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  group('steps', () {
    test('begins on the first step with the recipe servings', () async {
      final c = await started();
      expect(c.isActive, isTrue);
      expect(c.stepIndex, 0);
      expect(c.stepCount, 4);
      expect(c.isFirstStep, isTrue);
      expect(c.isLastStep, isFalse);
      expect(c.servings, 2);
      expect(c.scale, 1);
    });

    test('next and previous move through the steps and stop at the ends', () async {
      final c = await started();
      c.previous();
      expect(c.stepIndex, 0);
      c.next();
      c.next();
      expect(c.stepIndex, 2);
      c.previous();
      expect(c.stepIndex, 1);
      c.goTo(3);
      expect(c.isLastStep, isTrue);
      c.goTo(99);
      c.goTo(-1);
      expect(c.stepIndex, 3);
    });

    test('next on the last step completes the recipe, previous leaves the completion screen', () async {
      final c = await started();
      c.goTo(3);
      c.next();
      expect(c.completed, isTrue);
      c.previous();
      expect(c.completed, isFalse);
      expect(c.stepIndex, 3);
    });

    test('the servings scaler changes the scale factor within 1 to 24', () async {
      final c = await started(servings: 4);
      expect(c.servings, 4);
      expect(c.scale, 2);
      c.setServings(3);
      expect(c.scale, 1.5);
      c.setServings(0);
      expect(c.servings, 1);
      c.setServings(100);
      expect(c.servings, 24);
    });

    test('notifies listeners on every change', () async {
      final c = await started();
      var heard = 0;
      c.addListener(() => heard++);
      c.next();
      c.setServings(3);
      expect(heard, greaterThanOrEqualTo(2));
    });
  });

  group('per-step timers', () {
    test('the authored duration is what a step offers', () async {
      final c = await started();
      expect(c.timerSecondsFor(0), isNull);
      expect(c.timerSecondsFor(1), 60);
      expect(c.timerSecondsFor(2), 120);
      expect(c.remainingSeconds(1), 60, reason: 'not started yet');
    });

    test('start runs the timer against the wall clock', () async {
      final c = await started();
      c.startTimer(1);
      expect(c.isTimerRunning(1), isTrue);
      expect(c.remainingSeconds(1), 60);
      advance(25);
      expect(c.remainingSeconds(1), 35);
      expect(c.runningTimerSteps, [1]);
    });

    test('a step without a timer cannot start one', () async {
      final c = await started();
      c.startTimer(0);
      expect(c.timerAt(0), isNull);
    });

    test('pausing freezes the remaining time, starting again continues', () async {
      final c = await started();
      c.startTimer(1);
      advance(20);
      c.pauseTimer(1);
      expect(c.isTimerRunning(1), isFalse);
      advance(500);
      expect(c.remainingSeconds(1), 40);
      c.startTimer(1);
      advance(10);
      expect(c.remainingSeconds(1), 30);
    });

    test('several timers run at once, one per step', () async {
      final c = await started();
      c.startTimer(1);
      c.startTimer(2);
      advance(30);
      expect(c.runningTimerSteps, [1, 2]);
      expect(c.remainingSeconds(1), 30);
      expect(c.remainingSeconds(2), 90);
    });

    test('a timer that runs out fires timerDone once and stays finished', () async {
      final c = await started();
      final events = <int>[];
      final sub = c.timerDone.listen((e) => events.add(e.stepIndex));
      c.startTimer(1);
      advance(59);
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);
      advance(2);
      c.tick();
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(events, [1]);
      expect(c.isTimerFinished(1), isTrue);
      expect(c.remainingSeconds(1), 0);
      expect(c.runningTimerSteps, isEmpty);
      await sub.cancel();
    });

    test('a finished timer starts again from the full duration', () async {
      final c = await started();
      c.startTimer(1);
      advance(61);
      c.tick();
      c.startTimer(1);
      expect(c.isTimerRunning(1), isTrue);
      expect(c.remainingSeconds(1), 60);
    });

    test('reset forgets the timer', () async {
      final c = await started();
      c.startTimer(1);
      advance(10);
      c.resetTimer(1);
      expect(c.timerAt(1), isNull);
      expect(c.remainingSeconds(1), 60);
    });

    test('toggle starts and pauses', () async {
      final c = await started();
      c.toggleTimer(1);
      expect(c.isTimerRunning(1), isTrue);
      c.toggleTimer(1);
      expect(c.isTimerRunning(1), isFalse);
    });

    test('tick catches up after the app was away: the wall clock is the truth', () async {
      final c = await started();
      final events = <int>[];
      final sub = c.timerDone.listen((e) => events.add(e.stepIndex));
      c.startTimer(1);
      c.startTimer(2);
      advance(3600);
      c.tick();
      await Future<void>.delayed(Duration.zero);
      expect(events, unorderedEquals([1, 2]));
      await sub.cancel();
    });

    test('the automatic ticker finishes timers by itself', () async {
      // Shorter ticks than the default keep the test quick.
      final c = CookSessionController(
        await AppStorage.memory().records.open(Boxes.cookSession),
        clock: clock,
        tickInterval: const Duration(milliseconds: 10),
      );
      addTearDown(c.dispose);
      await c.begin(recipe);
      final done = c.timerDone.first;
      c.startTimer(1);
      now = now.add(const Duration(seconds: 61));
      final event = await done.timeout(const Duration(seconds: 2));
      expect(event.stepIndex, 1);
      expect(c.isTimerFinished(1), isTrue);
    });
  });

  group('pause and resume with progress persistence', () {
    test('pause freezes all running timers, resume restarts exactly those', () async {
      final c = await started();
      c.startTimer(1);
      c.startTimer(2);
      c.pauseTimer(2);
      advance(20);
      c.pause();
      expect(c.paused, isTrue);
      expect(c.runningTimerSteps, isEmpty);
      advance(1000);
      expect(c.remainingSeconds(1), 40);
      c.resume();
      expect(c.paused, isFalse);
      expect(c.runningTimerSteps, [1], reason: 'the paused timer of step 3 stays paused');
      advance(10);
      expect(c.remainingSeconds(1), 30);
    });

    test('timers cannot start while the session is paused', () async {
      final c = await started();
      c.pause();
      c.startTimer(1);
      expect(c.timerAt(1), isNull);
    });

    test('the run is stored and picked up again after a restart', () async {
      final storage = AppStorage.memory();
      final c = await started(storage: storage, servings: 4);
      c.next();
      c.next();
      c.startTimer(2);
      advance(30);
      await c.suspend();
      expect(c.isActive, isFalse);

      final again = await open(storage);
      final stored = again.storedSession!;
      expect(stored.recipeId, 'test-recipe');
      expect(stored.stepIndex, 2);
      expect(stored.servings, 4);
      expect(stored.paused, isTrue);

      await again.begin(recipe, resume: true);
      expect(again.stepIndex, 2);
      expect(again.servings, 4);
      expect(again.paused, isTrue);
      expect(again.remainingSeconds(2), 90, reason: 'frozen at 90 seconds left when leaving');
      again.resume();
      advance(30);
      expect(again.remainingSeconds(2), 60);
    });

    test('resuming another recipe starts fresh', () async {
      final storage = AppStorage.memory();
      final c = await started(storage: storage);
      c.next();
      await c.suspend();
      final again = await open(storage);
      await again.begin(recipeFixture(id: 'other', steps: [step('a'), step('b'), step('c')]), resume: true);
      expect(again.stepIndex, 0);
    });

    test('a stored step beyond the recipe is clamped', () async {
      final storage = AppStorage.memory();
      final c = await started(storage: storage);
      c.goTo(3);
      await c.suspend();
      final again = await open(storage);
      await again.begin(recipeFixture(id: 'test-recipe', steps: [step('a'), step('b'), step('c')]), resume: true);
      expect(again.stepIndex, 2);
    });

    test('damaged stored data is ignored', () async {
      final storage = AppStorage.memory();
      final box = await storage.records.open(Boxes.cookSession);
      await box.put('current', 'garbage');
      final c = await open(storage);
      expect(c.storedSession, isNull);
    });

    test('timers that ran while the app was closed are finished after a restart', () async {
      final storage = AppStorage.memory();
      final c = await started(storage: storage);
      c.startTimer(1);
      // Simulate a crash: the run is stored without pausing.
      await Future<void>.delayed(Duration.zero);
      final again = await open(storage);
      now = now.add(const Duration(minutes: 10));
      await again.begin(recipe, resume: true);
      expect(again.isTimerFinished(1), isTrue);
    });
  });

  group('finishing', () {
    test('complete returns the history entry and clears the stored run', () async {
      final storage = AppStorage.memory();
      final c = await started(storage: storage, servings: 3);
      final entry = await c.complete();
      expect(entry.recipeId, 'test-recipe');
      expect(entry.servings, 3);
      expect(entry.cookedAt, now);
      expect(c.isActive, isFalse);
      expect((await open(storage)).storedSession, isNull);
    });

    test('abandon drops the run without a trace', () async {
      final storage = AppStorage.memory();
      final c = await started(storage: storage);
      await c.abandon();
      expect(c.isActive, isFalse);
      expect((await open(storage)).storedSession, isNull);
    });
  });

  group('serialization', () {
    test('a session survives a JSON round trip', () {
      final session = CookSession(
        recipeId: 'r',
        servings: 3,
        stepIndex: 2,
        timers: {
          1: StepTimer(totalSeconds: 60, remainingSeconds: 40, endsAt: DateTime.utc(2026, 9, 28, 18, 1)),
          2: const StepTimer(totalSeconds: 30, remainingSeconds: 0, finished: true),
        },
        paused: true,
        pausedTimers: const {1},
        startedAt: DateTime.utc(2026, 9, 28, 17),
        updatedAt: DateTime.utc(2026, 9, 28, 18),
      );
      final back = CookSession.fromJson(session.toJson());
      expect(back.recipeId, 'r');
      expect(back.servings, 3);
      expect(back.stepIndex, 2);
      expect(back.paused, isTrue);
      expect(back.pausedTimers, {1});
      expect(back.timers[1]!.running, isTrue);
      expect(back.timers[2]!.finished, isTrue);
    });

    test('StepTimer remaining time never goes negative', () {
      final timer = StepTimer(totalSeconds: 10, remainingSeconds: 10, endsAt: DateTime(2026, 1, 1, 12));
      expect(timer.remainingAt(DateTime(2026, 1, 1, 12, 0, 5)), 0);
      expect(timer.remainingAt(DateTime(2026, 1, 1, 11, 59, 58)), 2);
      expect(
        timer.remainingAt(DateTime(2026, 1, 1, 11, 59, 57, 500)),
        3,
        reason: 'rounded up so 0 only shows at the end',
      );
    });
  });
}
