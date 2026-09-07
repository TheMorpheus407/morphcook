import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/import/website_recipe_import.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/ui/screens/personal_recipe_editor_screen.dart';
import 'package:morphcook/ui/screens/website_import_screen.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

class FakeWebsiteImporter extends WebsiteRecipeImporter {
  int requests = 0;
  int imageRequests = 0;
  bool failPage = false;
  bool failImage = false;

  @override
  Future<List<WebsiteRecipeImport>> fetch(Uri uri) async {
    requests++;
    if (failPage) throw const FormatException('no recipe');
    return parseWebsiteRecipes(
      '<script type="application/ld+json">${jsonEncode({
        '@type': 'Recipe',
        'name': 'Imported soup',
        'recipeIngredient': ['salt to taste', '200 g carrots'],
        'recipeInstructions': ['Boil gently.'],
        'image': 'https://example.com/soup.png',
      })}</script>',
      uri,
    );
  }

  @override
  Future<Uint8List> fetchImage(Uri uri) async {
    imageRequests++;
    if (failImage) throw const FormatException('bad photo');
    return testPngBytes();
  }
}

Future<AppState> stateForImport() async {
  final state = AppState(
    store: MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  await state.completeOnboarding(const Profile(lang: 'en'));
  return state;
}

Widget importApp(AppState state, FakeWebsiteImporter importer) =>
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: morphThemeData(MorphColors.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WebsiteImportScreen(importer: importer),
                ),
              ),
              child: const Text('open import'),
            ),
          ),
        ),
      ),
    );

Future<void> loadPage(WidgetTester tester) async {
  await tester.tap(find.text('open import'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('website-url')),
    'https://example.com/soup',
  );
  await tester.tap(find.byKey(const ValueKey('fetch-website-recipe')));
  await tester.pumpAndSettle();
}

Future<void> scroll(WidgetTester tester, Finder target, double delta) =>
    tester.scrollUntilVisible(
      target,
      delta,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

Future<void> review(WidgetTester tester) async {
  await scroll(tester, find.text('Imported soup'), 250);
  await tester.tap(find.text('Imported soup'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await scroll(tester, find.byKey(const ValueKey('save-personal-recipe')), 400);
  await tester.tap(find.byKey(const ValueKey('save-personal-recipe')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'URL import stays local only after review and save; photos default off',
    (tester) async {
      final state = (await tester.runAsync(stateForImport))!;
      final importer = FakeWebsiteImporter();
      await tester.pumpWidget(importApp(state, importer));
      expect(importer.requests, 0);
      await loadPage(tester);
      expect(importer.requests, 1);
      expect(importer.imageRequests, 0);
      expect(state.personalRecipes, isEmpty);
      await review(tester);
      expect(
        find.byKey(const ValueKey('import-review-warning')),
        findsOneWidget,
      );
      expect(state.personalRecipes, isEmpty);
      await save(tester);
      final recipe = state.personalRecipes.single;
      expect(recipe.title, 'Imported soup');
      expect(recipe.sourceUrl, 'https://example.com/soup');
      expect(recipe.ingredients.first.hasQuantity, isFalse);
      expect(recipe.ingredients.first.name, 'salt to taste');
      expect(recipe.asRecipe().hasNutrition, isFalse);
      expect(state.recipeImageFor(recipe.id), isNull);
      final reloaded = AppState(store: state.store, corpus: state.corpus);
      await reloaded.load();
      expect(reloaded.personalRecipes.single.toJson(), recipe.toJson());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelling review never saves a recipe', (tester) async {
    final state = (await tester.runAsync(stateForImport))!;
    await tester.pumpWidget(importApp(state, FakeWebsiteImporter()));
    await loadPage(tester);
    await review(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(state.personalRecipes, isEmpty);
  });

  testWidgets('photo opt-in is cached with saved recipe', (tester) async {
    final state = (await tester.runAsync(stateForImport))!;
    final importer = FakeWebsiteImporter();
    await tester.pumpWidget(importApp(state, importer));
    await loadPage(tester);
    final toggle = find.byKey(const ValueKey('download-website-photo'));
    await scroll(tester, toggle, 200);
    await tester.tap(toggle);
    await review(tester);
    expect(importer.imageRequests, 1);
    await save(tester);
    expect(
      state.recipeImageFor(state.personalRecipes.single.id)!.bytes,
      testPngBytes(),
    );
  });

  testWidgets(
    'failed photo permits text-only import and page errors are recoverable',
    (tester) async {
      final state = (await tester.runAsync(stateForImport))!;
      final importer = FakeWebsiteImporter()..failPage = true;
      await tester.pumpWidget(importApp(state, importer));
      await loadPage(tester);
      expect(find.byKey(const ValueKey('website-error')), findsOneWidget);
      importer.failPage = false;
      importer.failImage = true;
      await tester.tap(find.byKey(const ValueKey('fetch-website-recipe')));
      await tester.pumpAndSettle();
      await scroll(
        tester,
        find.byKey(const ValueKey('download-website-photo')),
        200,
      );
      await tester.tap(find.byKey(const ValueKey('download-website-photo')));
      await review(tester);
      expect(find.byType(PersonalRecipeEditorScreen), findsNothing);
      await scroll(tester, find.text('continue without photo'), -200);
      await tester.tap(find.text('continue without photo'));
      await tester.pumpAndSettle();
      await save(tester);
      expect(state.personalRecipes, hasLength(1));
      expect(state.recipeImageFor(state.personalRecipes.single.id), isNull);
    },
  );

  test('older personal recipes default to measured ingredients', () {
    final ingredient = PersonalRecipeIngredient.fromJson({
      'name': 'rice',
      'qty': 200,
      'unit': 'g',
    });
    expect(ingredient.hasQuantity, isTrue);
  });
}
