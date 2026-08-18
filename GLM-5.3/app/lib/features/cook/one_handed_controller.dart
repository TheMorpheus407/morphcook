import 'package:flutter/material.dart';

import '../../core/services/haptics.dart';

/// One-handed cook mode controller (SPEC): an opt-in quick-tap gesture — a
/// single tap on the step content advances to the next step with haptic
/// feedback, guarded by a 300 ms debounce to prevent accidental triggers.
/// Also respects the reduce-motion preference (no transition animation).
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    required this.quickNextTapEnabled,
    required this.reduceMotion,
  });

  bool quickNextTapEnabled;
  bool reduceMotion;

  static const quickNextDebounce = Duration(milliseconds: 300);

  DateTime _lastQuickNext = DateTime.fromMillisecondsSinceEpoch(0);

  /// Registered by the cook page — called when a quick tap advances.
  void Function()? onAdvance;

  /// Handles a tap on the step content. Returns true when the gesture was
  /// consumed (enabled + outside the debounce window).
  bool handleQuickTap() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (now.difference(_lastQuickNext) < quickNextDebounce) return false;
    _lastQuickNext = now;
    Haptics.tap();
    onAdvance?.call();
    return true;
  }

  void toggleQuickNext() {
    quickNextTapEnabled = !quickNextTapEnabled;
    notifyListeners();
  }
}
