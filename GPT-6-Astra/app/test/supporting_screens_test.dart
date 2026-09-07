import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/screens/cook_screen.dart';
import 'package:morphcook/screens/help_screen.dart';
import 'package:morphcook/screens/history_screen.dart';
import 'package:morphcook/screens/insights_screen.dart';
import 'package:morphcook/screens/planner_screen.dart';
import 'package:morphcook/screens/shopping_screen.dart';
import 'package:morphcook/ui/design.dart';

const skillet = Recipe(
  id: 'skillet-vegan',
  dishId: 'skillet',
  title: {'en': 'Vegan skillet', 'de': 'Vegane Gemüsepfanne'},
  diet: 'vegan',
  calories: 500,
  timeMinutes: 20,
  servings: 2,
  ingredients: [
    RecipeIngredient(id: 'garlic', quantity: 2, unit: 'clove'),
    RecipeIngredient(id: 'olive-oil', quantity: 1, unit: 'tbsp'),
  ],
  steps: [
    RecipeStep(
      title: {'en': 'Chop the garlic.', 'de': 'Knoblauch schneiden.'},
      text: {
        'en': 'Peel and finely chop the garlic, then warm the oil in a pan.',
        'de':
            'Den Knoblauch schälen und fein schneiden. Das Öl in einer Pfanne erwärmen.',
      },
      timerSeconds: 60,
    ),
    RecipeStep(
      title: {'en': 'Bring it together.', 'de': 'Alles zusammenbringen.'},
      text: {
        'en': 'Add the vegetables and stir gently.',
        'de': 'Das Gemüse hinzugeben und vorsichtig umrühren.',
      },
    ),
    RecipeStep(
      title: {'en': 'Time to serve.', 'de': 'Zeit zum Servieren.'},
      text: {
        'en': 'Share between two warm bowls and enjoy.',
        'de': 'Auf zwei warme Schalen verteilen und genießen.',
      },
    ),
  ],
);
const pasta = Recipe(
  id: 'pasta',
  dishId: 'pasta',
  title: {'en': 'A simple pasta', 'de': 'Einfache Pasta'},
  calories: 550,
  ingredients: [
    RecipeIngredient(id: 'garlic', quantity: 3, unit: 'clove'),
    RecipeIngredient(id: 'olive-oil', quantity: 15, unit: 'ml'),
  ],
  steps: [
    RecipeStep(text: {'en': 'Cook the pasta.', 'de': 'Pasta kochen.'}),
  ],
);
AppState fixture({
  String lang = 'en',
  bool quickTap = false,
}) => AppState.inMemory(
  profile: Profile(
    lang: lang,
    quickNextTapEnabled: quickTap,
    reduceMotion: true,
  ),
  repo: Repository.fromData(
    recipes: [skillet, pasta],
    ingredients: [
      const Ingredient(
        id: 'garlic',
        name: {'en': 'Garlic', 'de': 'Knoblauch'},
        aisle: {'en': 'Produce', 'de': 'Obst & Gemüse'},
      ),
      const Ingredient(
        id: 'olive-oil',
        name: {'en': 'Olive oil', 'de': 'Olivenöl'},
        aisle: {'en': 'Pantry', 'de': 'Vorrat'},
      ),
    ],
    faqs: [
      {
        'id': 'diet',
        'category': 'matching',
        'question': {
          'en': 'Where are my recipes?',
          'de': 'Wo sind meine Rezepte?',
        },
        'answer': {
          'en': 'Your dietary preferences decide which recipes you see.',
          'de':
              'Deine Ernährungsvorlieben bestimmen, welche Rezepte du siehst.',
        },
      },
      {
        'id': 'backup',
        'category': 'backup',
        'question': {
          'en': 'How do backups work?',
          'de': 'Wie funktionieren Backups?',
        },
        'answer': {
          'en': 'Export a file from settings and keep it somewhere safe.',
          'de':
              'Exportiere eine Datei in den Einstellungen und bewahre sie sicher auf.',
        },
      },
    ],
  ),
);
Widget host(Widget child, {double textScale = 1, bool tab = false}) =>
    MaterialApp(
      theme: morphTheme(),
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: widget!,
      ),
      home: tab ? PaperScaffold(child: child) : child,
    );
void mobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('one-handed quick navigation is opt-in and debounces for 300 ms', () {
    final controller = OneHandedCookModeController();
    var advanced = 0;
    final now = DateTime(2026, 9, 7);
    expect(
      controller.handleQuickTap(() => advanced++, timestamp: now),
      isFalse,
    );
    controller.quickNextTapEnabled = true;
    expect(controller.handleQuickTap(() => advanced++, timestamp: now), isTrue);
    expect(
      controller.handleQuickTap(
        () => advanced++,
        timestamp: now.add(const Duration(milliseconds: 299)),
      ),
      isFalse,
    );
    expect(
      controller.handleQuickTap(
        () => advanced++,
        timestamp: now.add(const Duration(milliseconds: 300)),
      ),
      isTrue,
    );
    expect(advanced, 2);
    controller.quickNextTapEnabled = false;
    expect(
      controller.handleQuickTap(
        () => advanced++,
        timestamp: now.add(const Duration(seconds: 2)),
      ),
      isFalse,
    );
    controller.dispose();
  });

  testWidgets(
    'cook timer pauses, resumes, and restores its exact recipe and step',
    (tester) async {
      mobile(tester);
      final state = fixture();
      await tester.pumpWidget(host(CookScreen(state: state, recipe: skillet)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start timer'));
      await tester.tap(find.text('Start timer'));
      await tester.pumpAndSettle();
      expect(state.cookProgress['timer_started'], isTrue);
      expect(
        DateTime.tryParse(state.cookProgress['deadline'] as String),
        isNotNull,
      );
      await tester.tap(find.byTooltip('Pause cooking'));
      await tester.pumpAndSettle();
      expect(state.cookProgress['paused'], isTrue);
      expect(state.cookProgress['deadline'], isNull);
      final remaining = state.cookProgress['remaining_seconds'];
      await tester.pump(const Duration(seconds: 5));
      expect(state.cookProgress['remaining_seconds'], remaining);
      await tester.tap(find.byTooltip('Resume cooking'));
      await tester.pumpAndSettle();
      expect(state.cookProgress['deadline'], isNotNull);
      expect(state.cookProgress['paused'], isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(host(CookScreen(state: state, recipe: skillet)));
      await tester.pumpAndSettle();
      expect(find.text('Chop the garlic.'), findsOneWidget);
      expect(find.text('Pause timer'), findsOneWidget);
      expect(state.cookProgress['step'], 0);
      expect(state.history, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'expired timer announces completion without advancing or flashing with reduced motion',
    (tester) async {
      mobile(tester);
      final state = fixture();
      state.setCookProgress({
        'recipe_id': skillet.id,
        'step': 0,
        'servings': 3,
        'timer_started': true,
        'remaining_seconds': 1,
        'deadline': DateTime.now()
            .subtract(const Duration(seconds: 5))
            .toIso8601String(),
      });
      await tester.pumpWidget(host(CookScreen(state: state, recipe: skillet)));
      await tester.pumpAndSettle();
      expect(find.text('TIME’S UP — HAVE A LOOK'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(state.cookProgress['step'], 0);
      expect(state.cookProgress['servings'], 3);
      expect(state.cookProgress['deadline'], isNull);
      final container = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(container.duration, Duration.zero);
      expect(state.history, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('cook completion clears progress and records one history entry', (
    tester,
  ) async {
    mobile(tester);
    final state = fixture(quickTap: true);
    await tester.pumpWidget(host(CookScreen(state: state, recipe: skillet)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chop the garlic.'));
    await tester.pumpAndSettle();
    expect(state.cookProgress['step'], 1);
    await tester.tap(find.text('Next step →'));
    await tester.pumpAndSettle();
    expect(state.cookProgress['step'], 2);
    expect(state.history, isEmpty);
    await tester.tap(find.text('Ready to enjoy ✓'));
    await tester.pumpAndSettle();
    expect(state.cookProgress, isEmpty);
    expect(state.history.single['recipe_id'], skillet.id);
    expect(find.text('and now,\nenjoy.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'shopping aggregates units and quantity edits retain ingredient translations',
    (tester) async {
      mobile(tester);
      final state = fixture();
      state.addRecipesToShopping([skillet, pasta]);
      await tester.pumpWidget(host(ShoppingScreen(state: state), tab: true));
      await tester.pumpAndSettle();
      expect(state.shopping.length, 2);
      expect(
        state.shopping.firstWhere((i) => i.ingredientId == 'garlic').quantity,
        5,
      );
      expect(
        state.shopping
            .firstWhere((i) => i.ingredientId == 'olive-oil')
            .quantity,
        30,
      );
      final garlicRow = find.ancestor(
        of: find.text('Garlic'),
        matching: find.byType(Dismissible),
      );
      await tester.tap(
        find.descendant(of: garlicRow, matching: find.byTooltip('Edit item')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '7');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        state.shopping.firstWhere((i) => i.ingredientId == 'garlic').quantity,
        7,
      );
      expect(
        state.shopping.firstWhere((i) => i.ingredientId == 'garlic').customName,
        isNull,
      );
      state.updateProfile(state.profile.copy()..lang = 'de');
      await tester.pumpAndSettle();
      expect(find.text('Knoblauch'), findsOneWidget);
      await tester.tap(find.text('Knoblauch'));
      await tester.pumpAndSettle();
      expect(
        state.shopping.firstWhere((i) => i.ingredientId == 'garlic').checked,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'planner assigns a recipe, moves it by drag, and exports only the selected week',
    (tester) async {
      mobile(tester);
      final state = fixture();
      final currentWeek = weekKey(DateTime.now());
      state.assignMeal(
        weekKey(DateTime.now().add(const Duration(days: 7))),
        'mon.dinner',
        pasta.id,
      );
      await tester.pumpWidget(host(PlannerScreen(state: state), tab: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vegan skillet'));
      await tester.pumpAndSettle();
      expect(state.mealPlan[currentWeek]?['mon.breakfast'], skillet.id);
      final start = tester.getCenter(find.text('Vegan skillet'));
      final end = tester.getCenter(find.byIcon(Icons.add).first);
      final gesture = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(end);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(state.mealPlan[currentWeek]?['mon.breakfast'], isNull);
      expect(state.mealPlan[currentWeek]?['mon.lunch'], skillet.id);
      await tester.ensureVisible(find.text('Make this week’s shopping list'));
      await tester.tap(find.text('Make this week’s shopping list'));
      await tester.pumpAndSettle();
      expect(
        state.shopping.firstWhere((i) => i.ingredientId == 'garlic').quantity,
        2,
      );
      expect(
        state.shopping
            .firstWhere((i) => i.ingredientId == 'olive-oil')
            .quantity,
        15,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('help search and categories find the relevant bilingual answer', (
    tester,
  ) async {
    mobile(tester);
    final state = fixture(lang: 'de');
    await tester.pumpWidget(host(HelpScreen(state: state), textScale: 1.2));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Backups');
    await tester.pumpAndSettle();
    expect(find.text('Wie funktionieren Backups?'), findsOneWidget);
    expect(find.text('Wo sind meine Rezepte?'), findsNothing);
    await tester.ensureVisible(find.text('Wie funktionieren Backups?'));
    await tester.tap(find.text('Wie funktionieren Backups?'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Exportiere eine Datei in den Einstellungen und bewahre sie sicher auf.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'history loads earlier seven-week windows and insights count recurring ingredients',
    (tester) async {
      mobile(tester);
      final state = fixture();
      state.history.addAll([
        {
          'recipe_id': skillet.id,
          'cooked_at': DateTime.now().toIso8601String(),
        },
        {
          'recipe_id': pasta.id,
          'cooked_at': DateTime.now()
              .subtract(const Duration(days: 90))
              .toIso8601String(),
        },
      ]);
      await tester.pumpWidget(host(HistoryScreen(state: state)));
      await tester.pumpAndSettle();
      expect(find.text('Vegan skillet'), findsOneWidget);
      expect(find.text('A simple pasta'), findsNothing);
      await tester.ensureVisible(find.text('Turn back seven more weeks'));
      await tester.tap(find.text('Turn back seven more weeks'));
      await tester.pumpAndSettle();
      expect(find.text('A simple pasta'), findsOneWidget);
      state.addRecipesToShopping([skillet, pasta]);
      await tester.pumpWidget(
        host(InsightsScreen(state: state), textScale: 1.2),
      );
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(find.text('2 additions'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'German supporting pages stay usable at narrow width and larger text',
    (tester) async {
      mobile(tester);
      final state = fixture(lang: 'de');
      state.addRecipesToShopping([skillet, pasta]);
      for (final page in <Widget>[
        PlannerScreen(state: state),
        ShoppingScreen(state: state),
        HelpScreen(state: state),
        InsightsScreen(state: state),
        CookScreen(state: state, recipe: skillet),
      ]) {
        await tester.pumpWidget(
          host(
            page,
            textScale: 1.3,
            tab: page is PlannerScreen || page is ShoppingScreen,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${page.runtimeType} should lay out without overflow',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );
}
