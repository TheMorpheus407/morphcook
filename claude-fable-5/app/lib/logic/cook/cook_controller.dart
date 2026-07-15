import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/recipe.dart';

const maxCookServings = 1000;

/// Persisted cook-mode progress so an interrupted session can resume.
class CookProgress {
  final String recipeId;
  final int stepIndex;
  final int servings;
  final int? remainingTimerSeconds;

  const CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    this.remainingTimerSeconds,
  });

  Map<String, dynamic> toJson() => {
    'recipe_id': recipeId,
    'step_index': stepIndex,
    'servings': servings,
    'remaining_timer_seconds': remainingTimerSeconds,
  };

  factory CookProgress.fromJson(Map<String, dynamic> json) => CookProgress(
    recipeId: json['recipe_id'] as String,
    stepIndex: json['step_index'] as int,
    servings: json['servings'] as int,
    remainingTimerSeconds: json['remaining_timer_seconds'] as int?,
  );
}

/// Drives a cook-mode session: step navigation, per-step timer with
/// pause/resume, servings scaling, progress persistence, completion.
class CookSessionController extends ChangeNotifier {
  final Recipe recipe;
  final void Function(CookProgress?) persist;

  CookSessionController({
    required this.recipe,
    required this.persist,
    CookProgress? resumeFrom,
    int? servings,
  }) : _servings = _validServings(
         servings ?? resumeFrom?.servings ?? recipe.servings,
         recipe.servings,
       ),
       _stepIndex = _validStepIndex(
         resumeFrom?.stepIndex,
         recipe.steps.length,
       ) {
    final resumeSeconds = resumeFrom?.remainingTimerSeconds;
    final resumeMatches =
        resumeFrom?.recipeId == recipe.id &&
        resumeFrom?.stepIndex == _stepIndex;
    if (resumeMatches && resumeSeconds != null && resumeSeconds > 0) {
      _remainingSeconds = resumeSeconds;
      _paused = true;
    } else {
      _resetTimerForStep();
    }
  }

  int _stepIndex;
  int _servings;
  int? _remainingSeconds;
  bool _running = false;
  bool _paused = false;
  bool _completed = false;
  bool _timerJustFinished = false;
  Timer? _ticker;

  int get stepIndex => _stepIndex;
  int get servings => _servings;
  bool get isCompleted => _completed;
  bool get isTimerRunning => _running;
  bool get isTimerPaused => _paused;
  int? get remainingSeconds => _remainingSeconds;
  bool get isLastStep => _stepIndex >= recipe.steps.length - 1;

  /// Set once when a timer reaches zero; the UI consumes it to trigger the
  /// visual flash alert (accessibility) and clears it via [consumeTimerAlert].
  bool get timerJustFinished => _timerJustFinished;

  /// Scale factor relative to the authored servings.
  double get scaleFactor => _servings / recipe.servings;

  void setServings(int value) {
    if (value < 1 || value > maxCookServings) return;
    _servings = value;
    _persistNow();
    notifyListeners();
  }

  void _resetTimerForStep() {
    _stopTicker();
    final minutes = recipe.steps[_stepIndex].timerMinutes;
    _remainingSeconds = minutes == null ? null : minutes * 60;
    _running = false;
    _paused = false;
  }

  void startTimer() {
    if (_remainingSeconds == null || _running) return;
    _running = true;
    _paused = false;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  void pauseTimer() {
    if (!_running) return;
    _stopTicker();
    _running = false;
    _paused = true;
    _persistNow();
    notifyListeners();
  }

  void resumeTimer() {
    if (!_paused || _remainingSeconds == null) return;
    startTimer();
  }

  /// Advances the countdown by one second (also called by tests directly).
  void tick() {
    final remaining = _remainingSeconds;
    if (!_running || remaining == null) return;
    if (remaining <= 1) {
      _remainingSeconds = 0;
      _stopTicker();
      _running = false;
      _timerJustFinished = true;
    } else {
      _remainingSeconds = remaining - 1;
    }
    notifyListeners();
  }

  void consumeTimerAlert() {
    _timerJustFinished = false;
  }

  bool nextStep() {
    if (isLastStep) {
      complete();
      return false;
    }
    _stepIndex++;
    _resetTimerForStep();
    _persistNow();
    notifyListeners();
    return true;
  }

  void previousStep() {
    if (_stepIndex == 0) return;
    _stepIndex--;
    _resetTimerForStep();
    _persistNow();
    notifyListeners();
  }

  void complete() {
    _stopTicker();
    _completed = true;
    persist(null); // session finished — clear saved progress
    notifyListeners();
  }

  void _persistNow() {
    persist(
      CookProgress(
        recipeId: recipe.id,
        stepIndex: _stepIndex,
        servings: _servings,
        remainingTimerSeconds: _remainingSeconds,
      ),
    );
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}

int _validStepIndex(int? requested, int stepCount) {
  if (stepCount <= 1 || requested == null || requested < 0) return 0;
  return requested < stepCount ? requested : stepCount - 1;
}

int _validServings(int requested, int fallback) =>
    requested >= 1 && requested <= maxCookServings ? requested : fallback;

/// One-handed cook mode: a single tap on the step content advances to the
/// next step. Opt-in via [quickNextTapEnabled]; a 300 ms debounce prevents
/// accidental double-triggers. Haptics and motion are the caller's concern
/// (it must respect reduceMotion).
class OneHandedCookModeController {
  bool quickNextTapEnabled;

  /// Injected clock for tests.
  final DateTime Function() now;

  OneHandedCookModeController({
    this.quickNextTapEnabled = false,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const debounce = Duration(milliseconds: 300);

  DateTime? _lastAccepted;

  /// Returns true when the tap should advance to the next step.
  bool handleTap() {
    if (!quickNextTapEnabled) return false;
    final t = now();
    final last = _lastAccepted;
    if (last != null && t.difference(last) < debounce) return false;
    _lastAccepted = t;
    return true;
  }
}
