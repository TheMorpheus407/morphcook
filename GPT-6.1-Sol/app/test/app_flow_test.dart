import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/core/shopping.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/state/storage.dart';
import 'package:morphcook/ui/screens/backup_screen.dart';
import 'package:morphcook/ui/screens/cook_screen.dart';
import 'package:morphcook/ui/screens/dish_screen.dart';
import 'package:morphcook/ui/screens/help_screen.dart';
import 'package:morphcook/ui/screens/history_screen.dart';
import 'package:morphcook/ui/screens/insights_screen.dart';
import 'package:morphcook/ui/screens/profile_screen.dart';
import 'package:morphcook/ui/screens/settings_screen.dart';
import 'package:morphcook/ui/shell.dart';
import 'package:morphcook/ui/widgets.dart';

Future<void> loadFonts() async {
  for (final entry in {
    'Playfair Display': [
      'assets/fonts/PlayfairDisplay-Regular.ttf',
      'assets/fonts/PlayfairDisplay-Italic.ttf',
    ],
    'JetBrains Mono': ['assets/fonts/JetBrainsMono-Regular.ttf'],
    'Caveat': ['assets/fonts/Caveat-Regular.ttf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(rootBundle.load(path));
    }
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecipeRepository repository;
  setUpAll(() async {
    await loadFonts();
    repository = RecipeRepository();
    await repository.initialize();
    await repository.loadAll();
  });
  late AppState state;
  setUp(() {
    state = AppState(repository: repository, storage: MemoryStorage());
    state.profile = Profile(name: 'Alex', onboarded: true, reduceMotion: true);
  });
  tearDown(() {
    state.dispose();
  });
  void size(WidgetTester tester, double width, double height) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> boot(WidgetTester tester, [Widget? home]) async {
    await tester.pumpWidget(MorphCookApp(state: state, home: home));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'five-step onboarding edits diet and opens a persistent German cookbook',
    (tester) async {
      size(tester, 420, 920);
      state.profile.onboarded = false;
      await boot(tester);
      expect(find.text('a place at the table.'), findsOneWidget);
      await tester.tap(find.text('Deutsch'));
      await tester.pumpAndSettle();
      expect(find.text('ein Platz am Tisch.'), findsOneWidget);
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Lena');
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(ChoiceChip, 'Vegan'));
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weiter'));
      await tester.pumpAndSettle();
      expect(find.text('Hallo, Lena.'), findsOneWidget);
      await tester.tap(find.text('Mein Kochbuch öffnen'));
      await tester.pumpAndSettle();
      expect(state.profile.onboarded, isTrue);
      expect(state.profile.diet, 'vegan');
      expect(state.profile.lang, 'de');
      expect(state.profile.name, 'Lena');
      expect(find.text('DIE TÄGLICHE KÜCHE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bottom navigation reaches discover, saved recipes, weekly plan and shopping',
    (tester) async {
      size(tester, 420, 920);
      await boot(tester);
      await tester.tap(find.text('Discover'));
      await tester.pumpAndSettle();
      expect(find.text('follow your appetite.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'doener');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.byType(RecipeCard), findsWidgets);
      await tester.tap(find.text('Cookbook'));
      await tester.pumpAndSettle();
      expect(find.text('a page waiting to be filled.'), findsOneWidget);
      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();
      expect(find.text('a week at your table.'), findsOneWidget);
      await tester.tap(find.text('Shopping'));
      await tester.pumpAndSettle();
      expect(find.text('a little shopping note.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'variant rows start collapsed; changing effort selects an authored recipe',
    (tester) async {
      size(tester, 420, 920);
      await boot(
        tester,
        const DishScreen(dishId: 'doener', recipeId: 'doener-mushroom'),
      );
      expect(find.byType(ChoiceChip), findsNothing);
      await tapVisible(tester, find.text('a little effort'));
      expect(find.byType(ChoiceChip), findsWidgets);
      await tapVisible(
        tester,
        find.widgetWithText(ChoiceChip, 'A little love'),
      );
      expect(find.textContaining('weekend project'), findsWidgets);
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(state.saved.keys, ['doener-falafel']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a specific saved variant, scaled ingredients and plan assignment stay linked',
    (tester) async {
      size(tester, 420, 920);
      await boot(
        tester,
        const DishScreen(dishId: 'doener', recipeId: 'doener-mushroom'),
      );
      await tester.tap(find.byTooltip('Save'));
      await tester.pumpAndSettle();
      expect(state.saved.keys, ['doener-mushroom']);
      await tapVisible(tester, find.byTooltip('More servings'));
      await tapVisible(tester, find.text('Add ingredients'));
      expect(
        state.shopping.firstWhere((i) => i.ingredientId == 'pita').quantity,
        3,
      );
      // Let the confirmation snack bar leave the bottom action unobscured.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Add to this week'));
      await tester.tap(find.text('Dinner').first);
      await tester.pumpAndSettle();
      expect(state.mealPlan.values.single['mon.dinner'], 'doener-mushroom');
      expect(state.planServings.values.single, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cook steps persist, finish once and create a journal entry', (
    tester,
  ) async {
    size(tester, 420, 920);
    final recipe = state.repository.recipes['doener-mushroom']!;
    await boot(tester, CookScreen(recipe: recipe, initialServings: 4));
    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(state.cookProgress!['step'], 1);
    expect(state.cookProgress!['servings'], 4);
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Made with love'));
    await tester.pumpAndSettle();
    expect(find.text('look what you made.'), findsOneWidget);
    expect(state.history.single.recipeId, recipe.id);
    expect(state.history.single.servings, 4);
    expect(state.cookProgress, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging occupied meal slots swaps recipes and servings', (
    tester,
  ) async {
    size(tester, 420, 920);
    final week = weekKey(DateTime.now());
    state.assignMeal(
      week,
      'mon.lunch',
      repository.recipes['doener-mushroom']!,
      servings: 3,
    );
    state.assignMeal(
      week,
      'mon.dinner',
      repository.recipes['alfredo-classic']!,
      servings: 4,
    );
    await boot(tester);
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    final from = tester.getCenter(find.byKey(ValueKey('$week:mon.lunch')));
    final to = tester.getCenter(find.byKey(ValueKey('$week:mon.dinner')));
    final drag = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await drag.moveTo(to);
    await tester.pump(const Duration(milliseconds: 100));
    await drag.up();
    await tester.pumpAndSettle();
    expect(state.mealPlan[week]!['mon.lunch'], 'alfredo-classic');
    expect(state.mealPlan[week]!['mon.dinner'], 'doener-mushroom');
    expect(state.planServings['$week:mon.dinner'], 3);
    await tester.tap(find.text('Shop this week'));
    await tester.pumpAndSettle();
    expect(state.shopping, isNotEmpty);
    expect(state.shoppingEvents.length, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checked shopping clears without losing insights history', (
    tester,
  ) async {
    size(tester, 420, 920);
    state.addManualIngredient('garlic', 3, 'clove');
    await boot(tester);
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(state.shopping.single.checked, isTrue);
    await tester.tap(find.text('Clear checked items'));
    await tester.pumpAndSettle();
    expect(state.shopping, isEmpty);
    expect(state.shoppingEvents.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busy and archived history rows stay lazy within one week', (
    tester,
  ) async {
    size(tester, 420, 920);
    state.history = List.generate(
      500,
      (index) => CookingRecord(
        index.isEven ? 'doener-mushroom' : 'future-corpus-recipe',
        DateTime(2026, 9, 30, 12).subtract(Duration(seconds: index)),
        2,
      ),
    );
    await boot(tester, const HistoryScreen());
    expect(find.text('An archived recipe'), findsWidgets);
    expect(find.byType(ListTile).evaluate().length, lessThanOrEqualTo(50));
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile).evaluate().length, lessThanOrEqualTo(50));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'searchable help expands contextual answers and filters categories',
    (tester) async {
      size(tester, 420, 920);
      await boot(tester, const HelpScreen(initialEntry: 'backup'));
      expect(
        find.textContaining('Export opens the OS share sheet'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), 'garlic');
      await tester.pumpAndSettle();
      expect(
        find.text('How are shopping quantities combined?'),
        findsOneWidget,
      );
      expect(find.text('Where do my backups go?'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'language and accessibility preferences take effect immediately',
    (tester) async {
      size(tester, 420, 920);
      await boot(tester, const SettingsScreen());
      await tapVisible(tester, find.text('DE'));
      expect(state.profile.lang, 'de');
      expect(find.text('Sprache'), findsOneWidget);
      await tapVisible(tester, find.text('Schritt antippen zum Weitergehen'));
      expect(state.profile.quickNextTapEnabled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [360.0, 420.0, 900.0]) {
    for (final entry in <String, Widget Function()>{
      'home': () => const KitchenShell(),
      'detail': () =>
          const DishScreen(dishId: 'doener', recipeId: 'doener-mushroom'),
      'settings': () => const SettingsScreen(),
      'help': () => const HelpScreen(),
      'profile': () => const ProfileScreen(),
      'backup': () => const BackupScreen(),
      'insights': () => const InsightsScreen(),
      'history': () => const HistoryScreen(),
      'cooking': () =>
          CookScreen(recipe: state.repository.recipes['doener-mushroom']!),
    }.entries) {
      testWidgets(
        '${entry.key} renders at ${width.toInt()}px without layout errors',
        (tester) async {
          size(tester, width, 920);
          final key = GlobalKey();
          await boot(tester, RepaintBoundary(key: key, child: entry.value()));
          expect(tester.takeException(), isNull);
          if (width == 420) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final folder = Directory('build/previews');
              await folder.create(recursive: true);
              await File(
                '${folder.path}/${entry.key}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('large text remains usable on a small phone', (tester) async {
    size(tester, 360, 920);
    await tester.pumpWidget(
      MorphCookApp(
        state: state,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 920),
            textScaler: TextScaler.linear(1.8),
          ),
          child: const KitchenShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (var scroll = 0; scroll < 3; scroll++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
