import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/import/pdf_text_extractor.dart';
import 'package:morphcook/models/expert_assessment.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/ui/screens/expert_assessments_screen.dart';
import 'package:morphcook/ui/screens/pdf_import_screen.dart';
import 'package:morphcook/ui/screens/personal_recipe_editor_screen.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

class FakePdfExtractor extends PdfTextExtractor {
  String text =
      'Carrot soup\nServings: 2\nTotal time: 30 minutes\nIngredients\n200 g carrots\nInstructions\n1. Simmer gently.';
  PdfImportFailure? failure;
  int requests = 0;
  @override
  Future<String> extract(Uint8List bytes) async {
    requests++;
    if (failure != null) throw PdfImportException(failure!);
    return text;
  }
}

Future<AppState> _state() async {
  final state = AppState(
    store: MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  await state.completeOnboarding(const Profile(lang: 'en'));
  return state;
}

Widget _app(AppState state, Widget page) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(
    theme: morphThemeData(MorphColors.light),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);

Future<void> _press(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.tap(finder);
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'offscreen assessment date rejects impossible and future dates at large text sizes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 650));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = (await tester.runAsync(_state))!;
      final recipe = PersonalRecipe.create(
        title: 'Soup',
        timeMinutes: 30,
        servings: 2,
        ingredients: [
          PersonalRecipeIngredient(name: 'carrots', qty: 200, unit: 'g'),
        ],
        steps: [PersonalRecipeStep(text: 'Simmer.')],
      );
      await tester.runAsync(() => state.savePersonalRecipe(recipe));
      await tester.pumpWidget(
        _app(state, ExpertAssessmentsScreen(recipe: recipe.asRecipe())),
      );
      await _press(tester, find.text('Open'));
      await _press(
        tester,
        find.byKey(const ValueKey('record-expert-assessment')),
      );
      for (final entry in {
        'expert-name': 'Alex Example',
        'expert-qualifications': 'Recorded qualification',
        'expert-assessment': 'Context and assessment.\n' * 20,
        'expert-source': 'Private consultation.\n' * 20,
      }.entries) {
        final field = find.byKey(ValueKey(entry.key));
        await tester.ensureVisible(field);
        await tester.enterText(field, entry.value);
      }
      for (final date in ['2026-02-31', '2200-01-01']) {
        final field = find.byKey(const ValueKey('expert-date'));
        await tester.ensureVisible(field);
        await tester.enterText(field, date);
        await _press(
          tester,
          find.byKey(const ValueKey('save-expert-assessment')),
        );
        expect(state.expertAssessments, isEmpty, reason: date);
        expect(
          find.text('Enter a valid past or present date.'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'PDF requires explicit selection and draft review; cancel adds nothing',
    (tester) async {
      final state = (await tester.runAsync(_state))!;
      final extractor = FakePdfExtractor();
      await tester.pumpWidget(
        _app(
          state,
          PdfImportScreen(
            extractor: extractor,
            pickPdf: () async => ('Sonnet recipe.pdf', Uint8List.fromList([1])),
          ),
        ),
      );
      await _press(tester, find.text('Open'));
      expect(extractor.requests, 0);
      await _press(tester, find.byKey(const ValueKey('pick-pdf-recipe')));
      expect(extractor.requests, 1);
      expect(state.personalRecipes, isEmpty);
      await _press(tester, find.byKey(const ValueKey('review-pdf-recipe-0')));
      expect(find.byType(PersonalRecipeEditorScreen), findsOneWidget);
      expect(find.text('Original PDF text'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(state.personalRecipes, isEmpty);
      await _press(tester, find.byKey(const ValueKey('review-pdf-recipe-0')));
      await _press(tester, find.byKey(const ValueKey('save-personal-recipe')));
      expect(state.personalRecipes.single.title, 'Carrot soup');
      expect(
        state.personalRecipes.single.ingredients.single.name,
        contains('carrots'),
      );
      expect(state.personalRecipes.single.asRecipe().hasNutrition, isFalse);
    },
  );

  testWidgets(
    'PDF unstructured fallback preserves original text without inventing ingredients',
    (tester) async {
      final state = (await tester.runAsync(_state))!;
      final extractor = FakePdfExtractor()
        ..text =
            'My handwritten-style recipe\nBoil whatever is available.\nEnjoy!';
      await tester.pumpWidget(
        _app(
          state,
          PdfImportScreen(
            extractor: extractor,
            pickPdf: () async => ('notes.pdf', Uint8List.fromList([1])),
          ),
        ),
      );
      await _press(tester, find.text('Open'));
      await _press(tester, find.byKey(const ValueKey('pick-pdf-recipe')));
      expect(find.text('Unstructured text'), findsOneWidget);
      await _press(tester, find.byKey(const ValueKey('review-pdf-recipe-0')));
      final editor = tester.widget<PersonalRecipeEditorScreen>(
        find.byType(PersonalRecipeEditorScreen),
      );
      expect(editor.recipe, isNull);
      expect(editor.importSourceText, extractor.text);
      await _press(tester, find.byKey(const ValueKey('save-personal-recipe')));
      expect(state.personalRecipes, isEmpty);
    },
  );

  testWidgets(
    'PDF no-text failure is actionable and picker cancel leaves recipes untouched',
    (tester) async {
      final state = (await tester.runAsync(_state))!;
      final extractor = FakePdfExtractor()..failure = PdfImportFailure.noText;
      var cancel = false;
      await tester.pumpWidget(
        _app(
          state,
          PdfImportScreen(
            extractor: extractor,
            pickPdf: () async =>
                cancel ? null : ('scan.pdf', Uint8List.fromList([1])),
          ),
        ),
      );
      await _press(tester, find.text('Open'));
      await _press(tester, find.byKey(const ValueKey('pick-pdf-recipe')));
      expect(find.textContaining('Scanned PDFs need OCR'), findsOneWidget);
      cancel = true;
      await _press(tester, find.byKey(const ValueKey('pick-pdf-recipe')));
      expect(extractor.requests, 1);
      expect(state.personalRecipes, isEmpty);
    },
  );

  testWidgets(
    'expert form validates, saves attribution and displays changed-recipe warning',
    (tester) async {
      final state = (await tester.runAsync(_state))!;
      final recipe = PersonalRecipe.create(
        title: 'Soup',
        timeMinutes: 30,
        servings: 2,
        ingredients: [
          PersonalRecipeIngredient(name: 'carrots', qty: 200, unit: 'g'),
        ],
        steps: [PersonalRecipeStep(text: 'Simmer.')],
      );
      await tester.runAsync(() => state.savePersonalRecipe(recipe));
      await tester.pumpWidget(
        _app(state, ExpertAssessmentsScreen(recipe: recipe.asRecipe())),
      );
      await _press(tester, find.text('Open'));
      await _press(
        tester,
        find.byKey(const ValueKey('record-expert-assessment')),
      );
      await _press(
        tester,
        find.byKey(const ValueKey('save-expert-assessment')),
      );
      expect(state.expertAssessments, isEmpty);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      for (final field in {
        'expert-name': 'Alex Example',
        'expert-qualifications': 'Recorded qualification',
        'expert-date': '2026-01-02',
        'expert-assessment': 'Assessment received during consultation.',
      }.entries) {
        final finder = find.byKey(ValueKey(field.key));
        if (finder.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            300,
            scrollable: find.byType(Scrollable).first,
          );
        } else {
          await tester.ensureVisible(finder);
        }
        await tester.enterText(finder, field.value);
      }
      await _press(
        tester,
        find.byKey(const ValueKey('save-expert-assessment')),
      );
      expect(state.expertAssessments.single.expertName, 'Alex Example');
      await tester.runAsync(
        () => state.savePersonalRecipe(recipe.copyWith(servings: 4)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assessment-recipe-changed')),
        findsOneWidget,
      );
      expect(
        state.expertAssessments.single.recipeFingerprint,
        isNot(expertRecipeFingerprint(state.personalRecipes.single.asRecipe())),
      );
    },
  );
}
