import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/screens/detail_screen.dart';
import 'package:morphcook/screens/profile_screen.dart';
import 'package:morphcook/ui/design.dart';

AppState fixture({bool onboarded = true, String lang = 'en'}) {
  const ingredients = [
    Ingredient(
      id: 'chickpeas',
      name: {'en': 'Chickpeas', 'de': 'Kichererbsen'},
      aisle: {'en': 'Pantry', 'de': 'Vorrat'},
    ),
    Ingredient(id: 'lemon', name: {'en': 'Lemon', 'de': 'Zitrone'}),
  ];
  const steps = [
    RecipeStep(
      title: {'en': 'A little preparation', 'de': 'Ein wenig Vorbereitung'},
      text: {
        'en':
            'Drain the chickpeas and slice the lemon. Set out your favourite pan.',
        'de':
            'Kichererbsen abgießen und Zitrone schneiden. Stell deine Lieblingspfanne bereit.',
      },
    ),
    RecipeStep(
      title: {'en': 'Let it simmer', 'de': 'Köcheln lassen'},
      text: {
        'en':
            'Warm the chickpeas gently with a splash of water for two minutes.',
        'de': 'Kichererbsen mit einem Schuss Wasser zwei Minuten erwärmen.',
      },
      timerSeconds: 120,
    ),
  ];
  final recipes = List.generate(
    8,
    (i) => Recipe(
      id: i == 0
          ? 'doener-classic'
          : i == 1
          ? 'doener-vegan'
          : 'recipe-$i',
      dishId: i < 2 ? 'doener' : 'dish-$i',
      title: {
        'en': i == 0
            ? 'Classic Döner'
            : i == 1
            ? 'Vegan Döner'
            : [
                'Slow Sunday pasta',
                'Golden chickpea curry',
                'A little green risotto',
                'The breakfast club',
                'Creamy alfredo',
                'Roasted tomato soup',
              ][i - 2],
        'de': i == 0
            ? 'Klassischer Döner'
            : i == 1
            ? 'Veganer Döner'
            : 'Wärmendes Lieblingsrezept $i',
      },
      description: {
        'en':
            'Warm flatbread, golden edges, a bright little crunch. The kind of dinner that turns an ordinary day into a good one.',
        'de':
            'Warmes Fladenbrot, goldene Ränder, ein bisschen Frische. Ein Abendessen, das aus einem gewöhnlichen Tag einen guten macht.',
      },
      diet: i == 1 ? 'vegan' : 'classic',
      timeMinutes: 25,
      calories: 560,
      ingredients: const [
        RecipeIngredient(id: 'chickpeas', quantity: 400, unit: 'g'),
        RecipeIngredient(id: 'lemon', quantity: 1, unit: 'piece'),
      ],
      steps: steps,
      attributes: const {'dinner'},
      nutrition: const {'protein': 22, 'carbs': 60, 'fat': 18},
    ),
  );
  final dishes = [
    for (final r in recipes.where((r) => r.id != 'doener-vegan'))
      Dish(
        id: r.dishId,
        name: {
          'en': r.dishId == 'doener' ? 'Döner' : localized(r.title, 'en'),
          'de': r.dishId == 'doener' ? 'Döner' : localized(r.title, 'de'),
        },
        caption: const {
          'en': 'a familiar favourite, a little closer to home.',
          'de': 'ein vertrauter Liebling, ein Stück Zuhause.',
        },
        color: [
          '#526E7A',
          '#7E8B6C',
          '#B47763',
          '#AF954F',
        ][recipes.indexOf(r) % 4],
        variants: recipes
            .where((x) => x.dishId == r.dishId)
            .map((x) => x.id)
            .toList(),
      ),
  ];
  return AppState.inMemory(
    repo: Repository.fromData(
      recipes: recipes,
      dishes: dishes,
      ingredients: ingredients,
      guides: [
        {
          'id': 'chickpeas',
          'description': {
            'en': 'Lovely little legumes.',
            'de': 'Wunderbare kleine Hülsenfrüchte.',
          },
          'usage': {
            'en': 'In soups and salads.',
            'de': 'In Supppen und Salaten.',
          },
          'storage': {'en': 'Cool and dry.', 'de': 'Kühl und trocken.'},
          'where': {'en': 'Pantry aisle.', 'de': 'Bei den Vorräten.'},
        },
      ],
    ),
    profile: Profile(name: 'Jamie', lang: lang, onboarded: onboarded),
  );
}

void main() {
  testWidgets('five-step onboarding creates local profile and opens home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = fixture(onboarded: false);
    await tester.pumpWidget(MorphCookApp(state: state));
    await tester.pumpAndSettle();
    expect(find.text('a seat at the table.'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(
        find.widgetWithText(FilledButton, 'Make yourself at home'),
      );
      await tester.pumpAndSettle();
      if (i == 0) {
        await tester.enterText(find.byType(TextField).first, 'Sam');
      }
    }
    await tester.tap(
      find.widgetWithText(FilledButton, 'Welcome to your kitchen'),
    );
    await tester.pumpAndSettle();
    expect(state.profile.onboarded, isTrue);
    expect(state.profile.name, 'Sam');
    expect(find.text('hello, Sam.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('navigation search saved variants and detail tabs work', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = fixture();
    await tester.pumpWidget(MorphCookApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('discover'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'vegan');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('vegan döner'), findsOneWidget);
    await tester.tap(find.byTooltip('Save recipe'));
    await tester.pumpAndSettle();
    expect(state.saved, ['doener-vegan']);
    await tester.tap(find.text('cookbook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('vegan döner'));
    await tester.pumpAndSettle();
    expect(find.byType(DetailScreen), findsOneWidget);
    await tester.tap(find.text('Add to list'));
    await tester.pumpAndSettle();
    expect(state.shopping.length, 2);
    await tester.scrollUntilVisible(
      find.text('INGREDIENTS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('NUTRITION'));
    await tester.pumpAndSettle();
    expect(find.text('Protein'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('German profile and detail fit a small screen', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = fixture(lang: 'de');
    await tester.pumpWidget(
      MaterialApp(
        theme: morphTheme(),
        home: ProfileScreen(state: state),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MaterialApp(
        theme: morphTheme(),
        home: DetailScreen(state: state, recipe: state.repo.recipes.first),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -650),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('render mobile and tablet design previews', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
      for (final font in [
        ('Playfair Display', 'PlayfairDisplay-Regular.ttf'),
        ('Playfair Display', 'PlayfairDisplay-Italic.ttf'),
        ('JetBrains Mono', 'JetBrainsMono-Regular.ttf'),
        ('Caveat', 'Caveat-Regular.ttf'),
      ]) {
        final loader = FontLoader(font.$1)
          ..addFont(rootBundle.load('assets/fonts/${font.$2}'));
        await loader.load();
      }
    });
    for (final size in [const Size(430, 932), const Size(1200, 1250)]) {
      tester.view.physicalSize = size;
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MorphCookApp(state: fixture()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = Directory('build/previews')..createSync(recursive: true);
        File(
          '${dir.path}/home-${size.width.toInt()}.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
