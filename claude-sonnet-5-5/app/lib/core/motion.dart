import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/controllers/profile_controller.dart';

/// Accessibility: animation follows the `reduceMotion` profile setting, and the
/// system setting when the profile leaves it unset (`null`).
class MotionPreferences extends ChangeNotifier {
  MotionPreferences(this._profile) {
    _profile.addListener(_changed);
  }

  final ProfileController _profile;
  bool _system = false;
  bool _last = false;

  /// Effective preference: the profile override, else the system setting.
  bool get reduceMotion => _profile.profile.reduceMotion ?? _system;

  /// Called by [MotionScope] with the platform's "remove animations" flag.
  void updateSystem(bool value) {
    if (value == _system) return;
    _system = value;
    _changed();
  }

  void _changed() {
    final now = reduceMotion;
    if (now == _last) return;
    _last = now;
    notifyListeners();
  }

  /// [duration], or zero when motion is reduced.
  Duration scale(Duration duration) => reduceMotion ? Duration.zero : duration;

  @override
  void dispose() {
    _profile.removeListener(_changed);
    super.dispose();
  }
}

/// Feeds the platform's reduce-motion flag into [MotionPreferences].
class MotionScope extends StatelessWidget {
  const MotionScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = Provider.of<MotionPreferences>(context, listen: false);
    final system = MediaQuery.of(context).disableAnimations;
    if (system != motion._system) {
      // Not while building: listeners would be marked dirty mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => motion.updateSystem(system));
    }
    return child;
  }
}

extension MotionContext on BuildContext {
  /// `true` when animations should be skipped or shortened.
  bool get reduceMotion => Provider.of<MotionPreferences>(this).reduceMotion;

  /// Scales [duration] to zero when motion is reduced.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
