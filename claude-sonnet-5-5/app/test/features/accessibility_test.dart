import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/features/backup/backup_screen.dart';
import 'package:morphcook/features/cook/cook_screen.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/features/onboarding/onboarding_flow.dart';
import 'package:morphcook/features/settings/settings_screen.dart';

import '../support/test_app.dart';

/// Flutter's own accessibility guidelines on the main screens: tap targets of
/// 44 to 48 dp and every tappable thing labeled. Text contrast is checked on
/// the palette itself (test/core/theme_test.dart): the screenshot based
/// guideline reports clipped, faded and tilted text as failures.
void main() {
  Future<void> check(
    WidgetTester tester,
    Widget home, {
    bool onboarded = true,
    Profile profile = const Profile(name: 'Sam'),
    int settleFrames = 15,
    Future<void> Function()? after,
  }) async {
    final semantics = tester.ensureSemantics();
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(
      tester,
      profile: profile,
      onboarded: onboarded,
      now: DateTime(2026, 9, 28, 18),
    );
    await pumpApp(tester, services, home: home);
    await settleAsync(tester, rounds: 12);
    await settle(tester, frames: settleFrames);
    if (after != null) await after();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  }

  testWidgets('the front page', (tester) => check(tester, const HomeShell()));
  testWidgets('the search tab', (tester) => check(tester, const HomeShell(initialTab: 1)));
  testWidgets('the cookbook tab', (tester) => check(tester, const HomeShell(initialTab: 2)));
  testWidgets('the plan tab', (tester) => check(tester, const HomeShell(initialTab: 3)));
  testWidgets('the shopping tab', (tester) => check(tester, const HomeShell(initialTab: 4)));
  testWidgets('a dish', (tester) => check(tester, const DishScreen(dishId: 'doener')));
  testWidgets('cook mode', (tester) => check(tester, const CookScreen(recipeId: 'pancakes-classic')));
  testWidgets('settings', (tester) => check(tester, const SettingsScreen()));
  testWidgets('the help center', (tester) => check(tester, const FaqScreen()));
  testWidgets('backup and restore', (tester) => check(tester, const BackupScreen()));
  testWidgets('onboarding', (tester) => check(tester, const OnboardingFlow(), onboarded: false));
}
