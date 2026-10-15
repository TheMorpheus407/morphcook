import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller for Cook Mode accessibility and one-handed operation as defined in SPEC.md:
/// - `quickNextTapEnabled`: opt-in single tap on step content to advance to next step
/// - Includes 300ms debounce to prevent accidental triggers
/// - `visualAlertEnabled`: visual flash alert (coral/teal) on timer completion for
///   deaf/hard-of-hearing users
/// - Respects `reduceMotion` preference
class OneHandedCookModeController extends ChangeNotifier {
  static const Duration debounceWindow = Duration(milliseconds: 300);

  /// Coral (`#E06D53`) and Teal (`#4EA89B`) flash colors for timer completion alerts.
  static const Color coralAlertColor = Color(0xFFE06D53);
  static const Color tealAlertColor = Color(0xFF4EA89B);

  bool _quickNextTapEnabled;
  bool _visualAlertEnabled;
  bool? _reduceMotion;
  DateTime? _lastTapAt;
  bool _isVisualAlertActive = false;
  int _flashPhase = 0;

  OneHandedCookModeController({
    bool quickNextTapEnabled = false,
    bool visualAlertEnabled = true,
    bool? reduceMotion,
  })  : _quickNextTapEnabled = quickNextTapEnabled,
        _visualAlertEnabled = visualAlertEnabled,
        _reduceMotion = reduceMotion;

  bool get quickNextTapEnabled => _quickNextTapEnabled;
  set quickNextTapEnabled(bool value) {
    if (_quickNextTapEnabled == value) return;
    _quickNextTapEnabled = value;
    notifyListeners();
  }

  bool get visualAlertEnabled => _visualAlertEnabled;
  set visualAlertEnabled(bool value) {
    if (_visualAlertEnabled == value) return;
    _visualAlertEnabled = value;
    notifyListeners();
  }

  bool? get reduceMotion => _reduceMotion;
  set reduceMotion(bool? value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
  }

  bool get isVisualAlertActive => _isVisualAlertActive;
  int get flashPhase => _flashPhase;

  /// Effective reduce-motion state combining user override and platform setting.
  bool effectiveReduceMotion({bool systemReduceMotion = false}) {
    return _reduceMotion ?? systemReduceMotion;
  }

  /// Animation duration respecting `reduceMotion`.
  Duration stepTransitionDuration({bool systemReduceMotion = false}) {
    if (effectiveReduceMotion(systemReduceMotion: systemReduceMotion)) {
      return Duration.zero;
    }
    return const Duration(milliseconds: 280);
  }

  /// Handles a single tap on step content.
  /// Returns `true` if the step advanced, or `false` if disabled or debounced (< 300ms).
  bool handleStepContentTap(
    VoidCallback onAdvanceStep, {
    DateTime? timestamp,
    bool triggerHaptics = true,
  }) {
    if (!_quickNextTapEnabled) return false;

    final now = timestamp ?? DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!) < debounceWindow) {
      return false;
    }

    _lastTapAt = now;
    if (triggerHaptics) {
      HapticFeedback.selectionClick();
    }
    onAdvanceStep();
    notifyListeners();
    return true;
  }

  /// Triggers the visual flash alert (coral/teal) when a step timer completes.
  void triggerTimerVisualAlert({bool systemReduceMotion = false}) {
    if (!_visualAlertEnabled) return;
    _isVisualAlertActive = true;
    _flashPhase = 0;
    notifyListeners();
  }

  /// Advances the coral/teal flash phase (unless `reduceMotion` is active, in
  /// which case a steady static border/banner is used instead of rapid flashing).
  void stepFlashPhase({bool systemReduceMotion = false}) {
    if (!_isVisualAlertActive) return;
    if (effectiveReduceMotion(systemReduceMotion: systemReduceMotion)) {
      _flashPhase = 0;
    } else {
      _flashPhase = (_flashPhase + 1) % 2;
    }
    notifyListeners();
  }

  void dismissVisualAlert() {
    if (!_isVisualAlertActive) return;
    _isVisualAlertActive = false;
    _flashPhase = 0;
    notifyListeners();
  }

  Color get currentAlertColor =>
      _flashPhase.isEven ? coralAlertColor : tealAlertColor;
}
