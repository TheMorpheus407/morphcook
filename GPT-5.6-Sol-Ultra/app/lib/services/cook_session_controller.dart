import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum CookTimerStatus { running, paused, completed }

enum TimerAlertTone { coral, teal }

class CookStepTimer {
  const CookStepTimer({
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.status,
    this.endsAt,
  }) : assert(totalSeconds >= 0),
       assert(remainingSeconds >= 0);

  factory CookStepTimer.fromJson(Map<String, dynamic> json) => CookStepTimer(
    totalSeconds: json['total_seconds'] as int,
    remainingSeconds: json['remaining_seconds'] as int,
    status: CookTimerStatus.values.byName(json['status'] as String),
    endsAt: json['ends_at'] == null
        ? null
        : DateTime.parse(json['ends_at'] as String).toUtc(),
  );

  final int totalSeconds;
  final int remainingSeconds;
  final CookTimerStatus status;
  final DateTime? endsAt;

  CookStepTimer copyWith({
    int? totalSeconds,
    int? remainingSeconds,
    CookTimerStatus? status,
    DateTime? endsAt,
    bool clearEndsAt = false,
  }) => CookStepTimer(
    totalSeconds: totalSeconds ?? this.totalSeconds,
    remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    status: status ?? this.status,
    endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total_seconds': totalSeconds,
    'remaining_seconds': remainingSeconds,
    'status': status.name,
    if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CookStepTimer &&
          totalSeconds == other.totalSeconds &&
          remainingSeconds == other.remainingSeconds &&
          status == other.status &&
          endsAt == other.endsAt;

  @override
  int get hashCode =>
      Object.hash(totalSeconds, remainingSeconds, status, endsAt);
}

class CookSessionSnapshot {
  CookSessionSnapshot({
    required this.recipeId,
    required this.baseServings,
    required this.servings,
    required this.totalSteps,
    required this.currentStepIndex,
    required this.isPaused,
    required this.isComplete,
    required Iterable<int> completedStepIndices,
    required Map<int, CookStepTimer> timers,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : completedStepIndices = Set<int>.unmodifiable(completedStepIndices),
       timers = Map<int, CookStepTimer>.unmodifiable(timers),
       createdAt = (createdAt ?? updatedAt ?? DateTime.now()).toUtc(),
       updatedAt = (updatedAt ?? DateTime.now()).toUtc(),
       assert(baseServings > 0),
       assert(servings > 0),
       assert(totalSteps > 0),
       assert(currentStepIndex >= 0 && currentStepIndex < totalSteps);

  factory CookSessionSnapshot.fresh({
    required String recipeId,
    required double baseServings,
    required int totalSteps,
  }) => CookSessionSnapshot(
    recipeId: recipeId,
    baseServings: baseServings,
    servings: baseServings,
    totalSteps: totalSteps,
    currentStepIndex: 0,
    isPaused: false,
    isComplete: false,
    completedStepIndices: const <int>{},
    timers: const <int, CookStepTimer>{},
  );

  factory CookSessionSnapshot.fromJson(Map<String, dynamic> json) {
    final timerMap = json['timers'] as Map<dynamic, dynamic>? ?? const {};
    return CookSessionSnapshot(
      recipeId: json['recipe_id'] as String,
      baseServings: (json['base_servings'] as num).toDouble(),
      servings: (json['servings'] as num).toDouble(),
      totalSteps: json['total_steps'] as int,
      currentStepIndex: json['current_step_index'] as int,
      isPaused: json['is_paused'] as bool? ?? false,
      isComplete: json['is_complete'] as bool? ?? false,
      completedStepIndices:
          (json['completed_step_indices'] as List<dynamic>? ?? const [])
              .cast<int>(),
      timers: timerMap.map(
        (key, value) => MapEntry(
          int.parse(key.toString()),
          CookStepTimer.fromJson(
            (value as Map).map(
              (timerKey, timerValue) =>
                  MapEntry(timerKey.toString(), timerValue),
            ),
          ),
        ),
      ),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String recipeId;
  final double baseServings;
  final double servings;
  final int totalSteps;
  final int currentStepIndex;
  final bool isPaused;
  final bool isComplete;
  final Set<int> completedStepIndices;
  final Map<int, CookStepTimer> timers;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'recipe_id': recipeId,
    'base_servings': baseServings,
    'servings': servings,
    'total_steps': totalSteps,
    'current_step_index': currentStepIndex,
    'is_paused': isPaused,
    'is_complete': isComplete,
    'completed_step_indices': completedStepIndices.toList()..sort(),
    'timers': timers.map(
      (key, value) => MapEntry(key.toString(), value.toJson()),
    ),
    'created_at': createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };
}

abstract interface class CookSessionPersistence {
  Future<CookSessionSnapshot?> loadCookSession(String recipeId);
  Future<void> saveCookSession(CookSessionSnapshot session);
  Future<void> deleteCookSession(String recipeId);
}

abstract interface class CookHaptics {
  Future<void> quickNext();
}

class FlutterCookHaptics implements CookHaptics {
  const FlutterCookHaptics();

  @override
  Future<void> quickNext() => HapticFeedback.selectionClick();
}

class NoopCookHaptics implements CookHaptics {
  const NoopCookHaptics();

  @override
  Future<void> quickNext() async {}
}

class TimerVisualAlert {
  const TimerVisualAlert({
    required this.tone,
    required this.shouldAnimate,
    required this.stepIndex,
  });

  final TimerAlertTone tone;
  final bool shouldAnimate;
  final int stepIndex;
}

typedef CookClock = DateTime Function();

/// Persistent cook-mode state, servings scaling and independent step timers.
class CookSessionController extends ChangeNotifier {
  CookSessionController._({
    required CookSessionSnapshot snapshot,
    required CookSessionPersistence persistence,
    required bool visualAlertEnabled,
    required bool reduceMotion,
    required bool restoredFromPersistence,
    required CookClock clock,
    void Function(int stepIndex)? onTimerCompleted,
  }) : _recipeId = snapshot.recipeId,
       _baseServings = snapshot.baseServings,
       _servings = snapshot.servings,
       _totalSteps = snapshot.totalSteps,
       _currentStepIndex = snapshot.currentStepIndex,
       _isPaused = snapshot.isPaused,
       _isComplete = snapshot.isComplete,
       _completedSteps = Set<int>.from(snapshot.completedStepIndices),
       _timers = Map<int, CookStepTimer>.from(snapshot.timers),
       _persistence = persistence,
       _visualAlertEnabled = visualAlertEnabled,
       _reduceMotion = reduceMotion,
       _restoredFromPersistence = restoredFromPersistence,
       _createdAt = snapshot.createdAt,
       _clock = clock,
       _onTimerCompleted = onTimerCompleted {
    if (_reconcileTimers(emitAlerts: false)) _queuePersist();
    _ensureTicker();
  }

  static Future<CookSessionController> restore({
    required String recipeId,
    required double baseServings,
    required int totalSteps,
    required CookSessionPersistence persistence,
    bool visualAlertEnabled = true,
    bool reduceMotion = false,
    CookClock? clock,
    void Function(int stepIndex)? onTimerCompleted,
  }) async {
    final stored = await persistence.loadCookSession(recipeId);
    final usable =
        stored != null &&
        stored.totalSteps == totalSteps &&
        stored.baseServings == baseServings &&
        stored.servings > 0 &&
        stored.servings.isFinite &&
        stored.currentStepIndex >= 0 &&
        stored.currentStepIndex < totalSteps &&
        stored.completedStepIndices.every(
          (index) => index >= 0 && index < totalSteps,
        ) &&
        stored.timers.entries.every(
          (entry) =>
              entry.key >= 0 &&
              entry.key < totalSteps &&
              entry.value.totalSeconds >= 0 &&
              entry.value.remainingSeconds >= 0 &&
              entry.value.remainingSeconds <= entry.value.totalSeconds,
        );
    final controller = CookSessionController._(
      snapshot: usable
          ? stored
          : CookSessionSnapshot.fresh(
              recipeId: recipeId,
              baseServings: baseServings,
              totalSteps: totalSteps,
            ),
      persistence: persistence,
      visualAlertEnabled: visualAlertEnabled,
      reduceMotion: reduceMotion,
      restoredFromPersistence: usable,
      clock: clock ?? DateTime.now,
      onTimerCompleted: onTimerCompleted,
    );
    if (!usable) controller._queuePersist();
    return controller;
  }

  final String _recipeId;
  final double _baseServings;
  final int _totalSteps;
  final Set<int> _completedSteps;
  final Map<int, CookStepTimer> _timers;
  final CookSessionPersistence _persistence;
  final CookClock _clock;
  final bool _restoredFromPersistence;
  final DateTime _createdAt;
  final void Function(int stepIndex)? _onTimerCompleted;

  double _servings;
  int _currentStepIndex;
  bool _isPaused;
  bool _isComplete;
  bool _visualAlertEnabled;
  bool _reduceMotion;
  TimerVisualAlert? _visualAlert;
  Timer? _ticker;
  int _alertSequence = 0;
  Future<void> _writeChain = Future<void>.value();
  Object? _persistenceError;

  String get recipeId => _recipeId;
  bool get wasRestored => _restoredFromPersistence;
  String get completionRecordId =>
      'cook:$_recipeId:${_createdAt.microsecondsSinceEpoch}';
  double get baseServings => _baseServings;
  double get servings => _servings;
  double get servingsScale => _servings / _baseServings;
  int get totalSteps => _totalSteps;
  int get currentStepIndex => _currentStepIndex;
  bool get canGoPrevious => _currentStepIndex > 0 && !_isPaused;
  bool get canGoNext => !_isComplete && !_isPaused;
  bool get isPaused => _isPaused;
  bool get isComplete => _isComplete;
  bool get visualAlertEnabled => _visualAlertEnabled;
  bool get reduceMotion => _reduceMotion;
  TimerVisualAlert? get visualAlert => _visualAlert;
  Set<int> get completedStepIndices => Set<int>.unmodifiable(_completedSteps);
  Map<int, CookStepTimer> get timers =>
      Map<int, CookStepTimer>.unmodifiable(_timers);
  Object? get persistenceError => _persistenceError;

  CookSessionSnapshot get snapshot => CookSessionSnapshot(
    recipeId: _recipeId,
    baseServings: _baseServings,
    servings: _servings,
    totalSteps: _totalSteps,
    currentStepIndex: _currentStepIndex,
    isPaused: _isPaused,
    isComplete: _isComplete,
    completedStepIndices: _completedSteps,
    timers: _timers,
    createdAt: _createdAt,
    updatedAt: _clock(),
  );

  double? scaleQuantity(num? baseQuantity) =>
      baseQuantity == null ? null : baseQuantity.toDouble() * servingsScale;

  void setServings(double value) {
    if (value <= 0) throw ArgumentError.value(value, 'value', 'Must be > 0.');
    if (value == _servings) return;
    _servings = value;
    _changed();
  }

  void setAccessibility({bool? visualAlertEnabled, bool? reduceMotion}) {
    final nextAlertEnabled = visualAlertEnabled ?? _visualAlertEnabled;
    final nextReduceMotion = reduceMotion ?? _reduceMotion;
    if (nextAlertEnabled == _visualAlertEnabled &&
        nextReduceMotion == _reduceMotion) {
      return;
    }
    _visualAlertEnabled = nextAlertEnabled;
    _reduceMotion = nextReduceMotion;
    if (!_visualAlertEnabled) _visualAlert = null;
    notifyListeners();
  }

  void previousStep() {
    if (!canGoPrevious) return;
    _currentStepIndex--;
    _changed();
  }

  void nextStep() {
    if (!canGoNext) return;
    _completedSteps.add(_currentStepIndex);
    if (_currentStepIndex == _totalSteps - 1) {
      _isComplete = true;
      _freezeActiveTimers();
    } else {
      _currentStepIndex++;
    }
    _changed();
  }

  void goToStep(int index) {
    if (index < 0 || index >= _totalSteps) {
      throw RangeError.range(index, 0, _totalSteps - 1, 'index');
    }
    if (_currentStepIndex == index) return;
    _currentStepIndex = index;
    _isComplete = false;
    _changed();
  }

  void complete() {
    if (_isComplete) return;
    _completedSteps.addAll(Iterable<int>.generate(_totalSteps));
    _currentStepIndex = _totalSteps - 1;
    _isComplete = true;
    _freezeActiveTimers();
    _changed();
  }

  void startTimer(int stepIndex, Duration duration) {
    _checkStep(stepIndex);
    if (_isComplete) {
      throw StateError('Cannot start a timer on a completed cook session.');
    }
    if (duration <= Duration.zero) {
      throw ArgumentError.value(duration, 'duration', 'Must be positive.');
    }
    final seconds = math.max(1, (duration.inMilliseconds / 1000).ceil());
    final running = !_isPaused;
    _timers[stepIndex] = CookStepTimer(
      totalSeconds: seconds,
      remainingSeconds: seconds,
      status: running ? CookTimerStatus.running : CookTimerStatus.paused,
      endsAt: running ? _clock().toUtc().add(Duration(seconds: seconds)) : null,
    );
    _ensureTicker();
    _changed();
  }

  void pauseTimer(int stepIndex) {
    _checkStep(stepIndex);
    final timer = _timers[stepIndex];
    if (timer == null || timer.status != CookTimerStatus.running) return;
    final remaining = _remainingAt(timer, _clock());
    _timers[stepIndex] = timer.copyWith(
      remainingSeconds: remaining,
      status: remaining == 0
          ? CookTimerStatus.completed
          : CookTimerStatus.paused,
      clearEndsAt: true,
    );
    if (remaining == 0) _timerCompleted(stepIndex);
    _ensureTicker();
    _changed();
  }

  void resumeTimer(int stepIndex) {
    _checkStep(stepIndex);
    final timer = _timers[stepIndex];
    if (_isPaused || timer == null || timer.status != CookTimerStatus.paused) {
      return;
    }
    _timers[stepIndex] = timer.copyWith(
      status: CookTimerStatus.running,
      endsAt: _clock().toUtc().add(Duration(seconds: timer.remainingSeconds)),
    );
    _ensureTicker();
    _changed();
  }

  void resetTimer(int stepIndex) {
    _checkStep(stepIndex);
    if (_timers.remove(stepIndex) == null) return;
    _ensureTicker();
    _changed();
  }

  void pause() {
    if (_isPaused || _isComplete) return;
    final now = _clock();
    _isPaused = true;
    for (final entry in _timers.entries.toList(growable: false)) {
      final timer = entry.value;
      if (timer.status != CookTimerStatus.running) continue;
      final remaining = _remainingAt(timer, now);
      _timers[entry.key] = timer.copyWith(
        remainingSeconds: remaining,
        status: remaining == 0
            ? CookTimerStatus.completed
            : CookTimerStatus.paused,
        clearEndsAt: true,
      );
      if (remaining == 0) _timerCompleted(entry.key);
    }
    _ensureTicker();
    _changed();
  }

  void resume() {
    if (!_isPaused || _isComplete) return;
    final now = _clock().toUtc();
    _isPaused = false;
    for (final entry in _timers.entries.toList(growable: false)) {
      final timer = entry.value;
      if (timer.status != CookTimerStatus.paused) continue;
      _timers[entry.key] = timer.copyWith(
        status: CookTimerStatus.running,
        endsAt: now.add(Duration(seconds: timer.remainingSeconds)),
      );
    }
    _ensureTicker();
    _changed();
  }

  void dismissVisualAlert() {
    if (_visualAlert == null) return;
    _visualAlert = null;
    notifyListeners();
  }

  Future<void> discard() async {
    _ticker?.cancel();
    _ticker = null;
    await _writeChain;
    await _persistence.deleteCookSession(_recipeId);
  }

  Future<void> flush() => _writeChain;

  void _checkStep(int index) {
    if (index < 0 || index >= _totalSteps) {
      throw RangeError.range(index, 0, _totalSteps - 1, 'stepIndex');
    }
  }

  bool _reconcileTimers({required bool emitAlerts}) {
    if (_isPaused) return false;
    var changed = false;
    final now = _clock();
    for (final entry in _timers.entries.toList(growable: false)) {
      final timer = entry.value;
      if (timer.status != CookTimerStatus.running) continue;
      final remaining = _remainingAt(timer, now);
      if (remaining == timer.remainingSeconds) continue;
      changed = true;
      _timers[entry.key] = timer.copyWith(
        remainingSeconds: remaining,
        status: remaining == 0
            ? CookTimerStatus.completed
            : CookTimerStatus.running,
        clearEndsAt: remaining == 0,
      );
      if (remaining == 0 && emitAlerts) _timerCompleted(entry.key);
    }
    return changed;
  }

  int _remainingAt(CookStepTimer timer, DateTime now) {
    final end = timer.endsAt;
    if (end == null) return timer.remainingSeconds;
    final milliseconds = end.difference(now.toUtc()).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil();
  }

  void _freezeActiveTimers() {
    final now = _clock();
    for (final entry in _timers.entries.toList(growable: false)) {
      final timer = entry.value;
      if (timer.status != CookTimerStatus.running) continue;
      final remaining = _remainingAt(timer, now);
      _timers[entry.key] = timer.copyWith(
        remainingSeconds: remaining,
        status: remaining == 0
            ? CookTimerStatus.completed
            : CookTimerStatus.paused,
        clearEndsAt: true,
      );
    }
  }

  void _timerCompleted(int stepIndex) {
    _onTimerCompleted?.call(stepIndex);
    if (_visualAlertEnabled) {
      _visualAlert = TimerVisualAlert(
        tone: _alertSequence++ % 2 == 0
            ? TimerAlertTone.coral
            : TimerAlertTone.teal,
        shouldAnimate: !_reduceMotion,
        stepIndex: stepIndex,
      );
    }
  }

  void _ensureTicker() {
    final needsTicker =
        !_isPaused &&
        !_isComplete &&
        _timers.values.any((timer) => timer.status == CookTimerStatus.running);
    if (!needsTicker) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) {
      final before = Map<int, CookStepTimer>.from(_timers);
      _reconcileTimers(emitAlerts: true);
      if (!mapEquals(before, _timers)) {
        final completedNow = _timers.entries.any(
          (entry) =>
              before[entry.key]?.status != CookTimerStatus.completed &&
              entry.value.status == CookTimerStatus.completed,
        );
        if (completedNow) _queuePersist();
        notifyListeners();
      }
      _ensureTicker();
    });
  }

  void _changed() {
    _ensureTicker();
    _queuePersist();
    notifyListeners();
  }

  void _queuePersist() {
    final value = snapshot;
    _writeChain = _writeChain
        .catchError((Object _) {})
        .then((_) => _persistence.saveCookSession(value))
        .catchError((Object error) {
          _persistenceError = error;
        });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    super.dispose();
  }
}

/// Opt-in one-handed gesture behavior kept separate from cook session state.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    required this.session,
    CookHaptics haptics = const FlutterCookHaptics(),
    CookClock? clock,
    bool quickNextTapEnabled = false,
  }) : _haptics = haptics,
       _clock = clock ?? DateTime.now,
       _quickNextTapEnabled = quickNextTapEnabled;

  static const quickNextDebounce = Duration(milliseconds: 300);

  final CookSessionController session;
  final CookHaptics _haptics;
  final CookClock _clock;
  DateTime? _lastAcceptedTap;
  bool _quickNextTapEnabled;

  bool get quickNextTapEnabled => _quickNextTapEnabled;
  Duration get transitionDuration =>
      session.reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  set quickNextTapEnabled(bool value) {
    if (value == _quickNextTapEnabled) return;
    _quickNextTapEnabled = value;
    _lastAcceptedTap = null;
    notifyListeners();
  }

  /// Returns true only when the tap was accepted and advanced the recipe.
  Future<bool> onStepContentTap() async {
    if (!_quickNextTapEnabled || !session.canGoNext) return false;
    final now = _clock();
    final last = _lastAcceptedTap;
    if (last != null && now.difference(last) < quickNextDebounce) return false;
    _lastAcceptedTap = now;
    session.nextStep();
    try {
      await _haptics.quickNext();
    } on Object {
      // Haptics are enhancement-only; a platform vibration failure must not
      // roll back or report failure for an already accepted navigation tap.
    }
    return true;
  }
}
