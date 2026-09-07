import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/screens/cook_screen.dart';
import 'package:morphcook/screens/detail_screen.dart';
import 'package:morphcook/screens/planner_screen.dart';
import 'package:morphcook/screens/profile_screen.dart';
import 'package:morphcook/screens/shopping_screen.dart';
import 'package:morphcook/ui/design.dart';

void setPhone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<Repository> corpus(WidgetTester tester) async {
  final repo = Repository();
  await tester.runAsync(repo.loadAll);
  expect(repo.dishes.length, greaterThanOrEqualTo(12));
  return repo;
}

AppState actualState(Repository repo, {String lang = 'en'}) =>
    AppState.inMemory(
      repo: repo,
      profile: Profile(
        name: 'Jamie',
        lang: lang,
        calorieTarget: 600,
        calorieTolerance: 600,
        maxTimeMinutes: 120,
        reduceMotion: true,
        onboarded: true,
      ),
    );
Widget corpusHost(AppState state, Widget screen, {bool tab = false}) =>
    MaterialApp(
      theme: morphTheme(),
      debugShowCheckedModeBanner: false,
      locale: Locale(state.profile.lang),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: tab ? PaperScaffold(child: screen) : screen,
    );
Future<void> bundledFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final loaders = [
      FontLoader('Playfair Display')
        ..addFont(rootBundle.load('assets/fonts/PlayfairDisplay-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/PlayfairDisplay-Italic.ttf')),
      FontLoader('JetBrains Mono')
        ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf')),
      FontLoader('Caveat')
        ..addFont(rootBundle.load('assets/fonts/Caveat-Regular.ttf')),
      FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')),
    ];
    await Future.wait(loaders.map((loader) => loader.load()));
  });
}

Future<void> capture(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) async {
  await tester.pumpAndSettle();
  expect(
    tester.takeException(),
    isNull,
    reason: '$name must render without layout exceptions',
  );
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/previews')..createSync(recursive: true);
      await File(
        '${dir.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  testWidgets(
    'all bundled dish representatives render bilingual detail dimensions, method and cook mode',
    (tester) async {
      setPhone(tester);
      final repo = await corpus(tester);
      for (final lang in ['en', 'de']) {
        final state = actualState(repo, lang: lang);
        for (final dish in repo.dishes) {
          final recipe = state.recommended(dish);
          expect(
            recipe,
            isNotNull,
            reason:
                '${dish.id} needs a representative for the broad launch profile',
          );
          await tester.pumpWidget(
            corpusHost(state, DetailScreen(state: state, recipe: recipe!)),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${dish.id}/$lang detail header',
          );
          final dimensionCount =
              (repo.ontology['dimensions'] as List? ?? []).length;
          for (var i = 0; i < dimensionCount; i++) {
            final chevron = find.byIcon(Icons.keyboard_arrow_down).first;
            await tester.ensureVisible(chevron);
            await tester.tap(chevron);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${dish.id}/$lang dimension $i',
            );
          }
          final method = find.text(lang == 'de' ? 'ZUBEREITUNG' : 'METHOD');
          await tester.ensureVisible(method);
          await tester.tap(method);
          await tester.pumpAndSettle();
          expect(
            find.text(localized(recipe.steps.first.text, lang)),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${dish.id}/$lang method',
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            corpusHost(state, CookScreen(state: state, recipe: recipe)),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(localized(recipe.steps.first.text, lang)),
            findsOneWidget,
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '${dish.id}/$lang cook mode',
          );
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
  );

  testWidgets(
    'actual corpus allergy profile keeps only compatible recipes when calories are overridden',
    (tester) async {
      setPhone(tester);
      final repo = await corpus(tester);
      final state = actualState(repo);
      state.updateProfile(
        state.profile.copy()..avoidFlags = {'dairy', 'tree-nuts', 'peanuts'},
      );
      final allowed = state.visibleRecipes();
      expect(allowed, isNotEmpty);
      for (final recipe in allowed) {
        expect(
          visible(
            recipe,
            state.profile,
            ingredients: repo.ingredients,
            ontology: repo.ontology,
            ignoreCalories: true,
          ),
          isTrue,
        );
      }
      final recipe = allowed.first;
      await tester.pumpWidget(
        corpusHost(state, DetailScreen(state: state, recipe: recipe)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Explore beyond my calorie target'));
      await tester.tap(find.text('Explore beyond my calorie target'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Let’s cook'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'planner searches accented dish names and German ingredients from the actual index',
    (tester) async {
      setPhone(tester);
      final repo = await corpus(tester);
      final state = actualState(repo, lang: 'de');
      await tester.pumpWidget(
        corpusHost(state, PlannerScreen(state: state), tab: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Döner');
      await tester.pumpAndSettle();
      expect(
        find.byType(ListTile),
        findsWidgets,
        reason: 'Accented Döner matches normalized doner index tokens',
      );
      await tester.enterText(find.byType(TextField), 'Knoblauch');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsWidgets);
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
      final recipe = repo.byId(
        state.mealPlan[weekKey(DateTime.now())]!['mon.breakfast']!,
      )!;
      expect(
        recipe.ingredients.any(
          (i) => localized(
            repo.ingredientById(i.id)!.name,
            'de',
          ).toLowerCase().contains('knoblauch'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('capture actual cookbook screens with bundled typography', (
    tester,
  ) async {
    setPhone(tester, size: const Size(430, 932));
    final repo = await corpus(tester);
    await bundledFonts(tester);
    final state = actualState(repo);
    final recipes = repo.dishes
        .map(state.recommended)
        .whereType<Recipe>()
        .toList();
    final featured =
        recipes.where((r) => r.dishId == 'doener').firstOrNull ?? recipes.first;
    Future<GlobalKey> show(Widget child) async {
      await tester.pumpWidget(const SizedBox.shrink());
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(key: boundary, child: child));
      await tester.pumpAndSettle();
      return boundary;
    }

    var boundary = await show(MorphCookApp(state: state));
    await capture(tester, boundary, 'real-home-en');
    boundary = await show(
      corpusHost(state, ProfileScreen(state: state, onboarding: true)),
    );
    await capture(tester, boundary, 'real-onboarding-en');
    boundary = await show(
      corpusHost(state, DetailScreen(state: state, recipe: featured)),
    );
    await capture(tester, boundary, 'real-detail-en');
    final diet = find.text('DIET');
    await tester.ensureVisible(diet);
    await tester.tap(diet);
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'real-detail-variants-en');
    boundary = await show(
      corpusHost(state, CookScreen(state: state, recipe: featured)),
    );
    await capture(tester, boundary, 'real-cook-en');
    final timedStep = featured.steps.indexWhere(
      (step) => step.timerSeconds > 0,
    );
    if (timedStep >= 0) {
      for (var step = 0; step < timedStep; step++) {
        await tester.tap(find.text('Next step →'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Start timer'));
      await tester.tap(find.text('Start timer'));
      await tester.pumpAndSettle();
      await capture(tester, boundary, 'real-cook-timer-en');
    }
    await tester.pumpWidget(const SizedBox.shrink());
    final week = weekKey(DateTime.now());
    for (var i = 0; i < 7; i++) {
      state.assignMeal(
        week,
        '${['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][i]}.${i.isEven ? 'dinner' : 'lunch'}',
        recipes[i % recipes.length].id,
      );
    }
    boundary = await show(
      corpusHost(state, PlannerScreen(state: state), tab: true),
    );
    await capture(tester, boundary, 'real-planner-en');
    state.addRecipesToShopping(recipes.take(2).toList());
    boundary = await show(
      corpusHost(state, ShoppingScreen(state: state), tab: true),
    );
    await capture(tester, boundary, 'real-shopping-en');
    final german = actualState(repo, lang: 'de');
    boundary = await show(MorphCookApp(state: german));
    await capture(tester, boundary, 'real-home-de');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
