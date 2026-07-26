import 'package:flutter/material.dart';

/// Motion is calm by default and disappears entirely when asked.
///
/// [Motion.of] resolves the profile's `reduceMotion` preference against the OS
/// setting: an explicit choice wins, null follows the platform.
class Motion extends InheritedWidget {
  const Motion({super.key, required this.reduced, required super.child});

  final bool reduced;

  static bool of(BuildContext context) {
    final inherited = context.dependOnInheritedWidgetOfExactType<Motion>();
    if (inherited != null) return inherited.reduced;
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Resolves an explicit preference against the platform default.
  static bool resolve(bool? preference, BuildContext context) =>
      preference ?? (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  static Duration duration(BuildContext context, Duration full) =>
      of(context) ? Duration.zero : full;

  /// A shortened, never-zero duration for things that must still read as a
  /// transition (a flash alert has to be perceivable even with motion reduced).
  static Duration gentle(BuildContext context, Duration full) =>
      of(context) ? Duration(milliseconds: full.inMilliseconds ~/ 3) : full;

  @override
  bool updateShouldNotify(Motion oldWidget) => oldWidget.reduced != reduced;
}

class MorphDurations {
  MorphDurations._();

  static const Duration flash = Duration(milliseconds: 420);
  static const Duration morph = Duration(milliseconds: 340);
  static const Duration expand = Duration(milliseconds: 260);
  static const Duration fade = Duration(milliseconds: 200);
  static const Duration quick = Duration(milliseconds: 120);
}

/// Collapse/expand that degrades to a plain rebuild under reduced motion.
///
/// `AnimatedSize` with a zero duration re-dirties itself inside its own
/// `performLayout`, so it cannot simply be handed `Duration.zero`.
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.duration,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration? duration;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (Motion.of(context)) return child;
    return AnimatedSize(
      duration: duration ?? MorphDurations.expand,
      curve: Curves2.standard,
      alignment: alignment,
      child: child,
    );
  }
}

/// `PageController.animateToPage` asserts on a zero duration, which is exactly
/// what reduced motion asks for. Jump instead.
extension MotionPaging on PageController {
  Future<void> goToPage(BuildContext context, int page, {Duration? full}) {
    final duration = Motion.duration(context, full ?? MorphDurations.expand);
    if (duration == Duration.zero) {
      jumpToPage(page);
      return Future<void>.value();
    }
    return animateToPage(page, duration: duration, curve: Curves2.standard);
  }
}

class Curves2 {
  Curves2._();

  /// Everything eases out. Nothing in this app should feel springy.
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve gentle = Cubic(0.33, 0.0, 0.15, 1.0);
}
