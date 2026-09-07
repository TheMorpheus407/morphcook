// Cook mode state: steps, per-step timer, servings scaler, pause/resume
// with progress persistence, completion, visual alert on timer end, and
// the opt-in one-handed quick-next tap.
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/recipe.dart';

class CookProgress {
  const CookProgress({
    required this.recipeId,
    required this.stepIndex,
    required this.servings,
    required this.updatedAt,
    this.timerRemaining,
    this.timerTotal,
    this.timerRunning = false,
  });

  final String recipeId;
  final int stepIndex;
  final int servings;
  final DateTime updatedAt;
  final int? timerRemaining;
  final int? timerTotal;
  final bool timerRunning;

  Map<String, dynamic> toJson() => {
        'recipe_id': recipeId,
        'step_index': stepIndex,
        'servings': servings,
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'timer_remaining': timerRemaining,
        'timer_total': timerTotal,
        'timer_running': timerRunning,
      };

  factory CookProgress.fromJson(Map<String, dynamic> j) => CookProgress(
        recipeId: j['recipe_id'] as String,
        stepIndex: ((j['step_index'] as num?) ?? 0).toInt(),
        servings: ((j['servings'] as num?) ?? 2).toInt(),
        updatedAt: DateTime.tryParse((j['updated_at'] as String?) ?? '')?.toLocal() ?? DateTime.now(),
        timerRemaining: (j['timer_remaining'] as num?)?.toInt(),
        timerTotal: (j['timer_total'] as num?)?.toInt(),
        timerRunning: (j['timer_running'] as bool?) ?? false,
      );
}

class StepTimer {
  StepTimer({required this.total, required this.remaining, this.running = false});
  final int total;
  int remaining;
  bool running;
  bool get done => remaining <= 0;
  double get progress => total == 0 ? 1 : 1 - remaining / total;
}

class CookModeController extends ChangeNotifier {
  CookModeController({
    required this.recipe,
    int? servings,
    CookProgress? resume,
    this.onProgress,
    this.tickInterval = const Duration(seconds: 1),
  })  : _servings = servings ?? resume?.servings ?? recipe.servings,
        _step = (resume?.stepIndex ?? 0).clamp(0, recipe.steps.isEmpty ? 0 : recipe.steps.length - 1) {
    if (resume?.timerTotal != null) {
      _timer = StepTimer(total: resume!.timerTotal!, remaining: resume.timerRemaining ?? resume.timerTotal!, running: false);
    } else {
      _timer = _timerForStep(_step);
    }
  }

  final Recipe recipe;
  final void Function(CookProgress)? onProgress;
  final Duration tickInterval;

  int _step;
  int _servings;
  StepTimer? _timer;
  Timer? _ticker;
  bool _paused = false;
  bool _completed = false;
  int _alertCount = 0;

  int get stepIndex => _step;
  int get stepCount => recipe.steps.length;
  RecipeStep? get step => recipe.steps.isEmpty ? null : recipe.steps[_step];
  int get servings => _servings;
  double get scale => recipe.servings == 0 ? 1 : _servings / recipe.servings;
  StepTimer? get timer => _timer;
  bool get paused => _paused;
  bool get completed => _completed;
  bool get isFirst => _step == 0;
  bool get isLast => recipe.steps.isEmpty || _step == recipe.steps.length - 1;
  double get progress => stepCount == 0 ? 0 : (_step + 1) / stepCount;

  /// Increments every time a timer finishes; the UI flashes on change.
  int get alertCount => _alertCount;

  List<RecipeIngredient> get scaledIngredients => [for (final i in recipe.ingredients) i.scaled(scale)];

  StepTimer? _timerForStep(int i) {
    if (i < 0 || i >= recipe.steps.length) return null;
    final s = recipe.steps[i].timerSeconds;
    return s == null ? null : StepTimer(total: s, remaining: s);
  }

  CookProgress snapshot() => CookProgress(
        recipeId: recipe.id,
        stepIndex: _step,
        servings: _servings,
        updatedAt: DateTime.now(),
        timerRemaining: _timer?.remaining,
        timerTotal: _timer?.total,
        timerRunning: _timer?.running ?? false,
      );

  void _persist() => onProgress?.call(snapshot());

  void goTo(int index) {
    if (recipe.steps.isEmpty) return;
    final next = index.clamp(0, recipe.steps.length - 1);
    if (next == _step) return;
    _stopTicker();
    _step = next;
    _timer = _timerForStep(_step);
    _persist();
    notifyListeners();
  }

  /// Returns true when the step actually advanced.
  bool next() {
    if (isLast) return false;
    goTo(_step + 1);
    return true;
  }

  bool prev() {
    if (isFirst) return false;
    goTo(_step - 1);
    return true;
  }

  void setServings(int n) {
    final v = n.clamp(1, 24);
    if (v == _servings) return;
    _servings = v;
    _persist();
    notifyListeners();
  }

  void startTimer([int? seconds]) {
    final total = seconds ?? _timer?.total ?? step?.timerSeconds;
    if (total == null || total <= 0) return;
    _timer = StepTimer(total: total, remaining: _timer != null && _timer!.total == total && !_timer!.done ? _timer!.remaining : total, running: true);
    _paused = false;
    _startTicker();
    _persist();
    notifyListeners();
  }

  void pauseTimer() {
    if (_timer == null || !_timer!.running) return;
    _timer!.running = false;
    _stopTicker();
    _persist();
    notifyListeners();
  }

  void resumeTimer() {
    if (_timer == null || _timer!.running || _timer!.done) return;
    _timer!.running = true;
    _paused = false;
    _startTicker();
    _persist();
    notifyListeners();
  }

  void resetTimer() {
    _stopTicker();
    _timer = _timerForStep(_step);
    _persist();
    notifyListeners();
  }

  void adjustTimer(int deltaSeconds) {
    final t = _timer;
    if (t == null) return;
    t.remaining = (t.remaining + deltaSeconds).clamp(0, 24 * 3600);
    _persist();
    notifyListeners();
  }

  /// Session-level pause: freezes the timer and marks the session paused so
  /// the progress can be resumed later (persisted via [onProgress]).
  void pauseSession() {
    _paused = true;
    if (_timer?.running ?? false) {
      _timer!.running = false;
      _stopTicker();
    }
    _persist();
    notifyListeners();
  }

  void resumeSession() {
    _paused = false;
    notifyListeners();
  }

  void complete() {
    _stopTicker();
    _completed = true;
    notifyListeners();
  }

  /// Advances the timer by [elapsed]. Public so tests can drive time.
  void tick([Duration? elapsed]) {
    final t = _timer;
    if (t == null || !t.running) return;
    final secs = (elapsed ?? tickInterval).inSeconds;
    t.remaining = (t.remaining - secs).clamp(0, t.total);
    if (t.done) {
      t.running = false;
      _stopTicker();
      _alertCount++;
      _persist();
    }
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(tickInterval, (_) => tick());
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

/// One-handed cook mode: a single tap on the step content advances to the
/// next step, with haptic feedback and a 300 ms debounce. Opt-in.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({bool quickNextTapEnabled = false, this.debounce = const Duration(milliseconds: 300)})
      : _enabled = quickNextTapEnabled;

  final Duration debounce;
  bool _enabled;
  DateTime? _lastTap;

  bool get quickNextTapEnabled => _enabled;
  set quickNextTapEnabled(bool v) {
    if (v == _enabled) return;
    _enabled = v;
    notifyListeners();
  }

  /// Returns true when the tap advanced the step. [now] is injectable for
  /// tests; [haptic] runs only on a successful advance.
  bool handleTap(CookModeController cook, {DateTime? now, VoidCallback? haptic}) {
    if (!_enabled) return false;
    final t = now ?? DateTime.now();
    final last = _lastTap;
    if (last != null && t.difference(last) < debounce) return false;
    _lastTap = t;
    final advanced = cook.next();
    if (advanced) haptic?.call();
    return advanced;
  }
}
