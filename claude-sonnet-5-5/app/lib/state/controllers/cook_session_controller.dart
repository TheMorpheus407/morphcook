import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/models/history_entry.dart';
import '../../data/models/recipe.dart';
import '../catalog.dart';
import '../storage/storage.dart';

/// A per-step countdown. While running it stores the wall-clock moment it
/// ends, so it stays right when the app is backgrounded or restarted.
class StepTimer {
  const StepTimer({required this.totalSeconds, required this.remainingSeconds, this.endsAt, this.finished = false});

  final int totalSeconds;

  /// Seconds left while not running.
  final int remainingSeconds;
  final DateTime? endsAt;
  final bool finished;

  bool get running => endsAt != null && !finished;

  int remainingAt(DateTime now) {
    if (finished) return 0;
    final end = endsAt;
    if (end == null) return remainingSeconds;
    final ms = end.difference(now).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': totalSeconds,
    'remaining': remainingSeconds,
    if (endsAt != null) 'ends_at': endsAt!.toUtc().toIso8601String(),
    'finished': finished,
  };

  factory StepTimer.fromJson(Map<String, dynamic> json) => StepTimer(
    totalSeconds: (json['total'] as num).toInt(),
    remainingSeconds: (json['remaining'] as num).toInt(),
    endsAt: json['ends_at'] == null ? null : DateTime.parse(json['ends_at'] as String).toLocal(),
    finished: (json['finished'] as bool?) ?? false,
  );
}

/// Progress of one cooking run, persisted so it survives leaving the screen.
class CookSession {
  const CookSession({
    required this.recipeId,
    required this.servings,
    required this.stepIndex,
    required this.timers,
    required this.paused,
    required this.pausedTimers,
    required this.startedAt,
    required this.updatedAt,
  });

  final String recipeId;
  final double servings;
  final int stepIndex;
  final Map<int, StepTimer> timers;
  final bool paused;

  /// Steps whose timer was running when the session was paused.
  final Set<int> pausedTimers;
  final DateTime startedAt;
  final DateTime updatedAt;

  CookSession copyWith({
    double? servings,
    int? stepIndex,
    Map<int, StepTimer>? timers,
    bool? paused,
    Set<int>? pausedTimers,
    DateTime? updatedAt,
  }) {
    return CookSession(
      recipeId: recipeId,
      servings: servings ?? this.servings,
      stepIndex: stepIndex ?? this.stepIndex,
      timers: timers ?? this.timers,
      paused: paused ?? this.paused,
      pausedTimers: pausedTimers ?? this.pausedTimers,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'recipe_id': recipeId,
    'servings': servings,
    'step_index': stepIndex,
    'paused': paused,
    'paused_timers': pausedTimers.toList()..sort(),
    'started_at': startedAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'timers': {for (final e in timers.entries) '${e.key}': e.value.toJson()},
  };

  factory CookSession.fromJson(Map<String, dynamic> json) => CookSession(
    recipeId: json['recipe_id'] as String,
    servings: (json['servings'] as num).toDouble(),
    stepIndex: (json['step_index'] as num).toInt(),
    paused: (json['paused'] as bool?) ?? false,
    pausedTimers: ((json['paused_timers'] as List?) ?? const <Object?>[]).map((e) => (e as num).toInt()).toSet(),
    startedAt: DateTime.parse(json['started_at'] as String).toLocal(),
    updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    timers: {
      for (final e in ((json['timers'] as Map?) ?? const <String, dynamic>{}).entries)
        int.parse(e.key.toString()): StepTimer.fromJson((e.value as Map).cast<String, dynamic>()),
    },
  );
}

/// A timer ran out.
class TimerDone {
  const TimerDone(this.stepIndex);
  final int stepIndex;
}

/// Step-by-step cooking: navigation, servings, per-step timers, pause and
/// resume, and progress persistence.
///
/// Timers store the moment they end rather than counting down, so [tick] can be
/// called at any rhythm (or after the app was in the background) and stays exact.
class CookSessionController extends ChangeNotifier {
  CookSessionController(
    this._box, {
    Clock? clock,
    this.autoTick = true,
    this.tickInterval = const Duration(milliseconds: 250),
  }) : _clock = clock ?? DateTime.now {
    _stored = _readStored();
  }

  static Future<CookSessionController> open(AppStorage storage, {Clock? clock, bool autoTick = true}) async {
    return CookSessionController(await storage.records.open(Boxes.cookSession), clock: clock, autoTick: autoTick);
  }

  static const String _key = 'current';

  final RecordBox _box;
  final Clock _clock;
  final bool autoTick;
  final Duration tickInterval;

  Recipe? _recipe;
  CookSession? _session;
  CookSession? _stored;
  bool _completed = false;
  Timer? _ticker;
  final StreamController<TimerDone> _done = StreamController<TimerDone>.broadcast();

  /// Fires once when a step timer finishes.
  Stream<TimerDone> get timerDone => _done.stream;

  /// A saved run that can be picked up ("continue cooking").
  CookSession? get storedSession => _stored;

  Recipe? get recipe => _recipe;
  CookSession? get session => _session;
  bool get isActive => _session != null && _recipe != null;
  bool get completed => _completed;
  bool get paused => _session?.paused ?? false;

  int get stepIndex => _session?.stepIndex ?? 0;
  int get stepCount => _recipe?.steps.length ?? 0;
  bool get isFirstStep => stepIndex == 0;
  bool get isLastStep => stepIndex >= stepCount - 1;
  double get servings => _session?.servings ?? 0;

  /// Scale factor for ingredient amounts.
  double get scale => _recipe == null || _recipe!.servings == 0 ? 1 : servings / _recipe!.servings;

  CookSession? _readStored() {
    final json = _box.getJson(_key);
    if (json == null) return null;
    try {
      return CookSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------- lifecycle

  /// Starts cooking [recipe]. With [resume], a stored run of the same recipe is
  /// picked up where it stopped; otherwise the run starts fresh.
  Future<void> begin(Recipe recipe, {double? servings, bool resume = false}) async {
    _recipe = recipe;
    _completed = false;
    final now = _clock();
    final stored = _stored;
    if (resume && stored != null && stored.recipeId == recipe.id) {
      _session = stored.copyWith(stepIndex: stored.stepIndex.clamp(0, math.max(0, recipe.steps.length - 1)));
      // Timers that were running keep counting; ones paused on leaving wait for resume().
    } else {
      _session = CookSession(
        recipeId: recipe.id,
        servings: servings ?? recipe.servings.toDouble(),
        stepIndex: 0,
        timers: const <int, StepTimer>{},
        paused: false,
        pausedTimers: const <int>{},
        startedAt: now,
        updatedAt: now,
      );
    }
    await _persist();
    _syncTicker();
    notifyListeners();
    tick();
  }

  Future<void> _persist() async {
    final session = _session;
    if (session == null) return;
    _stored = session;
    await _box.putJson(_key, session.copyWith(updatedAt: _clock()).toJson());
  }

  void _update(CookSession session) {
    _session = session;
    _syncTicker();
    notifyListeners();
    unawaited(_persist());
  }

  // ---------------------------------------------------------------- steps

  void next() {
    final session = _session;
    if (session == null) return;
    if (isLastStep) {
      _completed = true;
      notifyListeners();
      return;
    }
    _update(session.copyWith(stepIndex: session.stepIndex + 1));
  }

  void previous() {
    final session = _session;
    if (session == null) return;
    if (_completed) {
      _completed = false;
      notifyListeners();
      return;
    }
    if (isFirstStep) return;
    _update(session.copyWith(stepIndex: session.stepIndex - 1));
  }

  void goTo(int index) {
    final session = _session;
    if (session == null || index < 0 || index >= stepCount) return;
    _completed = false;
    _update(session.copyWith(stepIndex: index));
  }

  void setServings(double servings) {
    final session = _session;
    if (session == null) return;
    _update(session.copyWith(servings: servings.clamp(1, 24).toDouble()));
  }

  // ---------------------------------------------------------------- timers

  StepTimer? timerAt(int step) => _session?.timers[step];

  /// The authored duration for a step, if it has a timer.
  int? timerSecondsFor(int step) {
    final recipe = _recipe;
    if (recipe == null || step < 0 || step >= recipe.steps.length) return null;
    return recipe.steps[step].timerSeconds;
  }

  int remainingSeconds(int step) {
    final t = timerAt(step);
    if (t != null) return t.remainingAt(_clock());
    return timerSecondsFor(step) ?? 0;
  }

  bool isTimerRunning(int step) => timerAt(step)?.running ?? false;
  bool isTimerFinished(int step) => timerAt(step)?.finished ?? false;

  List<int> get runningTimerSteps {
    final session = _session;
    if (session == null) return const <int>[];
    return [
      for (final e in session.timers.entries)
        if (e.value.running) e.key,
    ]..sort();
  }

  /// Starts, or resumes, the timer of [step].
  void startTimer(int step) {
    final session = _session;
    final total = timerSecondsFor(step);
    if (session == null || total == null || session.paused) return;
    final now = _clock();
    final existing = session.timers[step];
    final StepTimer timer;
    if (existing == null || existing.finished) {
      timer = StepTimer(
        totalSeconds: total,
        remainingSeconds: total,
        endsAt: now.add(Duration(seconds: total)),
      );
    } else if (existing.running) {
      return;
    } else {
      timer = StepTimer(
        totalSeconds: existing.totalSeconds,
        remainingSeconds: existing.remainingSeconds,
        endsAt: now.add(Duration(seconds: existing.remainingSeconds)),
      );
    }
    _update(session.copyWith(timers: {...session.timers, step: timer}));
  }

  void pauseTimer(int step) {
    final session = _session;
    final timer = session?.timers[step];
    if (session == null || timer == null || !timer.running) return;
    final remaining = timer.remainingAt(_clock());
    _update(
      session.copyWith(
        timers: {
          ...session.timers,
          step: StepTimer(totalSeconds: timer.totalSeconds, remainingSeconds: remaining),
        },
      ),
    );
  }

  void toggleTimer(int step) => isTimerRunning(step) ? pauseTimer(step) : startTimer(step);

  void resetTimer(int step) {
    final session = _session;
    if (session == null || !session.timers.containsKey(step)) return;
    _update(session.copyWith(timers: {...session.timers}..remove(step)));
  }

  /// Advances timers to the current clock and fires [timerDone] for every one
  /// that ran out. Safe to call at any time, for example when the app resumes.
  void tick() {
    final session = _session;
    if (session == null) return;
    final now = _clock();
    var changed = false;
    final timers = {...session.timers};
    final finishedNow = <int>[];
    for (final entry in session.timers.entries) {
      final timer = entry.value;
      if (timer.running && !timer.endsAt!.isAfter(now)) {
        timers[entry.key] = StepTimer(totalSeconds: timer.totalSeconds, remainingSeconds: 0, finished: true);
        finishedNow.add(entry.key);
        changed = true;
      }
    }
    if (changed) {
      _session = session.copyWith(timers: timers);
      unawaited(_persist());
      for (final step in finishedNow) {
        _done.add(TimerDone(step));
      }
    }
    _syncTicker();
    // Running timers show a live countdown, so listeners refresh on every tick.
    if (changed || runningTimerSteps.isNotEmpty) notifyListeners();
  }

  void _syncTicker() {
    final needsTicker = autoTick && _session != null && !_session!.paused && runningTimerSteps.isNotEmpty;
    if (needsTicker && _ticker == null) {
      _ticker = Timer.periodic(tickInterval, (_) => tick());
    } else if (!needsTicker && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  // ---------------------------------------------------------------- pause / resume

  /// Freezes every running timer. Progress stays saved for later.
  void pause() {
    final session = _session;
    if (session == null || session.paused) return;
    final now = _clock();
    final timers = {...session.timers};
    final running = <int>{};
    for (final entry in session.timers.entries) {
      if (entry.value.running) {
        running.add(entry.key);
        timers[entry.key] = StepTimer(
          totalSeconds: entry.value.totalSeconds,
          remainingSeconds: entry.value.remainingAt(now),
        );
      }
    }
    _update(session.copyWith(timers: timers, paused: true, pausedTimers: running));
  }

  /// Restarts exactly the timers that ran when the session was paused.
  void resume() {
    final session = _session;
    if (session == null || !session.paused) return;
    final now = _clock();
    final timers = {...session.timers};
    for (final step in session.pausedTimers) {
      final timer = timers[step];
      if (timer != null && !timer.finished) {
        timers[step] = StepTimer(
          totalSeconds: timer.totalSeconds,
          remainingSeconds: timer.remainingSeconds,
          endsAt: now.add(Duration(seconds: timer.remainingSeconds)),
        );
      }
    }
    _update(session.copyWith(timers: timers, paused: false, pausedTimers: const <int>{}));
  }

  // ---------------------------------------------------------------- finish

  /// Marks the recipe as cooked, clears the saved run and returns the history entry.
  Future<HistoryEntry> complete() async {
    final session = _session!;
    final entry = HistoryEntry(recipeId: session.recipeId, cookedAt: _clock(), servings: session.servings);
    await _clear();
    return entry;
  }

  /// Drops the run without recording it.
  Future<void> abandon() => _clear();

  Future<void> _clear() async {
    _ticker?.cancel();
    _ticker = null;
    _session = null;
    _recipe = null;
    _stored = null;
    _completed = false;
    await _box.delete(_key);
    notifyListeners();
  }

  /// Leaves the screen but keeps the run for later (timers paused).
  Future<void> suspend() async {
    if (_session == null) return;
    pause();
    await _persist();
    _ticker?.cancel();
    _ticker = null;
    _recipe = null;
    _session = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _done.close();
    super.dispose();
  }
}
