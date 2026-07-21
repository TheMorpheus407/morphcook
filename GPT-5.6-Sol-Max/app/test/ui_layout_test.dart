import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphcook/core/brand.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/user_data.dart';
import 'package:morphcook/screens/backup_screen.dart';
import 'package:morphcook/screens/cook_mode_screen.dart';
import 'package:morphcook/screens/faq_screen.dart';
import 'package:morphcook/screens/history_screen.dart';
import 'package:morphcook/screens/main_shell.dart';
import 'package:morphcook/screens/meal_plan_screen.dart';
import 'package:morphcook/screens/onboarding_screen.dart';
import 'package:morphcook/screens/profile_editor_screen.dart';
import 'package:morphcook/screens/recipe_detail_screen.dart';
import 'package:morphcook/screens/settings_screen.dart';
import 'package:morphcook/screens/shopping_insights_screen.dart';
import 'package:morphcook/services/content_repository.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/state/app_controller.dart';
import 'package:provider/provider.dart';

class _MemoryStore extends LocalStore {
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
    await initializeDateFormatting('en_US');
    await initializeDateFormatting('de_DE');
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
    final repository = ContentRepository();
    await repository.loadCore();
    await repository.loadAll();
    app = AppController(content: repository, store: _MemoryStore())
      ..profile = const UserProfile(
        name: 'Mara',
        language: 'de',
        maxTimeMinutes: 90,
        calorieTarget: 600,
        calorieTolerance: 280,
        preferredEffort: 'easy',
        onboardingComplete: true,
      )
      ..initialized = true;
  });

  Widget frame(Widget screen) => ChangeNotifierProvider<AppController>.value(
    value: app,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: BrandTheme.light(),
      locale: const Locale('de'),
      supportedLocales: const [Locale('en'), Locale('de')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: screen,
    ),
  );

  Future<void> expectCleanLayout(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(frame(screen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('core screens fit a compact German phone viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await expectCleanLayout(tester, const MainShell());
    await expectCleanLayout(
      tester,
      const RecipeDetailScreen(
        dishId: 'doener',
        initialRecipeId: 'doener-vegan-easy',
      ),
    );
    await expectCleanLayout(tester, const SettingsScreen());
    await expectCleanLayout(tester, const ProfileEditorScreen());
    await expectCleanLayout(tester, const Scaffold(body: MealPlanScreen()));
    await expectCleanLayout(tester, const FaqScreen());
    await expectCleanLayout(tester, const ShoppingInsightsScreen());
    await expectCleanLayout(tester, const HistoryScreen());
    await expectCleanLayout(tester, const BackupScreen());

    final recipe = app.content.recipeById('doener-vegan-easy')!;
    await expectCleanLayout(
      tester,
      CookModeScreen(recipe: recipe, initialServings: 2),
    );
  });

  testWidgets('onboarding fits after switching to German', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(frame(const OnboardingScreen()));
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('zuerst, deine sprache.'), findsOneWidget);
  });
}
