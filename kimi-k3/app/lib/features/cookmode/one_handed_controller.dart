import 'package:flutter/foundation.dart';

/// One-handed cook mode: a single tap on the step content advances to the
/// next step. Opt-in via the profile, fully disabled under reduce motion.
///
/// A 300ms debounce guarantees an accidental double-tap never skips two
/// steps: taps arriving within [debounceWindow] of the last accepted tap are
/// ignored.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    bool quickNextTapEnabled = false,
    bool reduceMotion = false,
  }) : _quickNextTapEnabled = quickNextTapEnabled,
       _reduceMotion = reduceMotion;

  static const Duration debounceWindow = Duration(milliseconds: 300);

  bool _quickNextTapEnabled;
  bool _reduceMotion;
  DateTime? _lastAcceptedTap;

  /// Opt-in from the profile: quick tap on step content advances.
  bool get quickNextTapEnabled => _quickNextTapEnabled;

  set quickNextTapEnabled(bool value) {
    if (_quickNextTapEnabled == value) return;
    _quickNextTapEnabled = value;
    notifyListeners();
  }

  /// When active, quick-tap is disabled entirely (no surprise navigation).
  bool get reduceMotion => _reduceMotion;

  set reduceMotion(bool value) {
    if (_reduceMotion == value) return;
    _reduceMotion = value;
    notifyListeners();
  }

  /// Keeps the controller in step with the (possibly changing) profile.
  void sync({required bool quickNextTapEnabled, required bool reduceMotion}) {
    if (_quickNextTapEnabled == quickNextTapEnabled &&
        _reduceMotion == reduceMotion) {
      return;
    }
    _quickNextTapEnabled = quickNextTapEnabled;
    _reduceMotion = reduceMotion;
    notifyListeners();
  }

  /// Handles a tap on the step content area. Calls [advance] only when the
  /// gesture is enabled and the tap falls outside the debounce window.
  void onTap(VoidCallback advance) {
    if (!_quickNextTapEnabled || _reduceMotion) return;
    final now = DateTime.now();
    final last = _lastAcceptedTap;
    if (last != null && now.difference(last) < debounceWindow) return;
    _lastAcceptedTap = now;
    advance();
  }
}
