import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/state/cook_session_controller.dart';

void main() {
  test('quick-next is opt-in and debounces taps for 300 ms', () async {
    final disabled = OneHandedCookModeController(quickNextTapEnabled: false);
    expect(disabled.acceptTap(), isFalse);

    final enabled = OneHandedCookModeController(quickNextTapEnabled: true);
    expect(enabled.acceptTap(), isTrue);
    expect(enabled.acceptTap(), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 310));
    expect(enabled.acceptTap(), isTrue);
  });
}
