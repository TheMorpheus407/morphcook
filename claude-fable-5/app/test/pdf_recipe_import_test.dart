import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/import/pdf_recipe_import.dart';
import 'package:morphcook/models/personal_recipe.dart';

const _english = '''Creamy Tomato Soup
A comforting soup generated for a weeknight dinner.
Servings: 4
Prep time: 15 minutes
Cook time: 25 minutes

Ingredients
• 750 g tomatoes,
  roughly chopped
• 1½ tablespoons olive oil
• 2 cups vegetable broth
• Salt and black pepper to taste

Instructions
1. Heat the oil in a large saucepan.
   Add the tomatoes and stir until softened.
2. Pour in the broth and simmer for 25 minutes.
3. Blend until smooth, season and serve.

Notes
Serve with toasted bread.
''';

const _german = '''## Rezept: Ofengemüse mit Kräutern
**Vorbereitungszeit:** 15 Minuten
**Backzeit:** 30 Minuten
**Portionen:** 3

### Zutaten
Für das Gemüse:
- 500 g Kartoffeln
- 1,5 EL Olivenöl
- Salz nach Geschmack
Für die Sauce:
- 1 cup yogurt plus 2 tablespoons

### Zubereitung
Schritt 1: Das Gemüse waschen und klein schneiden.
Schritt 2: Mit Öl und Kräutern vermischen.
  Auf einem Blech verteilen.
Schritt 3: Im Ofen backen und mit der Sauce servieren.

### Tipps
Die Sauce separat anrichten.
''';

void main() {
  test(
    'English generated recipe supports wrapped bullets and numbered instructions',
    () {
      final imported = parsePdfRecipeText(
        _english,
        filename: 'recipe.pdf',
      ).single;
      expect(imported.isStructured, isTrue);
      expect(imported.sourceText, _english);
      expect(imported.usedDefaultTime, isFalse);
      expect(imported.usedDefaultServings, isFalse);
      final recipe = imported.recipe!;
      expect(recipe.title, 'Creamy Tomato Soup');
      expect(recipe.timeMinutes, 40);
      expect(recipe.servings, 4);
      expect(recipe.ingredients, hasLength(4));
      expect(recipe.ingredients[0].qty, 750);
      expect(recipe.ingredients[0].name, 'tomatoes, roughly chopped');
      expect(recipe.ingredients[1].qty, 1.5);
      expect(recipe.ingredients[1].unit, 'tbsp');
      expect(recipe.ingredients.last.name, 'Salt and black pepper to taste');
      expect(recipe.ingredients.last.hasQuantity, isFalse);
      expect(recipe.steps, hasLength(3));
      expect(
        recipe.steps.first.text,
        'Heat the oil in a large saucepan. Add the tomatoes and stir until softened.',
      );
      expect(
        recipe.description,
        contains('A comforting soup generated for a weeknight dinner.'),
      );
      expect(recipe.description, contains('Serve with toasted bread.'));
    },
  );

  test(
    'German markdown headings, groups and comma quantities remain editable',
    () {
      final imported = parsePdfRecipeText(_german).single;
      final recipe = imported.recipe!;
      expect(recipe.title, 'Ofengemüse mit Kräutern');
      expect(recipe.timeMinutes, 45);
      expect(recipe.servings, 3);
      expect(recipe.ingredients, hasLength(4));
      expect(recipe.ingredients.first.note, 'Für das Gemüse');
      expect(recipe.ingredients[1].qty, 1.5);
      expect(recipe.ingredients[1].unit, 'tbsp');
      expect(recipe.ingredients.last.name, '1 cup yogurt plus 2 tablespoons');
      expect(recipe.ingredients.last.hasQuantity, isFalse);
      expect(recipe.ingredients.last.note, 'Für die Sauce');
      expect(
        recipe.steps[1].text,
        'Mit Öl und Kräutern vermischen. Auf einem Blech verteilen.',
      );
      expect(recipe.description, contains('Die Sauce separat anrichten.'));
      final edited = PersonalRecipe.fromJson(
        recipe.copyWith(title: 'My version').toJson(),
      );
      expect(edited.ingredients.last.hasQuantity, isFalse);
      expect(edited.ingredients.last.note, 'Für die Sauce');
    },
  );

  test('plain lists and paragraph instructions do not require markdown', () {
    const source = '''Easy rice
Total time: 1 hour and 5 minutes
Ingredients (for 6 servings)
250 g rice
500 ml water
Salt to taste
Method
Wash the rice.
Drain it carefully.

Add water, cover and cook.
''';
    final imported = parsePdfRecipeText(source).single;
    expect(imported.recipe!.servings, 6);
    expect(imported.recipe!.timeMinutes, 65);
    expect(imported.recipe!.ingredients, hasLength(3));
    expect(imported.recipe!.steps.map((step) => step.text), [
      'Wash the rice. Drain it carefully.',
      'Add water, cover and cook.',
    ]);
  });

  test('explicit multiple recipes split without losing any original text', () {
    const source = '''Recipes for friends
Recipe 1: Rice
Time: 20 min
Servings: 2
Ingredients
- 200 g rice
Instructions
1. Boil.

Rezept 2: Suppe
Zeit: 30 Minuten
Für 4 Personen
Zutaten
- 1 l Wasser
Zubereitung
1. Kochen.
''';
    final imported = parsePdfRecipeText(source);
    expect(imported, hasLength(2));
    expect(imported.every((entry) => entry.isStructured), isTrue);
    expect(imported.map((entry) => entry.recipe!.title), ['Rice', 'Suppe']);
    expect(imported.map((entry) => entry.recipe!.servings), [2, 4]);
    expect(imported.map((entry) => entry.sourceText).join(), source);
    expect(imported.first.recipe!.description, contains('Recipes for friends'));
  });

  test(
    'unknown or incomplete structures preserve exact source without fabricated ingredients',
    () {
      for (final source in [
        'A handwritten-style suggestion: chop what you have and cook it.',
        'Soup\nIngredients\n200 g carrots\nThere are no instruction headings.',
        'Soup\nIngredients\n\nInstructions\nCook it.',
        'Soup\nIngredients\n200 g carrots\nInstructions\n',
        'Recipe: One\nIngredients\n200 g rice\nMethod\nCook.\nRecipe: Two\nIncomplete second recipe.',
        'Rice\nIngredients\n200 g rice\nMethod\nBoil.\nSoup\nIngredients\n1 l water\nMethod\nHeat.',
      ]) {
        final imported = parsePdfRecipeText(source).single;
        expect(imported.recipe, isNull);
        expect(imported.isStructured, isFalse);
        expect(imported.sourceText, source);
      }
    },
  );

  test(
    'defaults are explicit and ambiguous yields or times are never guessed',
    () {
      for (final metadata in [
        '',
        'Servings: 4-6\nTotal time: 30–45 minutes',
        'Yield: 1 cake\nTime: 1 hour (including 20 minutes prep)',
        'Servings: 4.5\nTime: unknown',
        'Servings: 0\nTime: PT999H',
        'Time: ${'9' * 400} hours',
      ]) {
        final source =
            'Soup\n$metadata\nIngredients\n200 g carrots\nInstructions\nSimmer.';
        final imported = parsePdfRecipeText(source).single;
        expect(imported.isStructured, isTrue);
        expect(imported.usedDefaultServings, isTrue);
        expect(imported.usedDefaultTime, isTrue);
        expect(imported.recipe!.servings, 2);
        expect(imported.recipe!.timeMinutes, 30);
        expect(imported.sourceText, source);
      }
    },
  );

  test(
    'total time takes precedence, supports decimal hours and German minutes',
    () {
      for (final (metadata, time) in [
        (
          'Prep time: 10 minutes\nCook time: 20 minutes\nTotal time: 35 minutes',
          35,
        ),
        ('Gesamtzeit: 1,5 Stunden', 90),
        ('Zeit: 2 Stunden und 5 Minuten', 125),
        ('Time: 1 minute 30 seconds', 2),
      ]) {
        final source =
            'Soup\n$metadata\nIngredients\n200 g carrots\nInstructions\nSimmer.';
        final imported = parsePdfRecipeText(source).single;
        expect(imported.recipe!.timeMinutes, time);
        expect(imported.usedDefaultTime, isFalse);
      }
    },
  );

  test('CRLF, page breaks and labeled page footers preserve source exactly', () {
    const source =
        'Soup\r\nIngredients\r\n• 200 g carrots\r\nPage 1 of 2\f\r\n• Salt to taste\r\nInstructions\r\n1) Cut carrots.\r\n2) Cook.\r\nSeite 2 von 2\r\n';
    final imported = parsePdfRecipeText(source).single;
    expect(imported.sourceText, source);
    expect(imported.recipe!.ingredients, hasLength(2));
    expect(imported.recipe!.steps.map((step) => step.text), [
      'Cut carrots.',
      'Cook.',
    ]);
  });

  test(
    'filename supplies a missing title without becoming a fake website source',
    () {
      final imported = parsePdfRecipeText(
        'Ingredients\n200 g carrots\nInstructions\nSimmer.',
        filename: '/picked/My soup.PDF',
      ).single;
      expect(imported.recipe!.title, 'My soup');
      expect(imported.recipe!.sourceUrl, isNull);
      expect(imported.recipe!.sourceAuthor, isNull);
    },
  );

  test(
    'ingredient, step, title and note limits fall back intact instead of truncating',
    () {
      for (final source in [
        'Soup\nIngredients\n${List.filled(101, '- 1 g salt').join('\n')}\nInstructions\nCook.',
        'Soup\nIngredients\n1 g salt\nInstructions\n${List.generate(101, (i) => '${i + 1}. Stir.').join('\n')}',
        '${'x' * 201}\nIngredients\n1 g salt\nInstructions\nCook.',
        'Soup\nIngredients\n1 g salt\nInstructions\n${'x' * 5001}',
        'Soup\nIngredients\n1 g salt\nInstructions\nCook.\nNotes\n${'x' * 5001}',
      ]) {
        final imported = parsePdfRecipeText(source).single;
        expect(imported.isStructured, isFalse);
        expect(imported.sourceText, source);
      }
    },
  );

  test(
    'empty and oversized extraction fail explicitly and max-sized plain text remains intact',
    () {
      expect(
        () => parsePdfRecipeText(' \r\n\t'),
        throwsA(
          isA<PdfRecipeTextException>().having(
            (e) => e.failure,
            'reason',
            PdfRecipeTextFailure.empty,
          ),
        ),
      );
      expect(
        () => parsePdfRecipeText('x' * (maxPdfRecipeTextCharacters + 1)),
        throwsA(
          isA<PdfRecipeTextException>().having(
            (e) => e.failure,
            'reason',
            PdfRecipeTextFailure.tooLarge,
          ),
        ),
      );
      final text = 'x' * maxPdfRecipeTextCharacters;
      final imported = parsePdfRecipeText(text).single;
      expect(imported.isStructured, isFalse);
      expect(imported.sourceText, text);
    },
  );

  test('long internal underscore runs remain a fast, intact fallback', () {
    final source = 'a${'_' * 190000}b';
    final watch = Stopwatch()..start();
    final imported = parsePdfRecipeText(source).single;
    watch.stop();
    expect(imported.isStructured, isFalse);
    expect(imported.sourceText, source);
    // Generous allowance for slow CI; the former trailing-marker regex takes
    // tens of seconds on this permitted input and blocks the app's UI isolate.
    expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test(
    'oversized wrapped ingredient retains every continuation in fallback',
    () {
      final source =
          'Soup\nIngredients\n- salt,\n${' a\n' * 60000}Instructions\nCook.';
      expect(source.length, lessThan(maxPdfRecipeTextCharacters));
      final watch = Stopwatch()..start();
      final imported = parsePdfRecipeText(source).single;
      watch.stop();
      expect(imported.isStructured, isFalse);
      expect(imported.sourceText, source);
      expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
    },
  );

  test(
    'long malformed metadata and title markers return promptly and intact',
    () {
      for (final line in [
        'Time: ${'9' * 190000} x',
        'Servings: ${' ' * 190000}x',
        'Recipe ${' ' * 190000}x',
        'Page 1 ${' ' * 190000}x',
        'Ingredients (for ${' ' * 190000}x)',
      ]) {
        final source =
            'Soup\n$line\nIngredients\n200 g carrots\nInstructions\nSimmer.';
        expect(source.length, lessThan(maxPdfRecipeTextCharacters));
        final watch = Stopwatch()..start();
        final imported = parsePdfRecipeText(source).single;
        watch.stop();
        expect(imported.isStructured, isFalse);
        expect(imported.sourceText, source);
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      }
    },
  );

  test(
    'oversized duration within a normal metadata line uses explicit default',
    () {
      final source =
          'Soup\nTime: ${'9' * 400} x\nServings: 4\n'
          'Ingredients\n200 g carrots\nInstructions\nSimmer.';
      final imported = parsePdfRecipeText(source).single;
      expect(imported.isStructured, isTrue);
      expect(imported.usedDefaultTime, isTrue);
      expect(imported.usedDefaultServings, isFalse);
      expect(imported.recipe!.timeMinutes, 30);
      expect(imported.recipe!.servings, 4);
      expect(imported.sourceText, source);
    },
  );

  test(
    'wrapped ingredient name at the model limit still accepts its amount',
    () {
      final name = 'a' * maxPersonalIngredientNameLength;
      final source =
          'Soup\nIngredients\n- 200 g ${name.substring(0, 100)},\n'
          '${name.substring(102)}\nInstructions\nCook.';
      final imported = parsePdfRecipeText(source).single;
      expect(imported.isStructured, isTrue);
      expect(
        imported.recipe!.ingredients.single.name.length,
        maxPersonalIngredientNameLength,
      );
      expect(imported.recipe!.ingredients.single.qty, 200);
      expect(imported.recipe!.ingredients.single.unit, 'g');
    },
  );

  test(
    'PDF titles and nutrition prose never create verified diet or nutrition',
    () {
      const source =
          'Vegan gluten-free soup\nIngredients\n200 g carrots\nInstructions\nCook.\nNutrition\nOnly 150 calories; suitable for everyone.';
      final recipe = parsePdfRecipeText(source).single.recipe!;
      expect(recipe.description, contains('Only 150 calories'));
      expect(recipe.asRecipe().hasNutrition, isFalse);
      expect(recipe.asRecipe().contains, isEmpty);
      expect(recipe.asRecipe().variant.diet, 'classic');
      expect(recipe.sourceDiet, isNull);
    },
  );
}
