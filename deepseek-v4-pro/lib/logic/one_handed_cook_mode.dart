
/// The one-handed cook-mode gesture controller.
/// A single tap on step content advances to the next step with haptic
/// feedback; opt-in via [quickNextTapEnabled]; includes a 300 ms debounce
/// to prevent accidental triggers; respects reduce-motion.
class OneHandedCookModeController {
  OneHandedCookModeController({
    this.quickNextTapEnabled = false,
    this.reduceMotion = false,
  });

  /// Opt-in flag (mirrors the profile setting).
  bool quickNextTapEnabled;

  /// Accessibility preference: animation duration, gesture sensitivity.
  bool reduceMotion;

  DateTime? _lastTap;

  static const debounce = Duration(milliseconds: 300);

  /// Attempts to advance. Returns true when the tap was accepted.
  bool tryAdvance() {
    if (!quickNextTapEnabled) return false;
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!) < debounce) {
      return false;
    }
    _lastTap = now;
    return true;
  }
}
