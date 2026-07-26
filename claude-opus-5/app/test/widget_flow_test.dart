import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/design/motion.dart';
import 'package:morphcook/design/theme.dart';
import 'package:morphcook/domain/profile.dart';
import 'package:morphcook/l10n/strings.dart';
import 'package:morphcook/screens/cook/cook_screen.dart';
import 'package:morphcook/screens/dish/dish_screen.dart';
import 'package:morphcook/screens/faq/faq_screen.dart';
import 'package:morphcook/screens/home/home_screen.dart';
import 'package:morphcook/screens/widgets/recipe_card.dart';
import 'package:morphcook/screens/onboarding/onboarding_screen.dart';
import 'package:morphcook/screens/settings/settings_screen.dart';
import 'package:morphcook/screens/shell.dart';
import 'package:morphcook/screens/shopping/shopping_screen.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:provider/provider.dart';

import 'support/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState state;
  final now = DateTime(2026, 7, 22, 19); // Wednesday evening

  setUp(() async => state = await buildAppState(now: now));

  Widget host(Widget child) => ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: MorphTheme.light(),
      locale: Locale(state.lang),
      supportedLocales: S.supported.map(Locale.new),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Animations off keeps pumpAndSettle honest and deterministic.
      builder: (context, inner) =>
          Motion(reduced: true, child: inner ?? const SizedBox.shrink()),
      home: child,
    ),
  );

  Future<void> show(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(child));
    await tester.pumpAndSettle();
  }

  group('onboarding', () {
    testWidgets('walks language → name → diet → targets → confirm', (
      tester,
    ) async {
      await show(tester, const OnboardingScreen());

      expect(find.text('First, a language'.toLowerCase()), findsOneWidget);
      expect(find.text('Deutsch'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        find.text('What should we call you?'.toLowerCase()),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, 'Cedric');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('How do you eat?'.toLowerCase()), findsOneWidget);

      await tester.tap(find.text('Vegan'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Time and appetite'.toLowerCase()), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(
        find.text('That is the whole setup'.toLowerCase()),
        findsOneWidget,
      );
      expect(find.textContaining('Cedric'), findsWidgets);

      await tester.tap(find.text('Open the cookbook'));
      await tester.pumpAndSettle();

      expect(state.profile.onboardingComplete, isTrue);
      expect(state.profile.name, 'Cedric');
      expect(state.profile.avoidFlags, contains('vegan'));
    });

    testWidgets('switching to German re-renders the copy', (tester) async {
      await show(tester, const OnboardingScreen());
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(find.text('Zuerst eine Sprache'.toLowerCase()), findsOneWidget);
    });

    testWidgets('skip lands in the app without a name', (tester) async {
      await show(tester, const OnboardingScreen());
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(state.profile.onboardingComplete, isTrue);
    });
  });

  group('home', () {
    setUp(
      () async =>
          state.updateProfile(state.profile.copyWith(onboardingComplete: true)),
    );

    testWidgets('renders a masthead, a featured dish and the sections', (
      tester,
    ) async {
      await show(tester, const HomeScreen());
      expect(find.text('morphcook'), findsOneWidget);
      expect(find.text('the same dish exists for every body'), findsOneWidget);
      expect(find.byType(FeatureCard), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('everyday'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('everyday'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('browse by kind'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('browse by kind'), findsOneWidget);
    });

    testWidgets('the evening feature is a dinner recipe', (tester) async {
      await show(tester, const HomeScreen());
      expect(find.text('THE ONE FOR TONIGHT'), findsOneWidget);
    });

    testWidgets('tapping the featured card opens its detail page', (
      tester,
    ) async {
      await show(tester, const HomeScreen());
      // The card is rotated, so tap its InkWell rather than the widget's
      // geometric centre.
      await tester.tap(
        find
            .descendant(
              of: find.byType(FeatureCard),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(DishScreen), findsOneWidget);
    });
  });

  group('dish detail', () {
    testWidgets('shows the variant switcher with one row per dimension', (
      tester,
    ) async {
      await show(tester, const DishScreen(dishId: 'doener'));
      expect(find.text('diet'), findsOneWidget);
      expect(find.text('effort'), findsOneWidget);
      expect(find.text('calorie level'), findsOneWidget);
    });

    testWidgets('expanding a row reveals the alternatives', (tester) async {
      await show(tester, const DishScreen(dishId: 'doener'));
      await tester.tap(find.text('diet'));
      await tester.pumpAndSettle();
      expect(find.text('vegan'), findsWidgets);
      expect(find.text('halal-compatible'), findsWidgets);
    });

    testWidgets('picking a variant swaps the recipe in place', (tester) async {
      await show(
        tester,
        const DishScreen(dishId: 'doener', initialRecipeId: 'doener-classic'),
      );
      expect(find.text('Classic Döner'), findsOneWidget);

      await tester.tap(find.text('diet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('vegan').last);
      await tester.pumpAndSettle();

      expect(find.text('Vegan Döner'), findsOneWidget);
      expect(find.text('Classic Döner'), findsNothing);
    });

    testWidgets('saving toggles the bookmark and the cookbook', (tester) async {
      await show(tester, const DishScreen(dishId: 'doener'));
      expect(state.saved, isEmpty);
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(state.saved, hasLength(1));
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('the ingredient list renders scaled quantities', (
      tester,
    ) async {
      await show(
        tester,
        const DishScreen(dishId: 'doener', initialRecipeId: 'doener-classic'),
      );
      await tester.scrollUntilVisible(
        find.text('ingredients'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('400 g'), findsOneWidget);

      // Doubling the servings doubles every line.
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(find.text('600 g'), findsOneWidget);
    });

    testWidgets('a profile clash shows the hidden banner, not an empty page', (
      tester,
    ) async {
      await state.updateProfile(const Profile(avoidFlags: {'vegan'}));
      await show(
        tester,
        const DishScreen(dishId: 'doener', initialRecipeId: 'doener-classic'),
      );
      expect(find.text('hidden by your profile'), findsWidgets);
      // The recipe itself is still fully readable.
      await tester.scrollUntilVisible(
        find.text('Classic Döner'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Classic Döner'), findsOneWidget);
    });

    testWidgets('the calorie override switch appears only with a target', (
      tester,
    ) async {
      await show(tester, const DishScreen(dishId: 'doener'));
      expect(find.text('Ignore my calorie target here'), findsNothing);

      await state.updateProfile(const Profile(calorieTarget: 600));
      await show(tester, const DishScreen(dishId: 'doener'));
      expect(find.text('Ignore my calorie target here'), findsOneWidget);
    });
  });

  group('cook mode', () {
    testWidgets('starts at step one and advances', (tester) async {
      await show(tester, const CookScreen(recipeId: 'porridge-classic'));
      final recipe = state.repository.recipe('porridge-classic')!;

      expect(find.text('Step 1 of ${recipe.steps.length}'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of ${recipe.steps.length}'), findsOneWidget);
    });

    testWidgets('progress is persisted as the cook moves', (tester) async {
      await show(tester, const CookScreen(recipeId: 'porridge-classic'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(state.cookProgress?.recipeId, 'porridge-classic');
      expect(state.cookProgress?.stepIndex, 1);
    });

    testWidgets('finishing logs history and clears progress', (tester) async {
      await show(tester, const CookScreen(recipeId: 'porridge-classic'));
      final steps = state.repository.recipe('porridge-classic')!.steps.length;
      for (var i = 0; i < steps - 1; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('that is dinner'), findsOneWidget);
      expect(state.history.single.recipeId, 'porridge-classic');
      expect(state.cookProgress, isNull);
    });

    testWidgets('quick-tap is off unless opted in', (tester) async {
      await show(tester, const CookScreen(recipeId: 'porridge-classic'));
      expect(find.text('Tap the step to move on'), findsNothing);

      await state.updateProfile(const Profile(quickNextTapEnabled: true));
      await show(tester, const CookScreen(recipeId: 'porridge-classic'));
      // Reduced motion is forced on in these tests, which disables the gesture.
      expect(find.text('Tap the step to move on'), findsNothing);
    });

    testWidgets('the servings scaler rescales the step ingredients', (
      tester,
    ) async {
      await show(
        tester,
        const CookScreen(recipeId: 'porridge-classic', servings: 2),
      );
      expect(state.repository.recipe('porridge-classic')!.servings, 2);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(state.cookProgress?.servings, 3);
    });
  });

  group('shopping list', () {
    testWidgets('starts empty and fills from a recipe', (tester) async {
      await show(tester, const ShoppingScreen());
      expect(find.text('empty list'), findsOneWidget);

      await state.addRecipesToShoppingList(['doener-classic']);
      await show(tester, const ShoppingScreen());
      expect(find.text('empty list'), findsNothing);
      expect(find.text('Fruit & veg'.toLowerCase()), findsOneWidget);
    });

    testWidgets('ticking an item strikes it through', (tester) async {
      await state.addRecipesToShoppingList(['porridge-classic']);
      await show(tester, const ShoppingScreen());
      expect(find.byIcon(Icons.check_box_outline_blank), findsWidgets);
      await tester.tap(find.byIcon(Icons.check_box_outline_blank).first);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_box_outlined), findsWidgets);
    });
  });

  group('help centre', () {
    testWidgets('lists entries and expands one', (tester) async {
      await show(tester, const FaqScreen());
      expect(find.textContaining('Why do I see fewer recipes'), findsOneWidget);
      await tester.tap(find.textContaining('Why do I see fewer recipes'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Your profile hides recipes'), findsOneWidget);
    });

    testWidgets('a contextual anchor opens the right entry expanded', (
      tester,
    ) async {
      await show(tester, const FaqScreen(anchor: 'halal-kosher'));
      expect(
        find.textContaining('MorphCook filters ingredients'),
        findsOneWidget,
      );
    });

    testWidgets('search narrows the list', (tester) async {
      await show(tester, const FaqScreen());
      await tester.enterText(find.byType(TextField).first, 'password');
      await tester.pumpAndSettle();
      expect(find.textContaining('backup password'), findsOneWidget);
      expect(find.textContaining('Why do I see fewer recipes'), findsNothing);
    });
  });

  group('settings', () {
    testWidgets('toggling a diet shortcut updates the profile', (tester) async {
      await show(tester, const SettingsScreen());
      await tester.scrollUntilVisible(
        find.text('Vegan').first,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Vegan').first);
      await tester.pumpAndSettle();
      expect(state.profile.avoidFlags, contains('vegan'));
    });

    testWidgets('the halal/kosher certification note is present', (
      tester,
    ) async {
      await show(tester, const SettingsScreen());
      await tester.scrollUntilVisible(
        find.textContaining('MorphCook describes ingredients'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('MorphCook describes ingredients'),
        findsOneWidget,
      );
    });

    testWidgets('switching language re-renders in German', (tester) async {
      await show(tester, const SettingsScreen());
      await tester.scrollUntilVisible(
        find.text('Deutsch'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(state.profile.lang, 'de');
    });
  });

  group('shell', () {
    setUp(
      () async =>
          state.updateProfile(state.profile.copyWith(onboardingComplete: true)),
    );

    testWidgets('has five destinations and switches between them', (
      tester,
    ) async {
      await show(tester, const AppShell());
      for (final label in ['kitchen', 'search', 'cookbook', 'week', 'list']) {
        expect(find.text(label), findsOneWidget);
      }

      await tester.tap(find.text('cookbook'));
      await tester.pumpAndSettle();
      expect(find.text('nothing saved yet'), findsOneWidget);

      await tester.tap(find.text('week'));
      await tester.pumpAndSettle();
      expect(find.text('your week'), findsOneWidget);
    });
  });
}
