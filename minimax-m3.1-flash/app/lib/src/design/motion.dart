import 'package:flutter/material.dart';

/// Motion policy for MorphCook.
///
/// Two independent switches reduce motion:
///
///  * the OS-level "remove animations" accessibility setting
///    ([MediaQueryData.disableAnimations]), and
///  * the in-app `reduceMotion` preference, which the user can pin to
///    *always on*, *always off*, or leave on `null` to follow the system.
///
/// Durations collapse to zero when motion is reduced — animations still run
/// their state changes, they just do not tween.
class MotionScope extends InheritedWidget {
  const MotionScope({
    required this.reduceMotion,
    required super.child,
    super.key,
  });

  /// `null` means "follow the system setting".
  final bool? reduceMotion;

  /// Effective reduce-motion flag for the nearest scope.
  static bool reduceOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<MotionScope>();
    final system = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final override = scope?.reduceMotion;
    if (override == null) return system;
    return override;
  }

  /// Scales [duration] to zero when motion is reduced.
  static Duration dur(BuildContext context, Duration duration) {
    return reduceOf(context) ? Duration.zero : duration;
  }

  @override
  bool updateShouldNotify(MotionScope oldWidget) =>
      oldWidget.reduceMotion != reduceMotion;
}

/// Named durations used across the app.
abstract final class Motion {
  const Motion._();

  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);
  static const Duration gentle = Duration(milliseconds: 900);

  /// The morph transition used when a variant changes and the ingredient
  /// list re-flows.
  static const Duration morph = Duration(milliseconds: 420);

  /// The breathing pulse used by timers.
  static const Duration pulse = Duration(milliseconds: 1100);
}
