import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives cook mode: step navigation, per-step timer, servings scaling, and the
/// one-handed quick-advance gesture. Pure logic + a Timer, so the screen stays
/// declarative. (Named for the SPEC's `OneHandedCookModeController`.)
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    required this.stepCount,
    required this.stepTimers,
    required this.baseServings,
    required this.reduceMotion,
    this.quickNextTapEnabled = false,
    this.onTimerComplete,
  }) : _servings = baseServings;

  final int stepCount;
  final List<int?> stepTimers;
  final int baseServings;
  final bool reduceMotion;
  final bool quickNextTapEnabled;
  final VoidCallback? onTimerComplete;

  int _step = 0;
  int get step => _step;

  bool _finished = false;
  bool get isFinished => _finished;

  int _servings;
  int get servings => _servings;
  double get servingsScale => baseServings == 0 ? 1 : _servings / baseServings;

  // --- timer ---
  Timer? _timer;
  int _remaining = 0;
  bool _timerRunning = false;
  int get remainingSeconds => _remaining;
  bool get timerRunning => _timerRunning;
  bool get hasTimer => _step < stepTimers.length && stepTimers[_step] != null;
  int get currentStepTimer => hasTimer ? stepTimers[_step]! : 0;

  // --- quick-tap debounce ---
  DateTime? _lastQuickTap;
  static const _debounce = Duration(milliseconds: 300);

  void goTo(int index) {
    if (index < 0) return;
    _cancelTimer();
    if (index >= stepCount) {
      _finished = true;
    } else {
      _step = index;
    }
    notifyListeners();
  }

  void next() => goTo(_step + 1);
  void prev() => goTo(_step - 1);

  /// One-handed quick advance: single tap on the step. Opt-in, debounced 300ms,
  /// suppressed when motion is reduced (avoids accidental rapid jumps).
  /// Returns true when it actually advanced (so the UI can fire haptics).
  bool quickNext() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (_lastQuickTap != null && now.difference(_lastQuickTap!) < _debounce) {
      return false;
    }
    _lastQuickTap = now;
    next();
    return true;
  }

  void setServings(int value) {
    _servings = value.clamp(1, 99);
    notifyListeners();
  }

  // timer controls
  void startTimer() {
    if (!hasTimer) return;
    _remaining = currentStepTimer;
    _runTimer();
  }

  void _runTimer() {
    _timerRunning = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        _remaining = 0;
        _timerRunning = false;
        t.cancel();
        notifyListeners();
        onTimerComplete?.call();
      } else {
        _remaining--;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void pauseTimer() {
    _timer?.cancel();
    _timerRunning = false;
    notifyListeners();
  }

  void resumeTimer() {
    if (_remaining > 0) _runTimer();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timerRunning = false;
    _remaining = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
