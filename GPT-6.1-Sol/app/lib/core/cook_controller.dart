import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models.dart';

class OneHandedCookModeController {
  bool quickNextTapEnabled;
  bool reduceMotion;
  DateTime? _lastTap;
  OneHandedCookModeController({
    this.quickNextTapEnabled = false,
    this.reduceMotion = false,
  });
  bool acceptTap(DateTime now) {
    if (!quickNextTapEnabled) return false;
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 300) {
      return false;
    }
    _lastTap = now;
    if (!reduceMotion) HapticFeedback.selectionClick();
    return true;
  }
}

class CookController extends ChangeNotifier {
  final Recipe recipe;
  final void Function(Map<String, dynamic>) persist;
  final DateTime Function() now;
  int step;
  int servings;
  int remainingSeconds;
  bool running;
  bool finished = false;
  bool timerCompleted = false;
  DateTime? _deadline;
  Timer? _ticker;
  bool _disposed = false;

  CookController({
    required this.recipe,
    required this.persist,
    Map<String, dynamic>? progress,
    DateTime Function()? clock,
  }) : now = clock ?? DateTime.now,
       step = ((progress?['step'] as num?)?.toInt() ?? 0).clamp(
         0,
         recipe.steps.length - 1,
       ),
       servings = ((progress?['servings'] as num?)?.toInt() ?? recipe.servings)
           .clamp(1, 20),
       remainingSeconds =
           (progress?['remaining_seconds'] as num?)?.toInt() ?? 0,
       running = progress?['running'] as bool? ?? false {
    timerCompleted = progress?['timer_completed'] as bool? ?? false;
    if (progress?['deadline'] is String && running) {
      _deadline = DateTime.tryParse(progress!['deadline'] as String);
      tick();
      if (running) _startTicker();
    } else {
      running = false;
    }
  }

  Map<String, dynamic> toJson() => {
    'recipe_id': recipe.id,
    'step': step,
    'servings': servings,
    'remaining_seconds': remainingSeconds,
    'timer_completed': timerCompleted,
    'running': running,
    'deadline': _deadline?.toIso8601String(),
  };

  void _save() {
    if (!_disposed) {
      persist(toJson());
      notifyListeners();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void tick() {
    if (_disposed || !running || _deadline == null) return;
    final ms = _deadline!.difference(now()).inMilliseconds;
    remainingSeconds = (ms / 1000).ceil().clamp(0, 86400);
    if (remainingSeconds == 0) {
      running = false;
      timerCompleted = true;
      _deadline = null;
      _ticker?.cancel();
    }
    _save();
  }

  void startTimer() {
    remainingSeconds = recipe.steps[step].timerSeconds;
    if (remainingSeconds <= 0) return;
    timerCompleted = false;
    running = true;
    _deadline = now().add(Duration(seconds: remainingSeconds));
    _startTicker();
    _save();
  }

  void pauseTimer() {
    tick();
    running = false;
    _deadline = null;
    _ticker?.cancel();
    _save();
  }

  void resumeTimer() {
    if (remainingSeconds <= 0) return;
    running = true;
    _deadline = now().add(Duration(seconds: remainingSeconds));
    _startTicker();
    _save();
  }

  void dismissAlert() {
    timerCompleted = false;
    _save();
  }

  void move(int delta) {
    _ticker?.cancel();
    running = false;
    remainingSeconds = 0;
    _deadline = null;
    timerCompleted = false;
    step = (step + delta).clamp(0, recipe.steps.length - 1);
    _save();
  }

  void scaleServings(int delta) {
    servings = (servings + delta).clamp(1, 20);
    _save();
  }

  void pauseSession() {
    if (running) {
      pauseTimer();
    } else {
      _save();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
