import 'package:flutter/foundation.dart';

import '../../platform/platform_services.dart';
import '../catalog.dart';
import 'profile_controller.dart';

/// One-handed cooking: a single tap on the step text moves to the next step.
///
/// Opt-in (`quickNextTapEnabled`, off by default), 300 ms debounce against
/// accidental double triggers, haptic feedback on every advance, and it
/// respects `reduceMotion` by turning the step transition into a plain swap.
class OneHandedCookModeController extends ChangeNotifier {
  OneHandedCookModeController({
    required ProfileController profile,
    required Haptics haptics,
    required bool Function() reduceMotion,
    Clock? clock,
  }) : _profile = profile,
       _haptics = haptics,
       _reduceMotion = reduceMotion,
       _clock = clock ?? DateTime.now {
    _profile.addListener(notifyListeners);
  }

  /// Taps closer together than this are ignored.
  static const Duration debounce = Duration(milliseconds: 300);

  final ProfileController _profile;
  final Haptics _haptics;
  final bool Function() _reduceMotion;
  final Clock _clock;
  DateTime? _lastAdvance;

  /// Opt-in switch; stored with the device settings.
  bool get quickNextTapEnabled => _profile.settings.quickNextTapEnabled;

  set quickNextTapEnabled(bool value) {
    _profile.updateSettings((s) => s.copyWith(quickNextTapEnabled: value));
  }

  /// Whether step changes may animate.
  bool get animateTransitions => !_reduceMotion();

  /// Handles a tap on the step content. Returns `true` when it advanced.
  bool handleQuickTap(VoidCallback advance) {
    if (!quickNextTapEnabled) return false;
    final now = _clock();
    final last = _lastAdvance;
    if (last != null && now.difference(last) < debounce) return false;
    _lastAdvance = now;
    _haptics.tap();
    advance();
    return true;
  }

  @override
  void dispose() {
    _profile.removeListener(notifyListeners);
    super.dispose();
  }
}
