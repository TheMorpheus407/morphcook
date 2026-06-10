import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/main.dart';

void main() {
  testWidgets('App boots and shows the splash wordmark',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MorphCookApp());
    // First frame: splash is rendered before async corpus / store load.
    await tester.pump();
    expect(find.text('morphcook'), findsOneWidget);
  });
}
