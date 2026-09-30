import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/features/onboarding/onboarding_flow.dart';
import 'package:morphcook/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morphcook/widgets/recipe_row.dart';

import 'support/test_app.dart';

/// The app as a person starts it: `main()` with the real storage (Hive on disk,
/// shared_preferences), the real asset bundle and the system platform services.
/// Only the operating system is replaced: a temporary folder stands in for the
/// app's documents, and "restarting" closes the boxes and starts `main()` again.
void main() {
  late Directory documents;

  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() {
    documents = Directory.systemTemp.createTempSync('morphcook_start');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => documents.path,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    await Hive.close();
    documents.deleteSync(recursive: true);
  });

  Future<void> start(WidgetTester tester, Finder until) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    await tester.runAsync(app.main);
    await tester.pump();
    await pumpUntilFound(tester, until, rounds: 200);
    await settle(tester);
  }

  /// A person closes the app: the widgets go, and so do Hive's open files. The
  /// boxes were opened under the test's fake clock, so they are closed there too
  /// and the frames keep pumping until they are shut.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    var closed = false;
    unawaited(Hive.close().whenComplete(() => closed = true));
    await settleAsync(tester, rounds: 200, until: () => closed);
    expect(closed, isTrue, reason: 'Hive closed all its boxes');
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('NEXT'));
    await settle(tester);
  }

  testWidgets('a first start shows the paper splash, then the welcome of the onboarding', (tester) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    await tester.runAsync(app.main);
    await tester.pump();
    expect(find.text('morphcook'), findsOneWidget, reason: 'the splash while storage and corpus load');
    await pumpUntilFound(tester, find.text('hello, and welcome.'), rounds: 200);
    expect(find.byType(OnboardingFlow), findsOneWidget);
  });

  testWidgets('the onboarding, a saved recipe and a restart: the second start opens the app where it was left', (
    tester,
  ) async {
    await start(tester, find.text('hello, and welcome.'));

    await next(tester);
    await tester.enterText(find.byType(TextField), 'Robin');
    await tester.pump();
    await next(tester);
    await tester.tap(find.text('vegetarian'));
    await tester.pump();
    await next(tester);
    await tester.tap(find.text('30 min'));
    await tester.pump();
    await next(tester);
    expect(find.text('here you are, Robin.'), findsOneWidget);
    await tester.tap(find.text('START COOKING'));
    await settle(tester, frames: 20);
    await settleAsync(tester, rounds: 12);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.textContaining('Robin'), findsWidgets);

    // Save the featured dish's variant from its page.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pump();
    await tester.tap(find.text('READ THE RECIPE'));
    await settle(tester, frames: 15);
    await pumpUntilFound(tester, find.byTooltip('save to cookbook'));
    await tester.tap(find.byTooltip('save to cookbook'));
    await settleAsync(tester, rounds: 6);
    expect(find.byTooltip('remove from cookbook'), findsOneWidget);

    await closeApp(tester);

    // The second start: no onboarding, the same person, the saved recipe in the cookbook.
    await start(tester, find.byType(HomeShell));
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.textContaining('Robin'), findsWidgets);
    await tester.tap(find.text('COOKBOOK'));
    await settleAsync(tester, rounds: 12);
    await settle(tester);
    expect(find.text('nothing saved yet.'), findsNothing, reason: 'the recipe saved before the restart is still there');
    expect(find.byType(RecipeRow), findsOneWidget, reason: 'exactly the one recipe that was saved');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a start with a profile from an earlier run goes straight to the app', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarded.v1': 'true',
      'profile.v1': '{"name":"Alex","lang":"de","avoid_flags":["vegan"]}',
    });
    await start(tester, find.byType(HomeShell));
    expect(find.byType(OnboardingFlow), findsNothing);
    expect(find.textContaining('Alex'), findsWidgets);
    expect(
      find.text('ein Kochbuch für jeden Körper.'),
      findsOneWidget,
      reason: 'the stored language wins over the phone language',
    );
  });

  testWidgets('the app files live in a morphcook folder of the documents and nowhere else', (tester) async {
    await start(tester, find.text('hello, and welcome.'));
    await next(tester);
    await tester.enterText(find.byType(TextField), 'Robin');
    await tester.pump();
    await closeApp(tester);
    final entries = documents
        .listSync(recursive: true)
        .map((e) => e.path.substring(documents.path.length + 1))
        .toList();
    for (final entry in entries) {
      expect(entry, anyOf(startsWith('morphcook'), isEmpty), reason: entry);
    }
  });
}
