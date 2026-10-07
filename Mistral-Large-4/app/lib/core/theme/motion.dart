import 'package:flutter/material.dart';

/// Motion durations. When the user prefers reduced motion (or the system does),
/// everything collapses to near-instant so the app stays calm, never flashy.
class Motion {
  Motion._();

  static const Duration fast = Duration(milliseconds: 220);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration morph = Duration(milliseconds: 450);
  static const Duration slow = Duration(milliseconds: 600);

  static const Duration fastReduced = Duration(milliseconds: 60);
  static const Duration mediumReduced = Duration(milliseconds: 90);
  static const Duration morphReduced = Duration(milliseconds: 100);
  static const Duration slowReduced = Duration(milliseconds: 120);

  /// Timer-completion flash: coral/teal alternation for deaf / hard-of-hearing
  /// users. Six toggles over 2.5 s; two toggles over 0.5 s when reduced.
  static const Duration timerFlash = Duration(milliseconds: 2500);
  static const int timerFlashToggles = 6;
  static const Duration timerFlashReduced = Duration(milliseconds: 500);
  static const int timerFlashTogglesReduced = 2;

  static Duration resolve(BuildContext context, Duration full, {bool? reduceMotion}) {
    final bool reduced = reduceMotion ?? MediaQuery.of(context).disableAnimations;
    if (!reduced) return full;
    if (full == fast) return fastReduced;
    if (full == medium) return mediumReduced;
    if (full == morph) return morphReduced;
    if (full == slow) return slowReduced;
    return fastReduced;
  }
}
