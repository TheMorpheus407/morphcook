import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/cook_session_controller.dart';

void main() {
  test(
    'restores a fresh session, scales servings and persists navigation',
    () async {
      final persistence = _MemoryPersistence();
      final controller = await CookSessionController.restore(
        recipeId: 'recipe',
        baseServings: 2,
        totalSteps: 3,
        persistence: persistence,
      );
      expect(controller.wasRestored, isFalse);

      controller.setServings(5);
      expect(controller.servingsScale, 2.5);
      expect(controller.scaleQuantity(3), 7.5);
      expect(controller.scaleQuantity(null), isNull);

      controller.nextStep();
      expect(controller.currentStepIndex, 1);
      expect(controller.completedStepIndices, <int>{0});
      controller.previousStep();
      expect(controller.currentStepIndex, 0);

      await controller.flush();
      expect(persistence.sessions['recipe']!.servings, 5);
      expect(persistence.sessions['recipe']!.currentStepIndex, 0);
      final completionId = controller.completionRecordId;
      controller.dispose();

      final restored = await CookSessionController.restore(
        recipeId: 'recipe',
        baseServings: 2,
        totalSteps: 3,
        persistence: persistence,
      );
      expect(restored.wasRestored, isTrue);
      expect(restored.servings, 5);
      expect(restored.completionRecordId, completionId);
      restored.dispose();
    },
  );

  test(
    'per-step timer completes and produces a static reduced-motion alert',
    () {
      fakeAsync((async) {
        final clock = _FakeClock(DateTime.utc(2026, 1, 1));
        final persistence = _MemoryPersistence();
        late CookSessionController controller;
        CookSessionController.restore(
          recipeId: 'recipe',
          baseServings: 2,
          totalSteps: 2,
          persistence: persistence,
          reduceMotion: true,
          clock: clock.call,
        ).then((value) => controller = value);
        async.flushMicrotasks();

        controller.startTimer(0, const Duration(seconds: 2));
        expect(controller.timers[0]!.status, CookTimerStatus.running);
        clock.advance(const Duration(seconds: 2));
        async.elapse(const Duration(milliseconds: 250));

        expect(controller.timers[0]!.remainingSeconds, 0);
        expect(controller.timers[0]!.status, CookTimerStatus.completed);
        expect(controller.visualAlert, isNotNull);
        expect(controller.visualAlert!.tone, TimerAlertTone.coral);
        expect(controller.visualAlert!.shouldAnimate, isFalse);
        controller.dismissVisualAlert();
        expect(controller.visualAlert, isNull);
        controller.dispose();
      });
    },
  );

  test('pause freezes all timers and resume recreates their deadlines', () {
    fakeAsync((async) {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      final persistence = _MemoryPersistence();
      late CookSessionController controller;
      CookSessionController.restore(
        recipeId: 'recipe',
        baseServings: 2,
        totalSteps: 2,
        persistence: persistence,
        clock: clock.call,
      ).then((value) => controller = value);
      async.flushMicrotasks();

      controller.startTimer(0, const Duration(seconds: 10));
      clock.advance(const Duration(seconds: 3));
      async.elapse(const Duration(milliseconds: 250));
      expect(controller.timers[0]!.remainingSeconds, 7);

      controller.pause();
      expect(controller.isPaused, isTrue);
      expect(controller.canGoNext, isFalse);
      expect(controller.timers[0]!.status, CookTimerStatus.paused);
      clock.advance(const Duration(minutes: 5));
      async.elapse(const Duration(seconds: 1));
      expect(controller.timers[0]!.remainingSeconds, 7);

      controller.resume();
      expect(controller.timers[0]!.status, CookTimerStatus.running);
      clock.advance(const Duration(seconds: 7));
      async.elapse(const Duration(milliseconds: 250));
      expect(controller.timers[0]!.status, CookTimerStatus.completed);
      controller.dispose();
    });
  });

  test('visual alerts can be disabled', () {
    fakeAsync((async) {
      final clock = _FakeClock(DateTime.utc(2026, 1, 1));
      late CookSessionController controller;
      CookSessionController.restore(
        recipeId: 'recipe',
        baseServings: 1,
        totalSteps: 1,
        persistence: _MemoryPersistence(),
        visualAlertEnabled: false,
        clock: clock.call,
      ).then((value) => controller = value);
      async.flushMicrotasks();

      controller.startTimer(0, const Duration(seconds: 1));
      clock.advance(const Duration(seconds: 1));
      async.elapse(const Duration(milliseconds: 250));
      expect(controller.visualAlert, isNull);
      controller.dispose();
    });
  });

  test(
    'rounds partial timer seconds up and freezes timers on completion',
    () async {
      final controller = await CookSessionController.restore(
        recipeId: 'recipe',
        baseServings: 1,
        totalSteps: 1,
        persistence: _MemoryPersistence(),
      );
      controller.startTimer(0, const Duration(milliseconds: 1500));
      expect(controller.timers[0]!.totalSeconds, 2);

      controller.complete();
      expect(controller.isComplete, isTrue);
      expect(controller.timers[0]!.status, CookTimerStatus.paused);
      expect(
        () => controller.startTimer(0, const Duration(seconds: 1)),
        throwsStateError,
      );
      controller.dispose();
    },
  );

  test(
    'restore reconciles a timer that elapsed while the app was closed',
    () async {
      final now = DateTime.utc(2026, 1, 1, 12);
      final persistence = _MemoryPersistence()
        ..sessions['recipe'] = CookSessionSnapshot(
          recipeId: 'recipe',
          baseServings: 2,
          servings: 2,
          totalSteps: 2,
          currentStepIndex: 0,
          isPaused: false,
          isComplete: false,
          completedStepIndices: const <int>{},
          timers: <int, CookStepTimer>{
            0: CookStepTimer(
              totalSeconds: 30,
              remainingSeconds: 30,
              status: CookTimerStatus.running,
              endsAt: now.subtract(const Duration(seconds: 1)),
            ),
          },
        );

      final controller = await CookSessionController.restore(
        recipeId: 'recipe',
        baseServings: 2,
        totalSteps: 2,
        persistence: persistence,
        clock: () => now,
      );
      expect(controller.timers[0]!.status, CookTimerStatus.completed);
      expect(controller.visualAlert, isNull);
      await controller.flush();
      expect(
        persistence.sessions['recipe']!.timers[0]!.status,
        CookTimerStatus.completed,
      );
      controller.dispose();
    },
  );

  test('quick-next is opt-in, haptic and debounced for 300ms', () async {
    final clock = _FakeClock(DateTime.utc(2026, 1, 1));
    final haptics = _CountingHaptics();
    final session = await CookSessionController.restore(
      recipeId: 'recipe',
      baseServings: 2,
      totalSteps: 3,
      persistence: _MemoryPersistence(),
      reduceMotion: true,
      clock: clock.call,
    );
    final controller = OneHandedCookModeController(
      session: session,
      haptics: haptics,
      clock: clock.call,
    );

    expect(await controller.onStepContentTap(), isFalse);
    controller.quickNextTapEnabled = true;
    expect(controller.transitionDuration, Duration.zero);
    expect(await controller.onStepContentTap(), isTrue);
    expect(session.currentStepIndex, 1);
    expect(haptics.count, 1);

    clock.advance(const Duration(milliseconds: 299));
    expect(await controller.onStepContentTap(), isFalse);
    expect(session.currentStepIndex, 1);
    clock.advance(const Duration(milliseconds: 1));
    expect(await controller.onStepContentTap(), isTrue);
    expect(session.currentStepIndex, 2);
    expect(haptics.count, 2);

    controller.dispose();
    session.dispose();
  });

  test('discard removes persisted progress', () async {
    final persistence = _MemoryPersistence();
    final controller = await CookSessionController.restore(
      recipeId: 'recipe',
      baseServings: 2,
      totalSteps: 2,
      persistence: persistence,
    );
    controller.nextStep();
    await controller.discard();
    expect(persistence.sessions, isEmpty);
    controller.dispose();
  });
}

class _MemoryPersistence implements CookSessionPersistence {
  final Map<String, CookSessionSnapshot> sessions =
      <String, CookSessionSnapshot>{};

  @override
  Future<void> deleteCookSession(String recipeId) async {
    sessions.remove(recipeId);
  }

  @override
  Future<CookSessionSnapshot?> loadCookSession(String recipeId) async =>
      sessions[recipeId];

  @override
  Future<void> saveCookSession(CookSessionSnapshot session) async {
    sessions[session.recipeId] = session;
  }
}

class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

class _CountingHaptics implements CookHaptics {
  int count = 0;

  @override
  Future<void> quickNext() async => count++;
}
