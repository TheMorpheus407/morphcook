// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/stores.dart';
import 'package:morphcook/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual captures of the key screens for human review.
/// Run: flutter test tool/visual_check_test.dart --update-goldens
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Corpus corpus;
  late AppStore store;
  late LocaleController loc;

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('vis');
    Hive.init(dir.path);
    SharedPreferences.setMockInitialValues({});
    store = await AppStore.init();
    loc = LocaleController(await SharedPreferences.getInstance());
    corpus = await Corpus.load(bundle: rootBundle);
    await (FontLoader('PlayfairDisplay')
          ..addFont(
              rootBundle.load('assets/fonts/PlayfairDisplay-Variable.ttf'))
          ..addFont(rootBundle
              .load('assets/fonts/PlayfairDisplay-Italic-Variable.ttf')))
        .load();
    await (FontLoader('JetBrainsMono')
          ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Variable.ttf'))
          ..addFont(rootBundle
              .load('assets/fonts/JetBrainsMono-Italic-Variable.ttf')))
        .load();
    await (FontLoader('Caveat')
          ..addFont(rootBundle.load('assets/fonts/Caveat-Variable.ttf')))
        .load();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> snap(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MorphCookApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('onboarding', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(
        MorphCookApp(corpus: corpus, store: store, loc: loc));
    await tester.pump(const Duration(milliseconds: 400));
    await snap(tester, '01-onboarding');
  });

  testWidgets('home', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    await tester.pumpWidget(
        MorphCookApp(corpus: corpus, store: store, loc: loc));
    await settle(tester);
    await snap(tester, '02-home');
  });

  testWidgets('dish detail', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    await tester.pumpWidget(
        MorphCookApp(corpus: corpus, store: store, loc: loc));
    await settle(tester);
    await tester.tap(find.text('search').last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'döner');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await settle(tester);
    await tester.tap(find.text('Classic Döner').first, warnIfMissed: false);
    await settle(tester);
    await snap(tester, '03-dish');
  });

  testWidgets('cook mode', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    store.updateProfile(const Profile(
        name: 'Ada', onboarded: true, calorieTarget: 400, calorieTolerance: 250));
    await tester.pumpWidget(
        MorphCookApp(corpus: corpus, store: store, loc: loc));
    await settle(tester);
    await tester.tap(find.text('search').last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'shakshuka');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.arrow_forward).first);
    await settle(tester);
    await tester.tap(find.text('Shakshuka').first, warnIfMissed: false);
    await settle(tester);
    await tester.tap(find.text('cook this').first, warnIfMissed: false);
    await settle(tester);
    await snap(tester, '04-cook-mode');
  });

  testWidgets('shopping', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    store.addShoppingEntries(const []);
    await tester.pumpWidget(
        MorphCookApp(corpus: corpus, store: store, loc: loc));
    await settle(tester);
    await tester.tap(find.text('shopping').last);
    await settle(tester);
    await snap(tester, '05-shopping');
  });

  testWidgets('planner', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    store.updateProfile(const Profile(name: 'Ada', onboarded: true));
    store.assignSlot('2026-W33', 'mon.dinner', 'doener.vegan');
    await tester.pumpWidget(
        MorphCookApp(corpus: corpus, store: store, loc: loc));
    await settle(tester);
    await tester.tap(find.text('planner').last);
    await settle(tester);
    await snap(tester, '06-planner');
  });
}
