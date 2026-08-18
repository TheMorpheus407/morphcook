import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/features/cook/one_handed_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quick tap disabled → gesture not consumed', () {
    final controller = OneHandedCookModeController(
      quickNextTapEnabled: false,
      reduceMotion: false,
    );
    var advances = 0;
    controller.onAdvance = () => advances++;
    expect(controller.handleQuickTap(), isFalse);
    expect(advances, 0);
  });

  test('quick tap advances with haptics when enabled', () {
    final controller = OneHandedCookModeController(
      quickNextTapEnabled: true,
      reduceMotion: false,
    );
    var advances = 0;
    controller.onAdvance = () => advances++;
    expect(controller.handleQuickTap(), isTrue);
    expect(advances, 1);
  });

  test('300 ms debounce swallows accidental double taps (SPEC)', () async {
    final controller = OneHandedCookModeController(
      quickNextTapEnabled: true,
      reduceMotion: false,
    );
    var advances = 0;
    controller.onAdvance = () => advances++;
    expect(controller.handleQuickTap(), isTrue);
    // Immediately after: consumed by the debounce window.
    expect(controller.handleQuickTap(), isFalse);
    expect(advances, 1);
    // After the window passes, the gesture works again.
    await Future<void>.delayed(
        OneHandedCookModeController.quickNextDebounce + const Duration(milliseconds: 20));
    expect(controller.handleQuickTap(), isTrue);
    expect(advances, 2);
  });

  test('toggle flips the opt-in', () {
    final controller = OneHandedCookModeController(
      quickNextTapEnabled: false,
      reduceMotion: true,
    );
    controller.toggleQuickNext();
    expect(controller.quickNextTapEnabled, isTrue);
    expect(controller.reduceMotion, isTrue);
  });

  test('haptic channel accepts calls without plugins', () async {
    // Sanity: the services channel is mocked by the test binding.
    await HapticFeedback.selectionClick();
  });
}
