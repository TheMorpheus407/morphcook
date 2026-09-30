import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/features/faq/faq_screen.dart';
import 'package:morphcook/features/onboarding/onboarding_flow.dart';
import 'package:morphcook/widgets/paper_controls.dart';

import '../support/test_app.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    String? entry,
    String? category,
    String ready = 'all',
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile);
    await pumpApp(
      tester,
      services,
      home: FaqScreen(initialEntryId: entry, initialCategory: category),
    );
    await pumpUntilFound(tester, find.text(ready));
    await settle(tester, frames: 8);
  }

  /// The category chips sit in a horizontal list that builds lazily: scroll to the chip.
  Future<Finder> chip(WidgetTester tester, String label) async {
    final row = find
        .ancestor(
          of: find.byType(PaperChip),
          matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right),
        )
        .first;
    final finder = find.descendant(of: row, matching: find.text(label));
    for (var i = 0; i < 20; i++) {
      if (finder.evaluate().isNotEmpty && tester.getCenter(finder).dx < 340 && tester.getCenter(finder).dx > 0) break;
      await tester.drag(row, const Offset(-120, 0));
      await tester.pump();
    }
    return finder;
  }

  group('the Help Center', () {
    testWidgets('a search field, category filters and the entries', (tester) async {
      await open(tester);
      expect(find.text('help center'), findsOneWidget);
      expect(find.text('search the help…'), findsOneWidget);
      for (final category in [
        'all',
        'eating & matching',
        'what you see',
        'cooking',
        'plan & shop',
        'your data',
        'accessibility',
        'troubleshooting',
      ]) {
        expect(await chip(tester, category), findsOneWidget, reason: category);
      }
      expect(find.text('How does MorphCook match recipes to my diet?'), findsOneWidget);
    });

    testWidgets('tapping a question opens its answer, tapping again closes it', (tester) async {
      await open(tester);
      expect(find.textContaining('Every dish exists in many versions'), findsNothing);
      await tester.tap(find.text('How does MorphCook match recipes to my diet?'));
      await settle(tester);
      expect(find.textContaining('Every dish exists in many versions'), findsOneWidget);
      await tester.tap(find.text('How does MorphCook match recipes to my diet?'));
      await settle(tester);
      expect(find.textContaining('Every dish exists in many versions'), findsNothing);
    });

    testWidgets('free-text search narrows the list, ignoring case', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'BACKUP');
      await settle(tester);
      expect(find.text('How do I back up and restore my data?'), findsOneWidget);
      expect(find.text('Should I use a backup password, and what if I forget it?'), findsOneWidget);
      expect(find.text('How does the calorie target work?'), findsNothing);
    });

    testWidgets('a search without an answer says so, and clearing restores the list', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField), 'zzzzqq');
      await settle(tester);
      expect(find.text('no answer found.'), findsOneWidget);
      await tester.tap(find.byTooltip('clear'));
      await settle(tester);
      expect(find.text('no answer found.'), findsNothing);
      expect(find.text('How does MorphCook match recipes to my diet?'), findsOneWidget);
    });

    testWidgets('a category filter shows only that category, and tapping it again removes the filter', (tester) async {
      await open(tester);
      await tester.tap(await chip(tester, 'your data'));
      await settle(tester);
      expect(find.text('How do I back up and restore my data?'), findsOneWidget);
      expect(find.text('How does the calorie target work?'), findsNothing);
      await tester.tap(await chip(tester, 'your data'));
      await settle(tester);
      expect(find.text('How does the calorie target work?'), findsOneWidget);
    });

    testWidgets('search and category combine', (tester) async {
      await open(tester);
      await tester.tap(await chip(tester, 'troubleshooting'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'backup');
      await settle(tester);
      expect(find.text('My backup will not import.'), findsOneWidget);
      expect(find.text('How do I back up and restore my data?'), findsNothing);
    });

    testWidgets('contextual links open the entry directly, expanded', (tester) async {
      await open(tester, entry: 'backup-restore');
      expect(find.textContaining('creates two files'), findsOneWidget);
    });

    testWidgets('related entries can be followed', (tester) async {
      await open(tester, entry: 'backup-restore');
      expect(find.text('read next'), findsOneWidget);
      await tester.tap(find.text('Should I use a backup password, and what if I forget it?').last);
      await settle(tester, frames: 15);
      expect(find.textContaining('password'), findsWidgets);
    });

    testWidgets('German questions and search', (tester) async {
      await open(
        tester,
        profile: const Profile(lang: 'de'),
        ready: 'alle',
      );
      expect(find.text('Hilfe-Center'), findsOneWidget);
      expect(find.text('Wie passt MorphCook die Rezepte an meine Ernährung an?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'sicherung');
      await settle(tester);
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('an initial category is preselected', (tester) async {
      await open(tester, category: 'cooking');
      expect(find.text('How does cook mode work?'), findsOneWidget);
      expect(find.text('How do I back up and restore my data?'), findsNothing);
    });
  });

  group('contextual help from the interface', () {
    testWidgets('"how does matching work?" on the diet step opens that entry', (tester) async {
      usePhone(tester);
      await loadBundledFonts(tester);
      final services = await buildServices(tester, onboarded: false);
      await pumpApp(tester, services);
      await settle(tester);
      expect(find.byType(OnboardingFlow), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await settle(tester);
      await tester.tap(find.text('NEXT'));
      await settle(tester);
      await tester.tap(find.text('how does matching work?'));
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.textContaining('Every dish exists in many versions'));
      expect(find.byType(FaqScreen), findsOneWidget);
    });
  });
}
