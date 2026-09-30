import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import 'library_store.dart';

/// One-handed helpers for cook mode. With [quickNextTapEnabled], a single
/// tap on the step content advances to the next step with haptic feedback.
/// Taps within [debounce] of the last accepted one are ignored so a bumped
/// screen or a double tap doesn't skip a step.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    bool quickNextTapEnabled = false,
    this.reduceMotion = false,
    this.debounce = const Duration(milliseconds: 300),
    DateTime Function()? clock,
    Future<void> Function()? haptic,
  }) : _quickNextTapEnabled = quickNextTapEnabled,
       _clock = clock ?? DateTime.now,
       _haptic = haptic ?? HapticFeedback.selectionClick;

  bool _quickNextTapEnabled;
  bool reduceMotion;
  final Duration debounce;
  final DateTime Function() _clock;
  final Future<void> Function() _haptic;
  DateTime? _lastAccepted;

  bool get quickNextTapEnabled => _quickNextTapEnabled;
  set quickNextTapEnabled(bool v) {
    if (v == _quickNextTapEnabled) return;
    _quickNextTapEnabled = v;
    notifyListeners();
  }

  /// How long the step transition animates; zero under reduced motion.
  Duration get transitionDuration => reduceMotion ? Duration.zero : const Duration(milliseconds: 260);

  /// Returns true when the tap should advance the step.
  bool registerTap() {
    if (!_quickNextTapEnabled) return false;
    final now = _clock();
    if (_lastAccepted != null && now.difference(_lastAccepted!) < debounce) return false;
    _lastAccepted = now;
    _haptic();
    return true;
  }
}

enum TimerStatus { idle, running, paused, done }

/// Step, servings and the per-step timer of one cook-mode session.
class CookSession extends ChangeNotifier {
  CookSession({
    required this.recipe,
    required this.library,
    int? servings,
    CookProgress? resumeFrom,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       servings = resumeFrom?.servings ?? servings ?? recipe.servings,
       _step = (resumeFrom?.step ?? 0).clamp(0, recipe.steps.length - 1) {
    if (resumeFrom?.timerStep == _step && resumeFrom?.timerRemaining != null) {
      _remaining = resumeFrom!.timerRemaining!;
      _timerStatus = _remaining > 0 ? TimerStatus.paused : TimerStatus.idle;
    } else {
      _resetTimerForStep();
    }
  }

  final Recipe recipe;
  final LibraryStore library;
  final DateTime Function() _clock;
  int servings;
  int _step;
  bool _completed = false;
  Timer? _ticker;
  int _remaining = 0;
  TimerStatus _timerStatus = TimerStatus.idle;

  /// Fired once when a timer reaches zero (drives the visual alert).
  VoidCallback? onTimerDone;

  int get step => _step;
  int get stepCount => recipe.steps.length;
  RecipeStep get current => recipe.steps[_step];
  bool get isFirst => _step == 0;
  bool get isLast => _step == stepCount - 1;
  bool get completed => _completed;
  double get progress => (_step + 1) / stepCount;
  int get remaining => _remaining;
  TimerStatus get timerStatus => _timerStatus;
  bool get hasTimer => current.timerSeconds != null;

  void _resetTimerForStep() {
    _ticker?.cancel();
    _remaining = current.timerSeconds ?? 0;
    _timerStatus = TimerStatus.idle;
  }

  void next() {
    if (_completed) return;
    if (isLast) {
      complete();
      return;
    }
    _step++;
    _resetTimerForStep();
    notifyListeners();
    persist();
  }

  void previous() {
    if (_completed) {
      _completed = false;
      notifyListeners();
      return;
    }
    if (isFirst) return;
    _step--;
    _resetTimerForStep();
    notifyListeners();
    persist();
  }

  void setServings(int value) {
    servings = value.clamp(1, 24);
    notifyListeners();
    persist();
  }

  void startTimer() {
    if (!hasTimer || _remaining <= 0) return;
    _timerStatus = TimerStatus.running;
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  void pauseTimer() {
    if (_timerStatus != TimerStatus.running) return;
    _ticker?.cancel();
    _timerStatus = TimerStatus.paused;
    notifyListeners();
    persist();
  }

  void resetTimer() {
    _resetTimerForStep();
    notifyListeners();
  }

  @visibleForTesting
  void tick() {
    if (_timerStatus != TimerStatus.running) return;
    _remaining = (_remaining - 1).clamp(0, 1 << 30);
    if (_remaining == 0) {
      _ticker?.cancel();
      _timerStatus = TimerStatus.done;
      onTimerDone?.call();
    }
    notifyListeners();
  }

  /// Pause the whole session: stops the timer and stores the progress.
  Future<void> pauseSession() async {
    if (_timerStatus == TimerStatus.running) {
      _ticker?.cancel();
      _timerStatus = TimerStatus.paused;
    }
    await persist();
  }

  Future<void> persist() async {
    if (_completed) return;
    await library.saveProgress(
      CookProgress(
        recipeId: recipe.id,
        step: _step,
        servings: servings,
        updatedAt: _clock(),
        timerRemaining: hasTimer ? _remaining : null,
        timerStep: hasTimer ? _step : null,
      ),
    );
  }

  Future<void> complete() async {
    _ticker?.cancel();
    _completed = true;
    notifyListeners();
    await library.clearProgress(recipe.id);
    await library.logCooked(recipe.id, servings);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
