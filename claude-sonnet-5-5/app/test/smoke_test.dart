import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/features/home/home_screen.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('home screen builds with the seed corpus', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester);
    await pumpApp(tester, services, home: const Scaffold(body: HomeScreen()));
    await settle(tester);
    expect(find.text('morphcook'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
