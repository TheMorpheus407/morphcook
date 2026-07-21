import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/corpus_repository.dart';
import 'package:morphcook/core/engine/matching.dart';
import 'package:morphcook/core/engine/search.dart';
import 'package:morphcook/core/storage/local_store.dart';
import 'package:morphcook/core/storage/profile_store.dart';
import 'package:morphcook/core/models/profile.dart';
import 'package:morphcook/core/theme/app_theme.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/home/home_screen.dart';
import 'package:morphcook/features/onboarding/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> buildApp({
  required CorpusRepository corpus,
  required ProfileStore profileStore,
  required LocalStore localStore,
  required Widget home,
}) async {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: profileStore),
      ChangeNotifierProvider.value(value: localStore),
      Provider.value(value: corpus),
      Provider(
          create: (_) =>
              MatchingEngine(corpus.ontology, corpus.ingredientDictionary)),
      Provider(create: (ctx) => SearchEngine(corpus, ctx.read())),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: home),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CorpusRepository corpus;
  late ProfileStore profileStore;
  late LocalStore localStore;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    corpus = CorpusRepository();
    await corpus.loadCore();
    // Pre-load lazy partitions: inside testWidgets the fake-async clock
    // would starve the asset futures.
    await corpus.ensureAllLoaded();
    profileStore = ProfileStore();
    await profileStore.load();
    localStore = LocalStore(); // in-memory only; no Hive writes in tests
  });

  testWidgets('onboarding renders the language step', (tester) async {
    await tester.pumpWidget(await buildApp(
      corpus: corpus,
      profileStore: profileStore,
      localStore: localStore,
      home: const OnboardingScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('english'), findsWidgets);
    expect(find.text('deutsch'), findsWidgets);
  });

  testWidgets('home feed renders masthead and dish cards', (tester) async {
    await tester.pumpWidget(await buildApp(
      corpus: corpus,
      profileStore: profileStore,
      localStore: localStore,
      home: const HomeScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('MorphCook'), findsOneWidget);
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    // At least one core dish name should be visible in the feed.
    final dishNames = corpus.dishes
        .where((d) => d.frequencyTier == 'core')
        .map((d) => d.name['en']!)
        .toSet();
    expect(texts.any((t) => dishNames.contains(t)), isTrue,
        reason: 'no dish card rendered; texts were: $texts');
  });

  testWidgets('dish detail renders variant switchers for döner',
      (tester) async {
    await profileStore.save(const UserProfile(reduceMotion: true));
    await tester.pumpWidget(await buildApp(
      corpus: corpus,
      profileStore: profileStore,
      localStore: localStore,
      home: const DishScreen(dishId: 'doener'),
    ));
    // Let the lazy partition loads and animations complete.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
      if (find.text('döner').evaluate().isNotEmpty) break;
    }
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    expect(find.text('döner'), findsWidgets,
        reason: 'dish title missing; texts were: $texts');
    // One collapsed row per dimension axis.
    expect(find.textContaining('diet'), findsWidgets);
    expect(find.textContaining('effort'), findsWidgets);
  });
}
