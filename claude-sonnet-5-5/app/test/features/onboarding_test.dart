import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/profile.dart';

import '../support/test_app.dart';

void main() {
  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('NEXT'));
    await settle(tester);
  }

  testWidgets('the flow runs language, name, diet, targets and confirm, then opens the app', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: false, profile: const Profile(lang: 'en'));
    await pumpApp(tester, services);
    await settle(tester);

    // 1. language
    expect(find.text('hello, and welcome.'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
    await next(tester);

    // 2. name
    expect(find.text('what should we call you?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Robin');
    await tester.pump();
    expect(services.profile.profile.name, 'Robin', reason: 'every step writes straight into the profile');
    await next(tester);

    // 3. diet & allergies
    expect(find.text('how do you eat?'), findsOneWidget);
    await tester.tap(find.text('vegetarian'));
    await tester.pump();
    expect(services.profile.profile.avoidFlags, {'vegetarian'});
    await next(tester);

    // 4. calorie target + time budget
    expect(find.text('how do you like to cook?'), findsOneWidget);
    await tester.tap(find.text('30 min'));
    await tester.pump();
    expect(services.profile.profile.maxTimeMinutes, 30);
    await tester.tap(find.byType(Switch));
    await settle(tester);
    expect(services.profile.profile.calorieTarget, 600);
    await next(tester);

    // 5. confirm
    expect(find.text('here you are, Robin.'), findsOneWidget);
    expect(services.profile.onboarded, isFalse);
    await tester.tap(find.text('START COOKING'));
    await settle(tester, frames: 20);
    expect(services.profile.onboarded, isTrue);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('morphcook'), findsWidgets);
  });

  testWidgets('choosing Deutsch switches the copy at once', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: false, profile: const Profile(lang: 'en'));
    await pumpApp(tester, services);
    await settle(tester);
    await tester.tap(find.text('Deutsch'));
    await settle(tester);
    expect(services.profile.profile.lang, 'de');
    expect(find.text('hallo und willkommen.'), findsOneWidget);
    expect(find.text('WEITER'), findsOneWidget);
  });

  testWidgets('the name is optional and can be skipped', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: false);
    await pumpApp(tester, services);
    await next(tester);
    await tester.tap(find.text('SKIP'));
    await settle(tester);
    expect(find.text('how do you eat?'), findsOneWidget);
    expect(services.profile.profile.name, isEmpty);
  });

  testWidgets('back returns to the previous step and keeps what was entered', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: false);
    await pumpApp(tester, services);
    await next(tester);
    await tester.enterText(find.byType(TextField), 'Kim');
    await next(tester);
    await tester.tap(find.byTooltip('back'));
    await settle(tester);
    expect(find.text('what should we call you?'), findsOneWidget);
    expect(find.text('Kim'), findsOneWidget);
  });

  testWidgets('class avoidance and specific ingredient avoidance both work in the diet step', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: false);
    await pumpApp(tester, services);
    await next(tester);
    await next(tester);

    // class avoidance: a checkbox per group
    await tester.scrollUntilVisible(find.text('dairy'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('dairy'));
    await tester.pump();
    expect(services.profile.profile.avoidFlags, contains('dairy'));

    // specific avoidance: typeahead over the dictionary
    await tester.scrollUntilVisible(find.byType(TextField), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), 'cilan');
    await tester.pump();
    expect(find.text('cilantro'), findsOneWidget);
    await tester.tap(find.text('cilantro'));
    await tester.pump();
    expect(services.profile.profile.avoidIngredients, {'cilantro'});
    expect(find.text('cilantro'), findsOneWidget, reason: 'now shown as a removable chip');

    // typing a parent offers the whole subtree
    await tester.enterText(find.byType(TextField), 'dairy');
    await tester.pump();
    expect(find.textContaining('incl. '), findsWidgets);
  });

  testWidgets('the halal and kosher note is shown next to the toggles and never claims certification', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: false);
    await pumpApp(tester, services);
    await next(tester);
    await next(tester);
    expect(find.textContaining('halal-compatible'), findsOneWidget);
    expect(find.textContaining('halal-certified'), findsNothing);
    expect(find.textContaining('kosher-certified'), findsNothing);
  });

  testWidgets('a returning person goes straight to the app', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, onboarded: true, profile: const Profile(name: 'Robin'));
    await pumpApp(tester, services);
    await settle(tester, frames: 15);
    expect(find.text('what should we call you?'), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });
}
