import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/screens/detail_screen.dart';
import 'package:morphcook/screens/library_screen.dart';
import 'package:morphcook/screens/profile_screen.dart';
import 'package:morphcook/ui/design.dart';

Recipe variant(
  String id, {
  String diet = 'classic',
  String effort = 'easy',
  String calorieLevel = 'balanced',
  int calories = 500,
  Set<String> contains = const {},
  String ingredient = 'tomato',
}) => Recipe(
  id: id,
  dishId: 'pasta',
  title: {'en': id, 'de': id},
  diet: diet,
  effort: effort,
  calorieLevel: calorieLevel,
  calories: calories,
  timeMinutes: 20,
  contains: contains,
  ingredients: [RecipeIngredient(id: ingredient, quantity: 2, unit: 'piece')],
  steps: [
    const RecipeStep(
      title: {'en': 'Stir gently', 'de': 'Vorsichtig rühren'},
      text: {
        'en': 'Warm the sauce and enjoy.',
        'de': 'Die Soße erwärmen und genießen.',
      },
    ),
  ],
);
AppState flowFixture() {
  final recipes = [
    variant('classic easy', contains: {'dairy'}, ingredient: 'parmesan'),
    variant('vegan easy', diet: 'vegan'),
    variant('vegan hard', diet: 'vegan', effort: 'hard'),
    variant('keto hard', diet: 'keto', effort: 'hard'),
    variant(
      'vegan hearty',
      diet: 'vegan',
      calorieLevel: 'hearty',
      calories: 1100,
    ),
    variant(
      'classic hearty',
      contains: {'dairy'},
      ingredient: 'parmesan',
      calorieLevel: 'hearty',
      calories: 1100,
    ),
  ];
  return AppState.inMemory(
    profile: Profile(
      calorieTarget: 500,
      calorieTolerance: 100,
      onboarded: true,
      reduceMotion: true,
    ),
    repo: Repository.fromData(
      recipes: recipes,
      dishes: [
        Dish(
          id: 'pasta',
          name: const {'en': 'Pasta', 'de': 'Pasta'},
          variants: recipes.map((r) => r.id).toList(),
        ),
      ],
      ingredients: const [
        Ingredient(id: 'tomato', name: {'en': 'Tomato', 'de': 'Tomate'}),
        Ingredient(
          id: 'dairy',
          name: {'en': 'Dairy family', 'de': 'Milchfamilie'},
          flags: {'dairy'},
        ),
        Ingredient(
          id: 'cheese',
          name: {'en': 'Cheese', 'de': 'Käse'},
          parentId: 'dairy',
          flags: {'dairy'},
        ),
        Ingredient(
          id: 'parmesan',
          name: {'en': 'Parmesan', 'de': 'Parmesan'},
          parentId: 'cheese',
          flags: {'dairy'},
        ),
      ],
      ontology: {
        'flags': [
          {
            'id': 'dairy',
            'name': {'en': 'All dairy', 'de': 'Alle Milchprodukte'},
          },
        ],
        'compounds': <String, dynamic>{},
        'dimensions': [
          {
            'id': 'diet',
            'label': {'en': 'diet', 'de': 'Ernährung'},
            'values': [
              for (final id in ['classic', 'vegan', 'keto'])
                {
                  'id': id,
                  'label': {'en': id, 'de': id},
                },
            ],
          },
          {
            'id': 'effort',
            'label': {'en': 'effort', 'de': 'Aufwand'},
            'values': [
              for (final id in ['easy', 'hard'])
                {
                  'id': id,
                  'label': {'en': id, 'de': id},
                },
            ],
          },
          {
            'id': 'calorie_level',
            'label': {'en': 'calorie level', 'de': 'Kalorien'},
            'values': [
              for (final id in ['balanced', 'hearty'])
                {
                  'id': id,
                  'label': {'en': id, 'de': id},
                },
            ],
          },
        ],
      },
    ),
  );
}

Widget flowHost(Widget child, {bool tab = false}) => MaterialApp(
  theme: morphTheme(),
  home: tab ? PaperScaffold(child: child) : child,
);
void narrow(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> reveal(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'switching a dimension preserves the others and saves the specific recipe',
    (tester) async {
      narrow(tester);
      final s = flowFixture();
      await tester.pumpWidget(
        flowHost(DetailScreen(state: s, recipe: s.repo.byId('classic easy')!)),
      );
      await tester.pumpAndSettle();
      await reveal(tester, 'DIET');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'keto'))
            .onSelected,
        isNull,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'vegan'));
      await tester.pumpAndSettle();
      expect(find.text('vegan easy'), findsOneWidget);
      await reveal(tester, 'EFFORT');
      await tester.tap(find.widgetWithText(ChoiceChip, 'hard'));
      await tester.pumpAndSettle();
      expect(find.text('vegan hard'), findsOneWidget);
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'keto'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'keto'));
      await tester.pumpAndSettle();
      expect(find.text('keto hard'), findsOneWidget);
      await tester.tap(find.byTooltip('Save this recipe'));
      await tester.pumpAndSettle();
      expect(s.saved, ['keto hard']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'calorie override reveals hearty recipes but keeps dairy exclusions',
    (tester) async {
      narrow(tester);
      final s = flowFixture();
      s.updateProfile(s.profile.copy()..avoidFlags = {'dairy'});
      await tester.pumpWidget(
        flowHost(DetailScreen(state: s, recipe: s.repo.byId('vegan easy')!)),
      );
      await tester.pumpAndSettle();
      await reveal(tester, 'CALORIE LEVEL');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'hearty'))
            .onSelected,
        isNull,
      );
      await reveal(tester, 'Explore beyond my calorie target');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'hearty'))
            .onSelected,
        isNotNull,
      );
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'hearty'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'hearty'));
      await tester.pumpAndSettle();
      expect(find.text('vegan hearty'), findsOneWidget);
      await reveal(tester, 'DIET');
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'classic'))
            .onSelected,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a recipe hidden by profile filters is not logged as missing corpus content',
    (tester) async {
      narrow(tester);
      final s = flowFixture();
      s.updateProfile(s.profile.copy()..avoidFlags = {'dairy'});
      await tester.pumpWidget(
        flowHost(LibraryScreen(state: s, onOpen: (_) {}), tab: true),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'classic');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(s.contentRequests, isEmpty);
      await tester.enterText(find.byType(TextField), 'missing dumpling');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(s.contentRequests, ['missing dumpling']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'detail immediately disables cook actions when its ingredient becomes avoided',
    (tester) async {
      narrow(tester);
      final s = flowFixture();
      await tester.pumpWidget(
        flowHost(DetailScreen(state: s, recipe: s.repo.byId('classic easy')!)),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Let’s cook'),
            )
            .onPressed,
        isNotNull,
      );
      s.updateProfile(s.profile.copy()..avoidIngredients = {'dairy'});
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PrimaryButton>(
              find.widgetWithText(PrimaryButton, 'Let’s cook'),
            )
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'settings retain name and language and parent ingredient avoidance across reopen',
    (tester) async {
      narrow(tester);
      final s = flowFixture();
      await tester.pumpWidget(flowHost(ProfileScreen(state: s)));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Robin');
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(s.profile.name, 'Robin');
      expect(s.profile.lang, 'de');
      await tester.ensureVisible(find.byType(TextField).at(1));
      await tester.enterText(find.byType(TextField).at(1), 'Milchfamilie');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Milchfamilie'));
      await tester.tap(find.widgetWithText(ListTile, 'Milchfamilie'));
      await tester.pumpAndSettle();
      expect(s.profile.avoidIngredients, {'dairy'});
      expect(s.visibleRecipes().any((r) => r.id == 'classic easy'), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(flowHost(ProfileScreen(state: s)));
      await tester.pumpAndSettle();
      expect(find.text('Robin'), findsOneWidget);
      expect(find.text('ganz auf deine Art.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'canceling the backup password dialog safely disposes its text field',
    (tester) async {
      narrow(tester);
      final s = flowFixture();
      await tester.pumpWidget(flowHost(ProfileScreen(state: s)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Back up my kitchen'));
      await tester.tap(find.text('Back up my kitchen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'local password');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
