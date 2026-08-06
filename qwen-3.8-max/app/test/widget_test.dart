import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morphcook/app.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/state/app_model.dart';
import 'package:morphcook/state/library_model.dart';

Future<({AppModel app, LibraryModel library, CorpusRepository corpus})> _boot(
  WidgetTester tester, {
  Map<String, Object>? prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? {});
  // Real file IO (Hive boxes, bundled assets) must run outside FakeAsync.
  final env = await tester.runAsync(() async {
    final tempDir =
        await Directory.systemTemp.createTemp('morphcook_widget');
    addTearDown(() async {
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
    });
    Hive.init(tempDir.path);

    final app = AppModel();
    final library = LibraryModel();
    final corpus = CorpusRepository();
    await app.init();
    await library.init(directory: tempDir.path);
    await corpus.init();
    return (app: app, library: library, corpus: corpus);
  });
  return env!;
}

Widget _wrap(
    {required AppModel app,
    required LibraryModel library,
    required CorpusRepository corpus}) {
  return MorphCookApp(appModel: app, library: library, corpus: corpus);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first launch shows onboarding (language first)',
      (tester) async {
    final env = await _boot(tester);
    await tester.pumpWidget(
        _wrap(app: env.app, library: env.library, corpus: env.corpus));
    await tester.pump();

    expect(find.text('choose your language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('onboarded profile lands on the home feed with masthead',
      (tester) async {
    final env = await _boot(tester, prefs: {
      'profile.v1':
          '{"name":"Ada","lang":"en","avoid_flags":[],"avoid_ingredients":[],'
              '"required_attributes":[],"max_time_minutes":null,'
              '"calorie_target":null,"preferred_effort":"easy",'
              '"show_variant_tags":true,"reduce_motion":true,'
              '"visual_alert_enabled":true,"quick_next_tap_enabled":false}',
    });
    await tester.pumpWidget(
        _wrap(app: env.app, library: env.library, corpus: env.corpus));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // idle prefetch timer

    expect(find.text('MorphCook'), findsWidgets); // masthead wordmark
    expect(find.text('featured dish'.toUpperCase()), findsOneWidget);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('search'), findsWidgets);
  });

  testWidgets('language toggle re-renders UI strings', (tester) async {
    final env = await _boot(tester);
    await tester.pumpWidget(
        _wrap(app: env.app, library: env.library, corpus: env.corpus));
    await tester.pump();

    await tester.tap(find.text('Deutsch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('wähle deine sprache'), findsOneWidget);
    expect(env.app.lang, AppLang.de);
  });

  testWidgets('onboarding walkthrough reaches confirm', (tester) async {
    final env = await _boot(tester);
    await tester.pumpWidget(
        _wrap(app: env.app, library: env.library, corpus: env.corpus));
    await tester.pump();

    // language -> continue
    await tester.tap(find.text('continue').last);
    await tester.pumpAndSettle();
    expect(find.text('what should we call you?'), findsOneWidget);

    // name
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.tap(find.text('continue').last);
    await tester.pumpAndSettle();
    expect(find.text('how do you eat?'), findsOneWidget);

    // diet page: pick vegan
    await tester.tap(find.text('vegan').first);
    await tester.pump();
    await tester.tap(find.text('continue').last);
    await tester.pumpAndSettle();
    expect(find.text('calorie target'), findsWidgets);

    // budget page
    await tester.tap(find.text('continue').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('welcome'), findsOneWidget);

    // confirm
    await tester.tap(find.text('confirm').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(env.app.onboardingDone, isTrue);
    expect(env.app.profile.name, 'Ada');
    expect(env.app.profile.avoidFlags, contains('vegan'));
    expect(find.text('featured dish'.toUpperCase()), findsOneWidget);
  });
}
