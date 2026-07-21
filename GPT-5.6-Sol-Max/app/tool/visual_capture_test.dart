import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphcook/core/brand.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/user_data.dart';
import 'package:morphcook/screens/cook_mode_screen.dart';
import 'package:morphcook/screens/main_shell.dart';
import 'package:morphcook/screens/meal_plan_screen.dart';
import 'package:morphcook/screens/onboarding_screen.dart';
import 'package:morphcook/screens/recipe_detail_screen.dart';
import 'package:morphcook/services/content_repository.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/state/app_controller.dart';
import 'package:provider/provider.dart';

class _CaptureStore extends LocalStore {
  @override
  CookProgress? loadCookProgress(String recipeId) => null;

  @override
  Future<void> saveCookProgress(CookProgress progress) async {}

  @override
  Future<void> clearCookProgress(String recipeId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppController app;

  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('PlayfairDisplay')..addFont(
          rootBundle.load('assets/fonts/PlayfairDisplay-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader('JetBrainsMono')..addFont(
          rootBundle.load('assets/fonts/JetBrainsMono-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader('Caveat')..addFont(
          rootBundle.load('assets/fonts/Caveat-VariableFont_wght.ttf'),
        ))
        .load();
    await initializeDateFormatting('en_US');
    await initializeDateFormatting('de_DE');
    final content = ContentRepository();
    await content.loadCore();
    await content.loadAll();
    app = AppController(content: content, store: _CaptureStore())
      ..profile = const UserProfile(
        name: 'Mara',
        language: 'en',
        maxTimeMinutes: 90,
        calorieTarget: 600,
        calorieTolerance: 280,
        preferredEffort: 'easy',
        onboardingComplete: true,
      )
      ..initialized = true;
  });

  Future<void> setPhone(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget frame(Widget child) => ChangeNotifierProvider<AppController>.value(
    value: app,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BrandTheme.light(),
      locale: Locale(app.language),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );

  testWidgets('capture onboarding', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(frame(const OnboardingScreen()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(OnboardingScreen),
      matchesGoldenFile('design_review/onboarding.png'),
    );
  });

  testWidgets('capture home', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(frame(const MainShell()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MainShell),
      matchesGoldenFile('design_review/home.png'),
    );
  });

  testWidgets('capture recipe detail', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(
      frame(
        const RecipeDetailScreen(
          dishId: 'doener',
          initialRecipeId: 'doener-vegan-easy',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(RecipeDetailScreen),
      matchesGoldenFile('design_review/recipe-detail.png'),
    );
  });

  testWidgets('capture planner', (tester) async {
    await setPhone(tester);
    await tester.pumpWidget(frame(const Scaffold(body: MealPlanScreen())));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MealPlanScreen),
      matchesGoldenFile('design_review/meal-plan.png'),
    );
  });

  testWidgets('capture cook mode', (tester) async {
    await setPhone(tester);
    final recipe = app.content.recipeById('doener-vegan-easy')!;
    await tester.pumpWidget(
      frame(CookModeScreen(recipe: recipe, initialServings: 2)),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(CookModeScreen),
      matchesGoldenFile('design_review/cook-mode.png'),
    );
  });
}
