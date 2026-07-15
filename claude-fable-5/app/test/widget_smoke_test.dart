import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/ui/screens/cookbook_screen.dart';
import 'package:morphcook/ui/screens/dish_detail_screen.dart';
import 'package:morphcook/ui/screens/home_screen.dart';
import 'package:morphcook/ui/screens/onboarding_screen.dart';
import 'package:morphcook/ui/screens/personal_recipe_editor_screen.dart';
import 'package:morphcook/ui/screens/settings_screen.dart';
import 'package:morphcook/ui/strings.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

Future<AppState> onboardedState() async {
  final corpus = await loadRealCorpus();
  final state = AppState(store: MemoryStore(), corpus: corpus);
  await state.load();
  await state.completeOnboarding(const Profile(name: 'cedric', lang: 'en'));
  return state;
}

class FailOnceCollectionStore extends MemoryStore {
  bool failNextPutCollections = true;

  @override
  Future<void> putCollections(Map<String, String> collections) async {
    if (failNextPutCollections) {
      failNextPutCollections = false;
      throw StateError('simulated storage failure');
    }
    await super.putCollections(collections);
  }
}

Widget app(AppState state, Widget child) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(theme: morphThemeData(MorphColors.light), home: child),
);

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;

  testWidgets('home masthead renders and dish cards open the detail page', (
    tester,
  ) async {
    // Corpus loading does real file I/O, which never completes inside the
    // FakeAsync zone — run it on the real event loop.
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(app(state, const RootShell()));
    await tester.pumpAndSettle();

    expect(find.text('morphcook'), findsOneWidget);
    expect(find.text('edition for cedric'), findsOneWidget);

    // The grid sits below the fold in the test viewport — scroll to it,
    // then tap a card to open the dish detail.
    final homeScrollable = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(homeScrollable, const Offset(0, -700));
    await tester.pumpAndSettle();
    final firstGridCard = find.byKey(const ValueKey('home-dish-card-0'));
    expect(firstGridCard, findsOneWidget);
    await tester.ensureVisible(firstGridCard);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: firstGridCard,
        matching: find.byType(GestureDetector),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DishDetailScreen), findsOneWidget);
  });

  testWidgets('dish detail shows dimension rows and switches variants', (
    tester,
  ) async {
    final state = (await tester.runAsync(onboardedState))!;
    // Titles come from the live corpus — the lattice regenerates, the
    // test shouldn't pin prose.
    final veganTitles = (await tester.runAsync(() async {
      final dish = state.corpus.dishById('doener')!;
      final variants = await state.corpus.variantsOf(dish);
      return variants
          .where((r) => r.variant.diet == 'vegan')
          .map((r) => r.title.of('en').toLowerCase())
          .toList();
    }))!;
    expect(veganTitles, isNotEmpty);

    await tester.pumpWidget(
      app(state, const DishDetailScreen(dishId: 'doener')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('— diet'), findsOneWidget);
    expect(find.textContaining('— effort'), findsOneWidget);
    expect(find.textContaining('— calorie'), findsOneWidget);

    // Expand the diet row and pick vegan.
    await tester.tap(find.textContaining('— diet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vegan').first);
    await tester.pumpAndSettle();
    final shown = veganTitles
        .where((t) => find.text(t).evaluate().isNotEmpty)
        .toList();
    expect(
      shown,
      isNotEmpty,
      reason:
          'no vegan döner title visible after switching; '
          'expected one of $veganTitles',
    );
    // Let the ingredient highlight-flash reset timer fire before teardown.
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('recipe detail sets, renders and removes a local image', (
    tester,
  ) async {
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(
      app(
        state,
        DishDetailScreen(
          dishId: 'doener',
          pickImageBytes: () async => testPngBytes(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('set-recipe-image')));
    await tester.pumpAndSettle();
    final selectedId = state.recipeImages.single.recipeId;
    expect(
      state.recipeImageFor(selectedId)?.bytes,
      orderedEquals(testPngBytes()),
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            (widget.image as ResizeImage).imageProvider is MemoryImage,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('remove-recipe-image')));
    await tester.pumpAndSettle();
    expect(state.recipeImageFor(selectedId), isNull);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            (widget.image as ResizeImage).imageProvider is MemoryImage,
      ),
      findsNothing,
    );
  });

  testWidgets('onboarding opens the cookbook in one tap', (tester) async {
    final state = (await tester.runAsync(() async {
      final corpus = await loadRealCorpus();
      final s = AppState(store: MemoryStore(), corpus: corpus);
      await s.load();
      return s;
    }))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: morphThemeData(MorphColors.light),
          home: Builder(
            builder: (context) => context.watch<AppState>().onboarded
                ? const RootShell()
                : const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-open')));
    await tester.pumpAndSettle();
    expect(state.onboarded, isTrue);
    expect(state.profile.readableText, isTrue);
    expect(find.byType(RootShell), findsOneWidget);
  });

  testWidgets('onboarding dietary setup is optional and keeps selections', (
    tester,
  ) async {
    final state = (await tester.runAsync(() async {
      final corpus = await loadRealCorpus();
      final s = AppState(store: MemoryStore(), corpus: corpus);
      await s.load();
      return s;
    }))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: morphThemeData(MorphColors.light),
          home: Builder(
            builder: (context) => context.watch<AppState>().onboarded
                ? const RootShell()
                : const OnboardingScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-personalize')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onboarding-back')), findsOneWidget);

    await tester.tap(find.text('vegan'));
    await tester.pumpAndSettle();
    final open = find.byKey(const ValueKey('onboarding-open-personalized'));
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();

    expect(state.onboarded, isTrue);
    expect(state.profile.avoidFlags, contains('vegan'));
  });

  testWidgets('settings renders the about & support section', (tester) async {
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(app(state, const RootShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('settings'));
    await tester.pumpAndSettle();

    const en = S('en');
    final settingsScrollable = find
        .descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text(en('supportBody')),
      300,
      scrollable: settingsScrollable,
    );

    expect(find.text(en('supportBody')), findsOneWidget);
    expect(find.text(en('supportMadeBy')), findsWidgets);
    expect(find.text(en('supportPatreon')), findsOneWidget);
    expect(find.text(en('supportWebsite')), findsOneWidget);
    // The logo asset is wired up (no URL is launched in this test).
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/mo-logo.png',
      ),
      findsOneWidget,
    );
  });

  test('support copy exists in english and german', () {
    const en = S('en');
    const de = S('de');
    for (final key in [
      'aboutSupport',
      'supportMadeBy',
      'supportBody',
      'supportPatreon',
      'supportWebsite',
    ]) {
      expect(en(key), isNot(equals(key)), reason: 'missing EN $key');
      expect(de(key), isNot(equals(key)), reason: 'missing DE $key');
    }
    // Genuinely translated, not the EN fallback.
    expect(de('supportBody'), isNot(equals(en('supportBody'))));
    expect(de('supportBody'), contains('unterstützen'));
    expect(de('supportPatreon'), isNot(equals(en('supportPatreon'))));
  });

  testWidgets('appearance settings re-theme the running app in place', (
    tester,
  ) async {
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const ThemedApp()),
    );
    await tester.pumpAndSettle();

    MorphThemeData morphOf() =>
        MorphTheme.of(tester.element(find.byType(HomeScreen)));
    expect(morphOf().isDark, isFalse);
    expect(morphOf().readable, isTrue);
    expect(morphOf().text.display.fontFamily, 'Atkinson Hyperlegible');
    expect(morphOf().text.display.fontStyle, isNot(FontStyle.italic));

    await state.updateProfile(state.profile.copyWith(themeMode: 'dark'));
    await tester.pumpAndSettle();
    expect(morphOf().isDark, isTrue);
    expect(find.text('morphcook'), findsOneWidget);

    await state.updateProfile(state.profile.copyWith(readableText: false));
    await tester.pumpAndSettle();
    final morph = morphOf();
    expect(morph.readable, isFalse);
    expect(morph.text.display.fontFamily, 'Playfair Display');
    expect(morph.text.display.fontStyle, FontStyle.italic);
    expect(morph.cased('Döner Kebab'), 'döner kebab');
    expect(find.text('morphcook'), findsOneWidget);
  });

  test('appearance strings exist in english and german', () {
    const en = S('en');
    const de = S('de');
    for (final key in [
      'theme',
      'themeLight',
      'themeDark',
      'readableText',
      'readableTextHint',
    ]) {
      expect(en(key), isNot(equals(key)), reason: 'missing EN $key');
      expect(de(key), isNot(equals(key)), reason: 'missing DE $key');
    }
    expect(de('readableTextHint'), isNot(equals(en('readableTextHint'))));
  });

  test('personal recipe and image strings exist in english and german', () {
    const en = S('en');
    const de = S('de');
    for (final key in [
      'myRecipes',
      'addRecipe',
      'privateRecipeHint',
      'chooseRecipeImage',
      'changeRecipeImage',
      'removeRecipeImage',
      'recipeImageTooLarge',
      'recipeImageDimensionsTooLarge',
      'recipeImageUnsupported',
      'personalRecipeLimit',
      'personalRecipeBackupLimit',
      'personalRecipeSaveFailed',
      'personalRecipeDeleteFailed',
      'recipeImageRemoveFailed',
      'confirmBackupPassword',
      'backupPasswordsDiffer',
      'backupExportFailed',
      'backupImportFailed',
    ]) {
      expect(en(key), isNot(equals(key)), reason: 'missing EN $key');
      expect(de(key), isNot(equals(key)), reason: 'missing DE $key');
      expect(de(key), isNot(equals(en(key))), reason: 'untranslated DE $key');
    }
  });

  test('password-protected exports do not share a plaintext gzip sidecar', () {
    expect(sharePlainGzipForPassword(''), isTrue);
    expect(sharePlainGzipForPassword('secret'), isFalse);
  });

  testWidgets('cookbook shows a saved variant', (tester) async {
    final state = (await tester.runAsync(onboardedState))!;
    final savedTitle = (await tester.runAsync(() async {
      final recipe = await state.corpus.recipeById('doener-vegan');
      return recipe!.title.of('en').toLowerCase();
    }))!;
    await state.toggleSaved('doener-vegan');
    await tester.pumpWidget(app(state, const RootShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('cookbook'));
    await tester.pumpAndSettle();
    expect(find.text(savedTitle), findsOneWidget);
  });

  testWidgets('personal recipe editor creates a private recipe', (
    tester,
  ) async {
    final state = (await tester.runAsync(onboardedState))!;
    await tester.pumpWidget(app(state, const PersonalRecipeEditorScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('recipe-title')),
      'My tomato toast',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ingredient-name-0')),
      'Tomato',
    );
    final editorScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('step-text-0')),
      300,
      scrollable: editorScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('step-text-0')),
      'Toast and top.',
    );
    final save = find.byKey(const ValueKey('save-personal-recipe'));
    await tester.scrollUntilVisible(save, 450, scrollable: editorScroll);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(state.personalRecipes, hasLength(1));
    expect(state.personalRecipes.single.title, 'My tomato toast');
    expect(state.isSaved(state.personalRecipes.single.id), isTrue);
  });

  testWidgets('personal recipe save failure is recoverable in the editor', (
    tester,
  ) async {
    final state = (await tester.runAsync(() async {
      final corpus = await loadRealCorpus();
      final value = AppState(store: FailOnceCollectionStore(), corpus: corpus);
      await value.load();
      return value;
    }))!;
    await tester.pumpWidget(app(state, const PersonalRecipeEditorScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('recipe-title')),
      'My tomato toast',
    );
    await tester.enterText(
      find.byKey(const ValueKey('ingredient-name-0')),
      'Tomato',
    );
    final editorScroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('step-text-0')),
      300,
      scrollable: editorScroll,
    );
    await tester.enterText(
      find.byKey(const ValueKey('step-text-0')),
      'Toast and top.',
    );
    final save = find.byKey(const ValueKey('save-personal-recipe'));
    await tester.scrollUntilVisible(save, 450, scrollable: editorScroll);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.text(const S('en')('personalRecipeSaveFailed')),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(state.personalRecipes, isEmpty);
  });

  testWidgets('personal recipe editor preserves a custom imported unit', (
    tester,
  ) async {
    final state = (await tester.runAsync(onboardedState))!;
    final personal = PersonalRecipe(
      id: 'personal-fedcba9876543210fedcba9876543210',
      title: 'Imported biscuits',
      timeMinutes: 20,
      servings: 4,
      ingredients: [
        PersonalRecipeIngredient(name: 'Butter', qty: 4, unit: 'oz'),
      ],
      steps: [PersonalRecipeStep(text: 'Mix.')],
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await tester.pumpWidget(
      app(state, PersonalRecipeEditorScreen(recipe: personal)),
    );
    await tester.pumpAndSettle();

    final unit = find.byKey(const ValueKey('ingredient-unit-0'));
    expect(tester.widget<TextField>(unit).controller?.text, 'oz');
    await tester.enterText(unit, 'packet');
    expect(tester.widget<TextField>(unit).controller?.text, 'packet');
  });

  testWidgets('cookbook opens a personal recipe without lattice controls', (
    tester,
  ) async {
    final state = (await tester.runAsync(onboardedState))!;
    final personal = PersonalRecipe(
      id: 'personal-0123456789abcdef0123456789abcdef',
      title: 'My soup',
      timeMinutes: 20,
      servings: 2,
      ingredients: [
        PersonalRecipeIngredient(name: 'Carrot', qty: 2, unit: 'piece'),
      ],
      steps: [PersonalRecipeStep(text: 'Simmer.')],
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
    await state.savePersonalRecipe(personal);
    await tester.pumpWidget(app(state, const Scaffold(body: CookbookScreen())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('my recipes'));
    await tester.pumpAndSettle();
    expect(find.text('My soup'), findsOneWidget);
    await tester.tap(find.text('My soup'));
    await tester.pumpAndSettle();

    expect(find.byType(DishDetailScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-personal-recipe')), findsOneWidget);
    expect(find.textContaining('— diet'), findsNothing);
    expect(find.text('macros'), findsNothing);
    expect(find.textContaining('kept only on this device'), findsOneWidget);
  });
}
