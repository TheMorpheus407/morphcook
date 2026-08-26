import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/l10n.dart';
import 'package:morphcook/state/store.dart';
import 'package:morphcook/ui/home.dart';
import 'package:morphcook/ui/morph.dart';
import 'package:morphcook/ui/onboarding.dart';

import 'package:morphcook/main.dart';

void main() {
  testWidgets('boots to onboarding with a fresh store', (tester) async {
    final dir = Directory.systemTemp.createTempSync('morphcook-test');
    addTearDown(() => dir.deleteSync(recursive: true));

    late AppStore store;
    late CorpusNotifier corpus;
    await tester.runAsync(() async {
      store = AppStore(dir: dir);
      await store.load();
      store.setOnboarded(false);
      corpus = await bootCorpus();
    });

    await tester.pumpWidget(
        MorphCookApp(
            store: store, locus: LanguageNotifier('en'), corpus: corpus));
    await tester.pump();

    // Onboarding is the first screen for a fresh (un-onboarded) store,
    // not the stock counter demo.
    expect(find.byType(OnboardingPage), findsOneWidget);
    expect(
        find.text('You have pushed the button this many times:'), findsNothing);
  });

  testWidgets('boots to home once onboarded', (tester) async {
    final dir = Directory.systemTemp.createTempSync('morphcook-test');
    addTearDown(() => dir.deleteSync(recursive: true));

    late AppStore store;
    late CorpusNotifier corpus;
    await tester.runAsync(() async {
      store = AppStore(dir: dir);
      await store.load();
      store.setOnboarded(true);
      corpus = await bootCorpus();
    });

    await tester
        .pumpWidget(MorphCookApp(
            store: store, locus: LanguageNotifier('en'), corpus: corpus));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('completing root onboarding lands on home, not a dead screen',
      (tester) async {
    final dir = Directory.systemTemp.createTempSync('morphcook-test');
    addTearDown(() => dir.deleteSync(recursive: true));

    late AppStore store;
    late CorpusNotifier corpus;
    await tester.runAsync(() async {
      store = AppStore(dir: dir);
      await store.load();
      store.setOnboarded(false);
      corpus = await bootCorpus();
    });

    await tester
        .pumpWidget(MorphCookApp(
            store: store, locus: LanguageNotifier('en'), corpus: corpus));
    await tester.pump();
    expect(find.byType(OnboardingPage), findsOneWidget);

    // Tap "begin" on the ROOT onboarding (nothing to pop).
    await tester.tap(find.text('begin', findRichText: true));
    await tester.pumpAndSettle();

    expect(store.onboarded, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(OnboardingPage), findsNothing);
  });
}
