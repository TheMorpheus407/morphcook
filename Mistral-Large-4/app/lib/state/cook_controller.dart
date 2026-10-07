import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/model/recipe.dart';
import 'storage.dart';

/// Cook mode state: step-by-step, per-step timer, servings scaler,
/// pause/resume with progress persistence.
///
/// The one-handed controller: when [quickNextTapEnabled] is on (opt-in), a
/// single tap on the step content advances to the next step with haptic
/// feedback, debounced by 300 ms. Both the quick-tap gesture and the visual
/// timer alert respect the reduce-motion preference.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    required this.recipe,
    this.reduceMotion = false,
    this.visualAlertEnabled = true,
    this.quickNextTapEnabled = false,
    this.onFinished,
    this.onExited,
    this.persistProgress = true,
  }) : _servings = recipe.servings {
    _restore();
  }

  final Recipe recipe;
  final bool reduceMotion;
  final bool visualAlertEnabled;

  /// Opt-in: single tap on step content advances to the next step.
  bool quickNextTapEnabled;

  final VoidCallback? onFinished;
  final VoidCallback? onExited;

  /// Pause/resume with progress persistence.
  final bool persistProgress;

  static const Duration quickTapDebounce = Duration(milliseconds: 300);

  int _step = 0;
  late int _servings;
  Timer? _ticker;
  int? _remainingSeconds;
  bool _running = false;
  bool _paused = false;
  bool _finished = false;
  DateTime? _lastQuickTap;

  /// 0..1 — set when the timer completes, drives the coral/teal flash.
  final ValueNotifier<double> flash = ValueNotifier<double>(0);

  int get step => _step;
  int get stepCount => recipe.steps.length;
  int get servings => _servings;
  bool get isRunning => _running;
  bool get isPaused => _paused;
  bool get isFinished => _finished;
  int? get remainingSeconds => _remainingSeconds;
  int? get stepTimerMinutes => recipe.steps[_step].timerMinutes;
  bool get hasTimer => stepTimerMinutes != null;

  CookStep get currentStep => recipe.steps[_step];

  List<IngredientLine> get scaledIngredients {
    final factor = _servings / recipe.servings;
    return recipe.ingredients
        .map((l) => IngredientLine(
              ingredientId: l.ingredientId,
              amount: l.amount * factor,
              unit: l.unit,
              note: l.note,
            ))
        .toList();
  }

  void _restore() {
    if (!persistProgress) return;
    final saved = AppStorage.cookProgressBox.get(recipe.id);
    if (saved is Map) {
      final step = saved['step'] as int? ?? 0;
      _step = step.clamp(0, stepCount - 1);
      _servings = (saved['servings'] as int? ?? recipe.servings).clamp(1, 99);
      final remaining = saved['remaining_seconds'] as int?;
      final paused = saved['paused'] as bool? ?? false;
      if (remaining != null && !paused) {
        // Resume a running timer where it left off.
        _remainingSeconds = remaining;
        _running = true;
        _paused = false;
        _startTicker();
      } else if (remaining != null) {
        _remainingSeconds = remaining;
      }
    }
  }

  Future<void> _persist() async {
    if (!persistProgress) return;
    await AppStorage.cookProgressBox.put(recipe.id, {
      'recipe_id': recipe.id,
      'step': _step,
      'servings': _servings,
      'remaining_seconds': _remainingSeconds,
      'paused': _paused,
      'running': _running,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ── servings ──────────────────────────────────────────────────────────

  void setServings(int servings) {
    _servings = servings.clamp(1, 99);
    _persist();
    notifyListeners();
  }

  // ── navigation ────────────────────────────────────────────────────────

  void next() {
    if (_step < stepCount - 1) {
      _step += 1;
      _resetTimer();
      _persist();
      notifyListeners();
    } else {
      finish();
    }
  }

  void previous() {
    if (_step > 0) {
      _step -= 1;
      _resetTimer();
      _persist();
      notifyListeners();
    }
  }

  void goTo(int step) {
    _step = step.clamp(0, stepCount - 1);
    _resetTimer();
    _persist();
    notifyListeners();
  }

  void finish() {
    if (_finished) return;
    _finished = true;
    _stopTicker();
    _persist();
    onFinished?.call();
    notifyListeners();
  }

  void exit() {
    _stopTicker();
    onExited?.call();
  }

  /// Quick-tap gesture: single tap on the step content advances to the next
  /// step with haptic feedback. Opt-in via [quickNextTapEnabled]; debounced
  /// by 300 ms to prevent accidental triggers.
  bool quickTapAdvance() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (_lastQuickTap != null && now.difference(_lastQuickTap!) < quickTapDebounce) {
      return false;
    }
    _lastQuickTap = now;
    if (!reduceMotion) {
      HapticFeedback.lightImpact();
    }
    next();
    return true;
  }

  // ── timer ─────────────────────────────────────────────────────────────

  void startTimer() {
    if (!hasTimer) return;
    _remainingSeconds ??= stepTimerMinutes! * 60;
    _running = true;
    _paused = false;
    _wakelock(true);
    _startTicker();
    _persist();
    notifyListeners();
  }

  void pauseTimer() {
    if (!_running || _paused) return;
    _paused = true;
    _stopTicker();
    _wakelock(false);
    _persist();
    notifyListeners();
  }

  void resumeTimer() {
    if (!_running || !_paused) return;
    _paused = false;
    _wakelock(true);
    _startTicker();
    _persist();
    notifyListeners();
  }

  /// Wakelock is best-effort — unsupported platforms (and tests) must not
  /// crash cook mode over it. The platform call fails asynchronously, so the
  /// future is ignored rather than awaited.
  void _wakelock(bool enable) {
    try {
      (enable ? WakelockPlus.enable() : WakelockPlus.disable()).ignore();
    } catch (_) {
      // ignored
    }
  }

  void _resetTimer() {
    _stopTicker();
    _remainingSeconds = null;
    _running = false;
    _paused = false;
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds == null) return;
      if (_remainingSeconds! <= 1) {
        _remainingSeconds = 0;
        _onTimerComplete();
      } else {
        _remainingSeconds = _remainingSeconds! - 1;
        if (_remainingSeconds! % 5 == 0) _persist();
        notifyListeners();
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTimerComplete() {
    _stopTicker();
    _running = false;
    _paused = false;
    if (!reduceMotion) {
      HapticFeedback.heavyImpact();
    }
    if (visualAlertEnabled) {
      flash.value = 1.0;
    }
    _persist();
    notifyListeners();
  }

  /// Called by the flash animation when it settles back to zero.
  void clearFlash() {
    flash.value = 0.0;
  }

  String formatRemaining() {
    final s = _remainingSeconds ?? 0;
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopTicker();
    _wakelock(false);
    flash.dispose();
    super.dispose();
  }
}
