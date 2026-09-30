import 'package:flutter/widgets.dart';

/// How large the person has set the system text, for layouts that need to give
/// text more room than a fixed height allows.
extension TextScaleContext on BuildContext {
  /// The system text scale as one number, 1.0 at the default size. It samples a
  /// body-sized font, because newer Android versions scale large fonts less.
  double get textScale => MediaQuery.textScalerOf(this).scale(16) / 16;

  /// Text is large enough that side-by-side layouts of labels and buttons have to stack.
  bool get largeText => textScale >= 1.3;
}
