import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models.dart';

/// Per-step timer. Counts down in whole seconds, survives pause/resume, and
/// raises [onFinished] exactly once per run.
class StepTimer extends ChangeNotifier {
  StepTimer();

  Timer? _ticker;
  int _total = 0;
  int _remaining = 0;
  bool _running = false;
  bool _finished = false;

  int get total => _total;
  int get remaining => _remaining;
  bool get running => _running;
  bool get finished => _finished;
  bool get hasTimer => _total > 0;

  double get progress => _total == 0 ? 0 : 1 - (_remaining / _total);

  VoidCallback? onFinished;

  void configure(int? seconds, {int? resumeAt}) {
    _ticker?.cancel();
    _ticker = null;
    _total = seconds ?? 0;
    _remaining = (resumeAt ?? seconds ?? 0).clamp(0, _total);
    _running = false;
    _finished = false;
    notifyListeners();
  }

  void start() {
    if (!hasTimer || _running || _remaining <= 0) return;
    _running = true;
    _finished = false;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    notifyListeners();
  }

  void pause() {
    _ticker?.cancel();
    _ticker = null;
    _running = false;
    notifyListeners();
  }

  void toggle() => _running ? pause() : start();

  void reset() {
    _ticker?.cancel();
    _ticker = null;
    _remaining = _total;
    _running = false;
    _finished = false;
    notifyListeners();
  }

  void _tick() {
    if (_remaining <= 1) {
      _remaining = 0;
      _running = false;
      _finished = true;
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      onFinished?.call();
      return;
    }
    _remaining--;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

/// Opt-in single-tap advance for cooking with one hand.
///
/// Debounced by 300 ms so a slipped thumb cannot skip two steps, and disabled
/// entirely when the user has asked for reduced motion — the gesture relies on
/// a transition to read as "something happened".
class OneHandedCookModeController {
  OneHandedCookModeController({
    this.quickNextTapEnabled = false,
    this.reduceMotion = false,
    this.debounce = const Duration(milliseconds: 300),
  });

  final bool quickNextTapEnabled;
  final bool reduceMotion;
  final Duration debounce;

  DateTime? _lastAccepted;

  bool get isActive => quickNextTapEnabled && !reduceMotion;

  /// Returns true when this tap should advance a step.
  bool registerTap(DateTime now) {
    if (!isActive) return false;
    final last = _lastAccepted;
    if (last != null && now.difference(last) < debounce) return false;
    _lastAccepted = now;
    return true;
  }

  void reset() => _lastAccepted = null;
}

/// Which ingredients a step is likely to need, matched by name so the cook can
/// see the quantities without scrolling back. Heuristic on purpose — the corpus
/// does not annotate steps with ingredient ids, and a wrong guess here costs a
/// glance, not a mistake.
List<RecipeIngredient> ingredientsMentionedIn(
  RecipeStep step,
  Recipe recipe,
  IngredientDictionary dictionary,
  String lang,
) {
  final text = step.text(lang).toLowerCase();
  return [
    for (final item in recipe.ingredients)
      if (_mentions(text, dictionary[item.ingredientId]?.label(lang) ?? ''))
        item,
  ];
}

bool _mentions(String text, String label) {
  if (label.isEmpty) return false;
  for (final word in label.toLowerCase().split(RegExp(r'[^\wäöüß]+'))) {
    if (word.length < 4) continue;
    // Trim a trailing plural so "tomatoes" matches "tomato".
    final stem = word.endsWith('s') ? word.substring(0, word.length - 1) : word;
    if (text.contains(stem)) return true;
  }
  return false;
}
