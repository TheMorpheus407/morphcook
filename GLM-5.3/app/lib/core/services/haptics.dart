import 'package:flutter/services.dart';

/// Central haptic feedback helpers.
class Haptics {
  const Haptics._();

  /// Light tap — quick-next gesture, chip selection.
  static void tap() => HapticFeedback.selectionClick();

  /// Medium impact — timer completion, cook-mode step change.
  static void impact() => HapticFeedback.mediumImpact();

  /// Success — cook-mode completion screen.
  static void success() => HapticFeedback.heavyImpact();
}
