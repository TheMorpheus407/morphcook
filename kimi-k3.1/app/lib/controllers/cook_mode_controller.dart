import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../models/user_data.dart';

class OneHandedCookModeController {
  OneHandedCookModeController({
    required this.quickNextTapEnabled,
    required this.reduceMotion,
    required this.onNext,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  final bool quickNextTapEnabled;
  final bool reduceMotion;
  final VoidCallback onNext;
  final DateTime Function() clock;
  DateTime? lastTap;

  bool handleTap() {
    if (!quickNextTapEnabled || reduceMotion) return false;
    final now = clock();
    if (lastTap != null &&
        now.difference(lastTap!) < const Duration(milliseconds: 300)) {
      return false;
    }
    lastTap = now;
    unawaited(HapticFeedback.selectionClick());
    onNext();
    return true;
  }
}

class CookModeController extends ChangeNotifier {
  CookModeController({
    required this.recipe,
    required CookProgress? initialProgress,
    required this.onPersist,
    required this.onCompleted,
    this.visualAlertEnabled = true,
    this.reduceMotion = false,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now {
    servings = initialProgress?.servings.clamp(1, 12) ?? recipe.servings;
    stepIndex =
        initialProgress?.stepIndex.clamp(0, recipe.steps.length - 1) ?? 0;
    remainingSeconds =
        initialProgress?.remainingSeconds ??
        recipe.steps[stepIndex].timerSeconds ??
        0;
    isRunning = initialProgress?.isRunning ?? false;
    if (isRunning && initialProgress != null) {
      final elapsed = this
          .clock()
          .difference(initialProgress.updatedAt)
          .inSeconds;
      remainingSeconds = (remainingSeconds - elapsed).clamp(
        0,
        remainingSeconds,
      );
      if (remainingSeconds == 0 && currentTimerSeconds > 0) {
        isRunning = false;
        _showTimerAlert();
      }
    }
    if (isRunning && currentTimerSeconds > 0) _startTicker();
    quickNext = OneHandedCookModeController(
      quickNextTapEnabled: false,
      reduceMotion: reduceMotion,
      onNext: next,
      clock: this.clock,
    );
  }

  final Recipe recipe;
  final void Function(CookProgress progress, bool notify) onPersist;
  final void Function(String recipeId, int servings) onCompleted;
  final bool visualAlertEnabled;
  final bool reduceMotion;
  final DateTime Function() clock;
  late OneHandedCookModeController quickNext;
  late int stepIndex;
  late int remainingSeconds;
  late int servings;
  bool isRunning = false;
  bool completed = false;
  bool alertVisible = false;
  int alertPhase = 0;
  Timer? ticker;
  Timer? alertTicker;
  int _persistTicks = 0;

  int get currentTimerSeconds => recipe.steps[stepIndex].timerSeconds ?? 0;
  double get progress => completed ? 1 : stepIndex / recipe.steps.length;
  bool get canGoBack => stepIndex > 0 && !completed;

  void configureQuickNext(bool enabled) {
    quickNext = OneHandedCookModeController(
      quickNextTapEnabled: enabled,
      reduceMotion: reduceMotion,
      onNext: next,
      clock: clock,
    );
  }

  void next() {
    alertVisible = false;
    alertTicker?.cancel();
    if (stepIndex >= recipe.steps.length - 1) {
      if (!completed) {
        completed = true;
        isRunning = false;
        ticker?.cancel();
        onCompleted(recipe.id, servings);
      }
    } else {
      stepIndex++;
      remainingSeconds = currentTimerSeconds;
      isRunning = false;
      ticker?.cancel();
      _persist();
    }
    notifyListeners();
  }

  void previous() {
    if (!canGoBack) return;
    stepIndex--;
    remainingSeconds = currentTimerSeconds;
    isRunning = false;
    ticker?.cancel();
    alertVisible = false;
    _persist();
    notifyListeners();
  }

  void toggleTimer() => isRunning ? pause() : resume();

  void resume() {
    if (currentTimerSeconds <= 0 || completed) return;
    if (remainingSeconds <= 0) remainingSeconds = currentTimerSeconds;
    isRunning = true;
    alertVisible = false;
    alertTicker?.cancel();
    _startTicker();
    _persist();
    notifyListeners();
  }

  void pause() {
    isRunning = false;
    ticker?.cancel();
    _persist();
    notifyListeners();
  }

  void resetTimer() {
    isRunning = false;
    ticker?.cancel();
    remainingSeconds = currentTimerSeconds;
    alertVisible = false;
    alertTicker?.cancel();
    _persist();
    notifyListeners();
  }

  void setServings(int value) {
    servings = value.clamp(1, 12);
    _persist();
    notifyListeners();
  }

  void dismissAlert() {
    alertVisible = false;
    alertTicker?.cancel();
    notifyListeners();
  }

  void _startTicker() {
    ticker?.cancel();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!isRunning) return;
    remainingSeconds = (remainingSeconds - 1).clamp(0, currentTimerSeconds);
    if (remainingSeconds == 0) {
      isRunning = false;
      ticker?.cancel();
      _showTimerAlert();
      _persist();
    } else if (++_persistTicks >= 5) {
      _persistTicks = 0;
      _persist(notify: false);
    }
    notifyListeners();
  }

  void _showTimerAlert() {
    if (!visualAlertEnabled) return;
    alertVisible = true;
    alertPhase = 0;
    alertTicker?.cancel();
    if (!reduceMotion) {
      alertTicker = Timer.periodic(const Duration(milliseconds: 350), (timer) {
        alertPhase++;
        if (alertPhase >= 8) {
          alertTicker?.cancel();
          alertPhase = 0;
        }
        notifyListeners();
      });
    }
  }

  void _persist({bool notify = true}) {
    onPersist(
      CookProgress(
        recipeId: recipe.id,
        stepIndex: stepIndex,
        remainingSeconds: remainingSeconds,
        servings: servings,
        isRunning: isRunning,
        updatedAt: clock().toUtc(),
      ),
      notify,
    );
  }

  @override
  void dispose() {
    if (isRunning) _persist();
    ticker?.cancel();
    alertTicker?.cancel();
    super.dispose();
  }
}
