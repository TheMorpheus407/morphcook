import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/ui/onboarding/onboarding_flow.dart';
import 'package:morphcook/ui/shell/app_shell.dart';

import 'helpers.dart';

void main() {
  testWidgets('fresh install shows onboarding; completed profile shows the front page', (tester) async {
    final app = (await tester.runAsync(() => newController(clock: () => DateTime(2026, 9, 1, 19), loadAll: true)))!;
    await tester.pumpWidget(MorphCookApp(controller: app));
    await tester.pump();
    expect(find.byType(OnboardingFlow), findsOneWidget);

    await tester.runAsync(() => app.updateProfile(const Profile(name: 'cedric', onboardingComplete: true)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('morphcook'), findsWidgets);
    expect(find.text('for cedric', skipOffstage: false), findsNothing); // part of a meta line
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets('language switch re-renders navigation labels', (tester) async {
    final app = (await tester.runAsync(() => newController(profile: const Profile(name: 'x', onboardingComplete: true), loadAll: true)))!;
    await tester.pumpWidget(MorphCookApp(controller: app));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('cookbook'), findsOneWidget);
    await tester.runAsync(() => app.setLang('de'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('kochbuch'), findsOneWidget);
  });
}
