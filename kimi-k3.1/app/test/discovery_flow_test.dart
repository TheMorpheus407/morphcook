import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets(
    'partition search respects vegan profile and saves the exact variant',
    (tester) async {
      usePhone(tester);
      final app = await makeTestApp(
        tester,
        profile: const Profile(avoidFlags: {'vegan'}, onboardingComplete: true),
      );
      await pumpMorphCook(tester, app);
      await tester.tap(find.byIcon(Icons.search));
      await tester.runAsync(() async {
        final deadline = DateTime.now().add(const Duration(seconds: 5));
        while (app.repository.recipes.length < 60 &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(find.byType(TextField), 'Döner');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Easy Seitan Döner'), findsOneWidget);
      expect(find.text('Classic Chicken Döner'), findsNothing);
      await tester.tap(find.text('Easy Seitan Döner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save my version'));
      await tester.pumpAndSettle();
      expect(app.isSaved('doener-vegan-easy'), isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('COOKBOOK'));
      await tester.pumpAndSettle();
      expect(find.text('Easy Seitan Döner'), findsOneWidget);
      await tester.runAsync(() => app.writesSettled);
      expect(tester.takeException(), isNull);
    },
  );
}
