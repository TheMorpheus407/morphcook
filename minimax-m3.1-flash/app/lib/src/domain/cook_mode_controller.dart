import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/recipe.dart';
import '../state/local_store.dart';

/// The state of the cook mode.
///
/// Holds the current step, the running timer, the serving scaler and the
/// one-handed quick-tap switch. Progress is persisted so a cook can close
/// the app mid-recipe and pick up where they left off.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    required this.recipe,
    required KeyValueStore store,
    int? initialServings,
    int initialStep = 0,
  })  : _store = store,
        _servings = initialServings ?? recipe.servings,
        _currentStep = initialStep {
    // Opening a recipe writes the state straight away, so a cook who closes
    // the app on the first step still finds their place when they come back.
    _persist();
  }

  final Recipe recipe;
  final KeyValueStore _store;

  /// Opt-in switch for the single-tap "next step" gesture.
  bool quickNextTapEnabled = false;

  /// The minimum gap between two quick taps, in milliseconds.
  static const int quickTapDebounceMs = 300;

  int _currentStep;
  int _servings;

  Timer? _ticker;
  int _timerRemaining = 0;
  int _timerTotal = 0;
  bool _timerRunning = false;
  DateTime? _timerEndsAt;

  DateTime? _lastQuickTap;

  /// Fired when a timer reaches zero, so the UI can flash the screen.
  final StreamController<CookTimerAlert> _alerts =
      StreamController<CookTimerAlert>.broadcast();

  Stream<CookTimerAlert> get alerts => _alerts.stream;

  int get currentStep => _currentStep;

  int get stepCount => recipe.steps.length;

  int get servings => _servings;

  double get servingScale => _servings / recipe.servings;

  int get timerRemaining => _timerRemaining;

  int get timerTotal => _timerTotal;

  bool get timerRunning => _timerRunning;

  bool get hasTimer => _timerTotal > 0;

  bool get isLastStep => _currentStep >= stepCount - 1;

  RecipeStep? get step =>
      _currentStep >= 0 && _currentStep < stepCount
          ? recipe.steps[_currentStep]
          : null;

  // ── Steps ────────────────────────────────────────────────────────────────

  /// Moves to the next step. Returns false when already on the last one.
  bool next() {
    if (_currentStep >= stepCount - 1) return false;
    _currentStep++;
    _syncTimerWithStep();
    _persist();
    notifyListeners();
    return true;
  }

  /// Moves to the previous step.
  bool previous() {
    if (_currentStep <= 0) return false;
    _currentStep--;
    _syncTimerWithStep();
    _persist();
    notifyListeners();
    return true;
  }

  void jumpTo(int index) {
    if (index < 0 || index >= stepCount) return;
    _currentStep = index;
    _syncTimerWithStep();
    _persist();
    notifyListeners();
  }

  /// Handles a quick tap on the step content.
  ///
  /// Debounced to [quickTapDebounceMs] so a double tap does not skip two
  /// steps. Returns true when the step actually advanced.
  bool handleQuickTap() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    final last = _lastQuickTap;
    if (last != null &&
        now.difference(last).inMilliseconds < quickTapDebounceMs) {
      return false;
    }
    _lastQuickTap = now;
    return next();
  }

  // ── Servings ─────────────────────────────────────────────────────────────

  void scaleServings(int delta) {
    final next = (_servings + delta).clamp(1, 24);
    if (next == _servings) return;
    _servings = next;
    _persist();
    notifyListeners();
  }

  void setServings(int value) {
    final next = value.clamp(1, 24);
    if (next == _servings) return;
    _servings = next;
    _persist();
    notifyListeners();
  }

  /// The ingredient quantity for the current serving scale.
  double scaledQuantity(double quantity) => quantity * servingScale;

  // ── Timer ────────────────────────────────────────────────────────────────

  void _syncTimerWithStep() {
    _stopTicker();
    final step = this.step;
    final seconds = step?.timerSeconds ?? 0;
    _timerTotal = seconds;
    _timerRemaining = seconds;
    _timerRunning = false;
    _timerEndsAt = null;
  }

  void startTimer([int? seconds]) {
    final total = seconds ?? _timerTotal;
    if (total <= 0) return;
    _timerTotal = total;
    _timerRemaining = total;
    _timerEndsAt = DateTime.now().add(Duration(seconds: total));
    _timerRunning = true;
    _startTicker();
    notifyListeners();
  }

  void pauseTimer() {
    if (!_timerRunning) return;
    _timerRunning = false;
    _timerEndsAt = null;
    _stopTicker();
    _persist();
    notifyListeners();
  }

  void resumeTimer() {
    if (_timerRunning || _timerRemaining <= 0) return;
    _timerEndsAt = DateTime.now().add(Duration(seconds: _timerRemaining));
    _timerRunning = true;
    _startTicker();
    notifyListeners();
  }

  void resetTimer() {
    _stopTicker();
    _timerRemaining = _timerTotal;
    _timerRunning = false;
    _timerEndsAt = null;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final endsAt = _timerEndsAt;
      if (endsAt == null) return;
      final remaining = endsAt.difference(DateTime.now()).inSeconds + 1;
      if (remaining <= 0) {
        _timerRemaining = 0;
        _timerRunning = false;
        _timerEndsAt = null;
        _stopTicker();
        _persist();
        _alerts.add(CookTimerAlert(recipeId: recipe.id));
        notifyListeners();
        return;
      }
      _timerRemaining = remaining;
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  // ── Persistence ──────────────────────────────────────────────────────────

  void _persist() {
    _store.writeMap(StoreKeys.cookProgress, <String, dynamic>{
      'recipe_id': recipe.id,
      'step': _currentStep,
      'servings': _servings,
      'timer_remaining': _timerRemaining,
      'timer_total': _timerTotal,
      'saved_at': DateTime.now().toIso8601String(),
    });
  }

  /// Restores a saved progress block for [recipeId], if there is one.
  static Map<String, dynamic>? restore(KeyValueStore store, String recipeId) {
    final raw = store.readMap(StoreKeys.cookProgress);
    if (raw.isEmpty) return null;
    if ('${raw['recipe_id']}' != recipeId) return null;
    return raw;
  }

  static void clear(KeyValueStore store) => store.delete(StoreKeys.cookProgress);

  @override
  void dispose() {
    _stopTicker();
    _alerts.close();
    super.dispose();
  }
}

/// Emitted when a cook-mode timer finishes.
class CookTimerAlert {
  const CookTimerAlert({required this.recipeId});
  final String recipeId;
}
