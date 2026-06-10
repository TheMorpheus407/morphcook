// This is a basic Flutter widget test for MorphCookApp.
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('App launch and onboarding load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MorphCookApp());
    await tester.pump(); // trigger frame

    // Verify that our app displays the wordmark "morphcook"
    expect(find.text('morphcook'), findsWidgets);
  });
}
