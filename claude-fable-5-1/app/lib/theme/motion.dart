import 'package:flutter/widgets.dart';

/// Central place for "should we animate?". The profile's tri-state
/// (null = follow system) is resolved here.
class Motion extends InheritedWidget {
  const Motion({super.key, required this.reduceMotion, required super.child});

  final bool reduceMotion;

  static bool reduced(BuildContext context) {
    final m = context.dependOnInheritedWidgetOfExactType<Motion>();
    if (m != null) return m.reduceMotion;
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration duration(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;

  @override
  bool updateShouldNotify(Motion oldWidget) => oldWidget.reduceMotion != reduceMotion;
}
