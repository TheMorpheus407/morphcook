import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide Matcher;
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/core/corpus.dart';
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/state/storage.dart';
import 'package:morphcook/widgets/masthead.dart';
import 'package:morphcook/widgets/spine_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Smoke tests for the real app wiring: a fresh install lands on
/// onboarding, completing it reveals the five-tab shell, the spine
/// switches tabs, and the chrome follows the profile language.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late Directory tempDir;
  late Corpus corpus;
  late Matcher matcher;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('morphcook_widget_test_');
    corpus = Corpus();
    await corpus.init();
    matcher = Matcher(ontology: corpus.ontology, ingredients: corpus.ingredients);
  });

  tearDownAll(() async {
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await AppStorage.resetForTest();
    await AppStorage.initForTest(tempDir.path);
  });

  Future<AppState> freshState() async {
    final state = AppState();
    await state.init(corpus: corpus, matcher: matcher);
    return state;
  }

  Finder navLabel(String label) => find.descendant(
        of: find.byType(SpineNav),
        matching: find.text(label),
      );

  testWidgets('fresh install lands on onboarding, not the shell', (tester) async {
    final state = await freshState();
    await tester.pumpWidget(MorphCookApp(appState: state));
    await tester.pumpAndSettle();

    expect(find.text('welcome to the paper'), findsOneWidget);
    expect(find.byType(SpineNav), findsNothing);
    expect(find.byType(Masthead), findsNothing);
  });

  testWidgets('completing onboarding reveals the shell with the five spine tabs',
      (tester) async {
    final state = await freshState();
    await tester.pumpWidget(MorphCookApp(appState: state));
    await tester.pumpAndSettle();

    await state.completeOnboarding();
    await tester.pumpAndSettle();

    // masthead on the home tab
    expect(
      find.descendant(of: find.byType(Masthead), matching: find.text('morphcook')),
      findsOneWidget,
    );
    // home content; SectionLabel renders its label uppercased
    expect(find.text("TONIGHT'S LEAD STORY"), findsOneWidget);
    // all five spine tabs, english chrome
    for (final label in ['home', 'cookbook', 'week', 'market', 'settings']) {
      expect(navLabel(label), findsOneWidget, reason: 'missing nav tab "$label"');
    }
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
  });

  testWidgets('tapping the spine switches tabs', (tester) async {
    final state = await freshState();
    await state.completeOnboarding();
    await tester.pumpWidget(MorphCookApp(appState: state));
    await tester.pumpAndSettle();

    await tester.tap(navLabel('market'));
    await tester.pumpAndSettle();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);

    await tester.tap(navLabel('week'));
    await tester.pumpAndSettle();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);

    await tester.tap(navLabel('settings'));
    await tester.pumpAndSettle();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 4);
  });

  testWidgets('chrome follows the profile language (de)', (tester) async {
    final state = await freshState();
    await state.completeOnboarding();
    await state.setLang('de');
    await tester.pumpWidget(MorphCookApp(appState: state));
    await tester.pumpAndSettle();

    for (final label in ['start', 'kochbuch', 'woche', 'markt', 'einstellungen']) {
      expect(navLabel(label), findsOneWidget, reason: 'missing nav tab "$label"');
    }
    expect(navLabel('home'), findsNothing);
    // masthead name is the same in both languages
    expect(
      find.descendant(of: find.byType(Masthead), matching: find.text('morphcook')),
      findsOneWidget,
    );
  });
}
