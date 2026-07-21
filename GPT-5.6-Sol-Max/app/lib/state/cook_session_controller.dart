import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../models/user_data.dart';
import 'app_controller.dart';

class OneHandedCookModeController {
  OneHandedCookModeController({required this.quickNextTapEnabled});

  bool quickNextTapEnabled;
  DateTime? _lastTap;

  bool acceptTap() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < 300) {
      return false;
    }
    _lastTap = now;
    return true;
  }
}

class CookSessionController extends ChangeNotifier {
  CookSessionController({
    required this.app,
    required this.recipe,
    required this.reduceMotion,
  }) : oneHanded = OneHandedCookModeController(
         quickNextTapEnabled: app.profile.quickNextTapEnabled,
       ) {
    final saved = app.store.loadCookProgress(recipe.id);
    stepIndex = saved?.stepIndex.clamp(0, recipe.steps.length - 1) ?? 0;
    servings = saved?.servings ?? recipe.servings;
    remainingSeconds =
        saved?.remainingSeconds ?? recipe.steps[stepIndex].timerSeconds ?? 0;
    paused = saved?.paused ?? true;
    if (!paused && remainingSeconds > 0) _startTicker();
  }

  final AppController app;
  final Recipe recipe;
  final bool reduceMotion;
  final OneHandedCookModeController oneHanded;
  Timer? _timer;
  Timer? _alertTimer;

  late int stepIndex;
  late int servings;
  late int remainingSeconds;
  late bool paused;
  bool timerFinished = false;
  bool alertAlternate = false;
  bool completed = false;

  RecipeStep get step => recipe.steps[stepIndex];
  bool get hasPrevious => stepIndex > 0;
  bool get hasNext => stepIndex < recipe.steps.length - 1;
  double get progress => (stepIndex + 1) / recipe.steps.length;

  void setServings(int value) {
    servings = value.clamp(1, 12);
    _persist();
    notifyListeners();
  }

  void startTimer() {
    if (remainingSeconds <= 0) {
      remainingSeconds = step.timerSeconds ?? 0;
    }
    if (remainingSeconds <= 0) return;
    paused = false;
    timerFinished = false;
    _startTicker();
    _persist();
    notifyListeners();
  }

  void pauseTimer() {
    paused = true;
    _timer?.cancel();
    _persist();
    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _alertTimer?.cancel();
    paused = true;
    timerFinished = false;
    remainingSeconds = step.timerSeconds ?? 0;
    _persist();
    notifyListeners();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (remainingSeconds > 0) remainingSeconds--;
      if (remainingSeconds <= 0) {
        _timer?.cancel();
        paused = true;
        timerFinished = true;
        _startVisualAlert();
      }
      if (remainingSeconds % 5 == 0 || remainingSeconds == 0) _persist();
      notifyListeners();
    });
  }

  void _startVisualAlert() {
    if (!app.profile.visualAlertEnabled) return;
    if (reduceMotion) {
      alertAlternate = true;
      return;
    }
    _alertTimer?.cancel();
    _alertTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      alertAlternate = !alertAlternate;
      notifyListeners();
    });
    Future<void>.delayed(const Duration(seconds: 5), () {
      _alertTimer?.cancel();
      alertAlternate = false;
      notifyListeners();
    });
  }

  void dismissAlert() {
    timerFinished = false;
    alertAlternate = false;
    _alertTimer?.cancel();
    notifyListeners();
  }

  void previous() {
    if (!hasPrevious) return;
    _moveTo(stepIndex - 1);
  }

  void next() {
    if (hasNext) {
      _moveTo(stepIndex + 1);
    } else {
      completed = true;
      _timer?.cancel();
      _alertTimer?.cancel();
      notifyListeners();
    }
  }

  Future<void> quickNext() async {
    if (!oneHanded.acceptTap()) return;
    if (!reduceMotion) await HapticFeedback.lightImpact();
    next();
  }

  void _moveTo(int index) {
    _timer?.cancel();
    _alertTimer?.cancel();
    stepIndex = index;
    remainingSeconds = recipe.steps[index].timerSeconds ?? 0;
    paused = true;
    timerFinished = false;
    alertAlternate = false;
    _persist();
    notifyListeners();
  }

  void _persist() {
    app.store.saveCookProgress(
      CookProgress(
        recipeId: recipe.id,
        stepIndex: stepIndex,
        servings: servings,
        remainingSeconds: remainingSeconds,
        paused: paused,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    if (!completed) _persist();
    super.dispose();
  }
}
