import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morphcook/main.dart' show morphCookMaterialApp;
import 'package:morphcook/l10n.dart';
import 'package:morphcook/logic/profile.dart';
import 'package:morphcook/screens/cookbook_screen.dart';
import 'package:morphcook/screens/home_screen.dart';
import 'package:morphcook/screens/meal_plan_screen.dart';
import 'package:morphcook/screens/settings_screen.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:morphcook/ui/widgets.dart';import 'package:morphcook/screens/dish_screen.dart';
import 'package:morphcook/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Widget tests pause real timers, so bootstrap's file IO (Hive) must run
  /// inside [WidgetTester.runAsync] to ever complete.
  Future<AppState> bootApp(WidgetTester tester) async {
    final app = AppState();
    await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('morphcook_wt');
      await app.bootstrap(hiveDir: dir.path);
    });
    return app;
  }

  Widget host(Widget child, {Lang lang = Lang.en}) =>
      morphCookMaterialApp(lang: lang, home: child);

  testWidgets('masthead renders wordmark and dateline', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Masthead(lang: Lang.en, name: 'mo')),
    ));
    expect(find.text('morphcook'), findsOneWidget);
    expect(find.text('the same dish exists for every body'), findsOneWidget);
    expect(find.textContaining(RegExp(r'day, ')), findsOneWidget);
  });

  testWidgets('dashed rule paints without crashing', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: Center(child: SizedBox(width: 100, child: DashedRule()))),
    ));
    expect(find.byType(DashedRule), findsOneWidget);
  });

  testWidgets('polaroid card shows title, meta and tag', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PolaroidCard(
          stripeColor: AppTheme.coral,
          title: 'döner',
          subtitle: 'vegan version',
          meta: '45 min · ~590 kcal',
          tag: 'vegan',
        ),
      ),
    ));
    expect(find.text('döner'), findsNWidgets(2)); // plate caption + title
    expect(find.text('vegan version'), findsOneWidget);
    expect(find.text('45 min · ~590 kcal'), findsOneWidget);
    expect(find.text('VEGAN'), findsOneWidget);
  });

  testWidgets('striped plate paints caption', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StripedPlate(color: AppTheme.teal, caption: 'no. 01'),
      ),
    ));
    expect(find.text('no. 01'), findsOneWidget);
  });

  testWidgets('dish screen renders switchers, ingredients, method',
      (tester) async {
    final app = await bootApp(tester);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const DishScreen(dishId: 'doener')),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('döner'), findsWidgets);
    expect(find.textContaining('diet'), findsWidgets);
    expect(find.textContaining('effort'), findsWidgets);
    expect(find.textContaining('calorie'), findsWidgets);
    expect(find.textContaining('ingredients'), findsWidgets);
    // method lives below the fold in the lazy ListView — scroll to it
    await tester.scrollUntilVisible(
      find.textContaining('method'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('method'), findsOneWidget);
    // scroll into the ingredient list and check a universal döner ingredient
    await tester.scrollUntilVisible(
      find.textContaining('garlic'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('garlic'), findsWidgets);
  });

  testWidgets('dish screen vegan profile picks the vegan döner',
      (tester) async {
    final app = await bootApp(tester);
    await app.updateProfile(
        const Profile(avoidFlags: {'vegan'}, name: 'veggie'));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const DishScreen(dishId: 'doener')),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('seitan'), findsWidgets);
    expect(find.textContaining('cashew'), findsWidgets);
  });

  // ---- regression: German locale crashed every AppBar/TextField with
  // "No MaterialLocalizations found" (DefaultMaterialLocalizations is
  // English-only). The app must carry Global* delegates.
  testWidgets('German locale renders AppBar and TextField without crashing',
      (tester) async {
    final app = await bootApp(tester);
    await app.updateProfile(const Profile(lang: Lang.de, name: 'mo'));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const DishScreen(dishId: 'doener'), lang: Lang.de),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsOneWidget);
    // German masthead copy surfaced via the app bar title
    expect(find.text('döner'), findsWidgets);
  });

  testWidgets('German settings screen with TextFields does not throw',
      (tester) async {
    final app = await bootApp(tester);
    await app.updateProfile(const Profile(lang: Lang.de, name: 'mo'));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const SettingsScreen(), lang: Lang.de),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // scroll down to the backup section — the password TextField must
    // build under the German locale without a localizations crash
    await tester.scrollUntilVisible(
      find.byType(TextField),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsWidgets);
  });

  // ---- regression: CookbookScreen.dispose() called context.read on a
  // deactivated element ("Looking up a deactivated widget's ancestor is
  // unsafe"). Popping/mounting the screen must stay clean.
  testWidgets('cookbook screen builds and disposes without errors',
      (tester) async {
    final app = await bootApp(tester);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const CookbookScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // save a recipe so the pager has data, then swap the screen away.
    // Hive writes are real IO — must run inside runAsync (fake clock
    // would otherwise never release the await).
    await tester.runAsync(() => app.toggleSave('doener-vegan'));
    await tester.pump();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const MealPlanScreen()),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(CookbookScreen), findsNothing);
  });

  // ---- regression: a restrictive profile (avoided garlic+onion excludes
  // nearly every recipe) blanked the home feed entirely because it
  // hard-filtered on full profile match. The feed must always show dishes
  // (closest diet-compatible fallback, flagged) and stay clickable.
  testWidgets('restrictive profile: home still lists dishes and opens one',
      (tester) async {
    final app = await bootApp(tester);
    await app.updateProfile(
        const Profile(avoidIngredients: {'garlic', 'onion'}, name: 'mo'));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const HomeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // masthead renders despite nothing fully matching
    expect(find.text('morphcook'), findsOneWidget);
    // the fallback notice row is visible near the top
    expect(find.textContaining('closest versions'), findsOneWidget);

    // grid cards live below the fold (masthead + featured fill the
    // viewport) — drag the page down until one is built
    final gesture = await tester.startGesture(const Offset(200, 400));
    for (var i = 0;
        i < 20 && find.byType(PolaroidCard).evaluate().isEmpty;
        i++) {
      await gesture.moveBy(const Offset(0, -250));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(PolaroidCard), findsWidgets);

    // tap the featured block (its striped plate is the first one in the
    // tree, above the grid) to open a dish page
    final plate = find.byType(StripedPlate).first;
    await tester.tap(plate, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(DishScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding welcome shows title and next button',
      (tester) async {
    final app = await bootApp(tester);
    await app.stores.resetOnboarding();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: app,
      child: host(const OnboardingScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('every body gets'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
  });

  // pure config sanity: the prod delegates must cover both app locales
  test('GlobalMaterialLocalizations supports en and de', () {
    expect(
      GlobalMaterialLocalizations.delegate.isSupported(const Locale('de')),
      isTrue,
    );
    expect(
      GlobalMaterialLocalizations.delegate.isSupported(const Locale('en')),
      isTrue,
    );
  });
}
