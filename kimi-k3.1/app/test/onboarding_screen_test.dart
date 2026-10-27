import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets(
    'five-step onboarding applies language, name and diet preferences',
    (tester) async {
      usePhone(tester);
      final app = await makeTestApp(tester, profile: const Profile());
      await pumpMorphCook(tester, app);
      expect(find.text('Which language feels like home?'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Vegan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vegan'));
      await tester.pump();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Your cookbook is ready.'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Open my cookbook'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
      expect(app.profile.onboardingComplete, isTrue);
      expect(app.profile.name, 'Ada');
      expect(app.profile.avoidFlags, contains('vegan'));
      expect(find.text('morphcook.'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pump();
      await tester.runAsync(() => app.writesSettled);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('profile completion switches directly to home', (tester) async {
    usePhone(tester);
    final app = await makeTestApp(tester, profile: const Profile());
    await pumpMorphCook(tester, app);
    await tester.runAsync(
      () => app.updateProfile(app.profile.copyWith(onboardingComplete: true)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('fresh from the kitchen'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('fresh from the kitchen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
