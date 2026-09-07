import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/import/website_recipe_import.dart';
import 'package:morphcook/models/personal_recipe.dart';

import 'helpers.dart';

final _source = Uri.parse('https://www.chefkoch.de/rezepte/123/suppe.html');

Map<String, dynamic> _recipe([Map<String, dynamic> overrides = const {}]) => {
  '@context': 'https://schema.org',
  '@type': 'Recipe',
  'name': 'Kartoffelsuppe',
  'description': 'Warm &amp; lecker.',
  'recipeIngredient': ['750 g Kartoffeln', '1,5 EL Öl', 'Salz nach Geschmack'],
  'recipeInstructions': [
    {'@type': 'HowToStep', 'text': 'Kartoffeln schälen.'},
    {'@type': 'HowToStep', 'text': 'Kochen &amp; servieren.'},
  ],
  'prepTime': 'PT15M',
  'cookTime': 'PT30M',
  'recipeYield': '4 Portionen',
  'image': '/images/suppe.jpg',
  ...overrides,
};

String _page(dynamic data) =>
    '<html><script type="application/ld+json">${jsonEncode(data)}</script></html>';

Matcher _fails(WebsiteRecipeImportFailure failure) => throwsA(
  isA<WebsiteRecipeImportException>().having(
    (e) => e.failure,
    'failure',
    failure,
  ),
);

Future<Uri> _serve(void Function(HttpRequest request) handle) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handle);
  addTearDown(() => server.close(force: true));
  return Uri.parse('http://127.0.0.1:${server.port}/recipe');
}

void main() {
  test(
    'large referenced text and accumulated metadata reject before expansion',
    () {
      for (final length in [600, 10000]) {
        final graph = [
          _recipe({
            'author': List.generate(20, (_) => {'@id': '#author'}),
          }),
          {'@id': '#author', '@type': 'Person', 'name': 'a' * length},
        ];
        expect(
          () => parseWebsiteRecipes(_page({'@graph': graph}), _source),
          _fails(WebsiteRecipeImportFailure.invalidRecipe),
        );
      }
      final graph = [
        _recipe({
          'recipeInstructions': List.generate(200, (_) => {'@id': '#step'}),
        }),
        {'@id': '#step', '@type': 'HowToStep', 'text': 'a' * 10000},
      ];
      expect(
        () => parseWebsiteRecipes(_page({'@graph': graph}), _source),
        _fails(WebsiteRecipeImportFailure.invalidRecipe),
      );
    },
  );

  test('reference expansion is bounded even for empty repeated branches', () {
    for (final field in ['recipeIngredient', 'recipeInstructions']) {
      for (final empty in [false, true]) {
        final graph = [
          _recipe({
            field: [
              'salt to taste',
              {'@id': '#layer0'},
            ],
          }),
          for (var i = 0; i < 14; i++)
            {
              '@id': '#layer$i',
              '@type': 'ItemList',
              'itemListElement': [
                {'@id': '#layer${i + 1}'},
                {'@id': '#layer${i + 1}'},
              ],
            },
          {
            '@id': '#layer14',
            '@type': 'ItemList',
            'itemListElement': empty ? [] : ['salt to taste'],
          },
        ];
        expect(
          () => parseWebsiteRecipes(_page({'@graph': graph}), _source),
          _fails(WebsiteRecipeImportFailure.invalidRecipe),
        );
      }
    }
  });

  test('ambiguous thousands separators and compound measures remain raw', () {
    const lines = [
      '1.000 g Mehl',
      '1,000 g flour',
      '1,500 ml water',
      '2 cups plus 2 tablespoons flour',
      '2 cups + 2 tablespoons flour',
      '2 EL und 1 TL Öl',
      '1 cup (200 g) sugar',
      '2 cups flour plus 2 tablespoons for dusting',
      '2 eggs or 1/2 cup applesauce',
      '1 cup sugar + 2 tbsp',
    ];
    final recipe = parseWebsiteRecipes(
      _page(_recipe({'recipeIngredient': lines})),
      _source,
    ).single.recipe;
    expect(recipe.ingredients.map((i) => i.name), lines);
    expect(recipe.ingredients.map((i) => i.hasQuantity), everyElement(isFalse));
  });

  test(
    'Chefkoch-style data preserves German quantities and unparsed lines',
    () {
      final imported = parseWebsiteRecipes(_page(_recipe()), _source).single;
      final recipe = imported.recipe;

      expect(recipe.title, 'Kartoffelsuppe');
      expect(recipe.description, 'Warm & lecker.');
      expect(recipe.timeMinutes, 45);
      expect(recipe.servings, 4);
      expect(recipe.ingredients[0].qty, 750);
      expect(recipe.ingredients[0].name, 'Kartoffeln');
      expect(recipe.ingredients[1].qty, 1.5);
      expect(recipe.ingredients[1].unit, 'tbsp');
      expect(recipe.ingredients[2].name, 'Salz nach Geschmack');
      expect(recipe.ingredients[2].hasQuantity, isFalse);
      expect(recipe.asRecipe().ingredients[2].hasQuantity, isFalse);
      expect(recipe.steps.last.text, 'Kochen & servieren.');
      expect(recipe.sourceUrl, _source.toString());
      expect(
        imported.imageUrl.toString(),
        'https://www.chefkoch.de/images/suppe.jpg',
      );
      expect(imported.usedDefaultTime, isFalse);
      expect(imported.usedDefaultServings, isFalse);
    },
  );

  test('Allrecipes-style root arrays and type arrays import fractions', () {
    final recipe = parseWebsiteRecipes(
      _page([
        {'@type': 'BreadcrumbList'},
        _recipe({
          '@type': ['Recipe', 'NewsArticle'],
          'name': 'Apple cake',
          'recipeIngredient': [
            '1 1/2 cups flour',
            '½ teaspoon salt',
            '2 eggs',
            '1–2 apples',
            '2 large eggs',
          ],
          'recipeYield': ['8', '1 cake'],
          'totalTime': 'PT1H20M30S',
          'image': [
            {
              '@type': 'ImageObject',
              'url': 'https://images.allrecipes.com/cake.jpg',
            },
          ],
        }),
      ]),
      Uri.parse('https://www.allrecipes.com/recipe/cake/'),
    ).single.recipe;

    expect(recipe.title, 'Apple cake');
    expect(recipe.timeMinutes, 81);
    expect(recipe.servings, 8);
    expect(recipe.ingredients[0].qty, 1.5);
    expect(recipe.ingredients[0].unit, 'cup');
    expect(recipe.ingredients[1].qty, 0.5);
    expect(recipe.ingredients[2].qty, 2);
    expect(recipe.ingredients[2].name, 'eggs');
    expect(recipe.ingredients[3].name, '1–2 apples');
    expect(recipe.ingredients[3].hasQuantity, isFalse);
    expect(recipe.ingredients[4].name, '2 large eggs');
    expect(recipe.ingredients[4].hasQuantity, isFalse);
  });

  test(
    'graphs, references, nested sections and HTML preserve instruction order',
    () {
      final imported = parseWebsiteRecipes(
        _page({
          '@graph': [
            {'@id': '#author', '@type': 'Person', 'name': 'Ada &amp; Ben'},
            {
              '@id': '#photo',
              '@type': 'ImageObject',
              'contentUrl': '../photo.png',
            },
            _recipe({
              '@type': 'https://schema.org/Recipe',
              'author': {'@id': '#author'},
              'image': {'@id': '#photo'},
              'recipeInstructions': [
                {
                  '@type': 'HowToSection',
                  'name': 'Prepare',
                  'itemListElement': [
                    {'@type': 'HowToStep', 'text': '<p>Wash &amp; chop.</p>'},
                    {
                      '@type': 'HowToSection',
                      'name': 'Sauce',
                      'itemListElement': [
                        {'@type': 'HowToStep', 'text': 'Stir.'},
                      ],
                    },
                  ],
                },
                {'@type': 'HowToStep', 'text': 'Serve.'},
              ],
            }),
          ],
        }),
        _source,
      ).single;

      expect(imported.recipe.sourceAuthor, 'Ada & Ben');
      expect(
        imported.imageUrl.toString(),
        'https://www.chefkoch.de/rezepte/photo.png',
      );
      expect(imported.recipe.steps.map((s) => s.text), [
        'Prepare: Wash & chop.',
        'Sauce: Stir.',
        'Serve.',
      ]);
    },
  );

  test('multiline strings and structured ingredients remain complete', () {
    final recipe = parseWebsiteRecipes(
      _page(
        _recipe({
          'recipeIngredient': {
            '@type': 'ItemList',
            'itemListElement': [
              {'@type': 'ListItem', 'item': '200g flour'},
              {
                '@type': 'PropertyValue',
                'name': 'water',
                'value': 100,
                'unitText': 'ml',
              },
              '1½ tbsp oil',
            ],
          },
          'recipeInstructions': '<p>Mix.</p><p>Rest.<br>Bake.</p>',
        }),
      ),
      _source,
    ).single.recipe;

    expect(recipe.ingredients.map((i) => i.name), ['flour', 'water', 'oil']);
    expect(recipe.ingredients.map((i) => i.qty), [200, 100, 1.5]);
    expect(recipe.steps.map((s) => s.text), ['Mix.', 'Rest.', 'Bake.']);
  });

  test(
    'unverified website claims survive edits and JSON without classification',
    () {
      final recipe = parseWebsiteRecipes(
        _page(
          _recipe({
            'name': 'Vegan gluten-free soup',
            'author': [
              {'name': 'Someone'},
              {'name': 'Someone else'},
            ],
            'suitableForDiet': [
              'https://schema.org/VeganDiet',
              'https://schema.org/GlutenFreeDiet',
            ],
          }),
        ),
        _source,
      ).single.recipe;
      final restored = PersonalRecipe.fromJson(
        recipe.copyWith(title: 'My soup').toJson(),
      );

      expect(restored.sourceAuthor, 'Someone, Someone else');
      expect(
        restored.sourceDiet,
        'https://schema.org/VeganDiet, https://schema.org/GlutenFreeDiet',
      );
      expect(restored.sourceUrl, _source.toString());
      expect(restored.ingredients.last.hasQuantity, isFalse);
      expect(restored.asRecipe().variant.diet, 'classic');
      expect(restored.asRecipe().contains, isEmpty);
      expect(restored.asRecipe().attributes, isNot(contains('vegan')));
      expect(restored.asRecipe().hasNutrition, isFalse);
      expect(
        estimatedPersonalRecipeBackupBytes([restored]),
        greaterThan(utf8.encode(jsonEncode([restored.toJson()])).length),
      );
    },
  );

  test(
    'finds multiple recipes, ignores incomplete stubs and duplicate schema',
    () {
      final first = _recipe();
      final recipes = parseWebsiteRecipes(
        '<script type="application/ld+json">broken</script>${_page({
          '@graph': [
            {'@type': 'Recipe', 'name': 'Link-only suggestion'},
            {'@type': 'WebPage', 'mainEntity': first},
            _recipe({'name': 'Second soup'}),
            first,
          ],
        })}',
        _source,
      );
      expect(recipes.map((r) => r.recipe.title), [
        'Kartoffelsuppe',
        'Second soup',
      ]);
    },
  );

  test('missing or ambiguous time and yield are marked for review', () {
    for (final yieldValue in ['1 cake', '4-6 servings', null]) {
      final imported = parseWebsiteRecipes(
        _page(
          _recipe({
            'totalTime': 'not a duration',
            'cookTime': null,
            'prepTime': null,
            'recipeYield': yieldValue,
          }),
        ),
        _source,
      ).single;
      expect(imported.usedDefaultTime, isTrue);
      expect(imported.usedDefaultServings, isTrue);
      expect(imported.recipe.timeMinutes, 30);
      expect(imported.recipe.servings, 2);
    }
    final structured = parseWebsiteRecipes(
      _page(
        _recipe({
          'recipeYield': {'@type': 'QuantitativeValue', 'value': 6},
          'totalTime': 'P1D',
        }),
      ),
      _source,
    ).single;
    expect(structured.recipe.servings, 6);
    expect(structured.recipe.timeMinutes, 1440);
  });

  test(
    'invalid schemes, credentials and unusable recipe data fail explicitly',
    () {
      for (final source in [
        'file:///etc/passwd',
        'javascript:alert(1)',
        'https://user:secret@example.org/r',
        '/recipe',
      ]) {
        expect(
          () => parseWebsiteRecipes(_page(_recipe()), Uri.parse(source)),
          _fails(WebsiteRecipeImportFailure.invalidUrl),
        );
      }
      expect(
        () => parseWebsiteRecipes('<p>No structured recipe</p>', _source),
        _fails(WebsiteRecipeImportFailure.noRecipe),
      );
      expect(
        () => parseWebsiteRecipes(
          _page(_recipe({'recipeIngredient': []})),
          _source,
        ),
        _fails(WebsiteRecipeImportFailure.invalidRecipe),
      );
      expect(
        () => parseWebsiteRecipes(
          _page(_recipe({'recipeInstructions': []})),
          _source,
        ),
        _fails(WebsiteRecipeImportFailure.invalidRecipe),
      );
      expect(
        () => parseWebsiteRecipes(
          _page(
            _recipe({
              'recipeIngredient': ['x' * 201],
            }),
          ),
          _source,
        ),
        _fails(WebsiteRecipeImportFailure.invalidRecipe),
      );
      expect(
        () =>
            parseWebsiteRecipes('x' * (maxWebsiteRecipePageBytes + 1), _source),
        _fails(WebsiteRecipeImportFailure.tooLarge),
      );
    },
  );

  test('unsafe image URL candidates are ignored without losing the recipe', () {
    for (final image in [
      'file:///photo.png',
      'data:image/png;base64,abc',
      'https://user:pass@example.org/photo',
    ]) {
      expect(
        parseWebsiteRecipes(
          _page(_recipe({'image': image})),
          _source,
        ).single.imageUrl,
        isNull,
      );
    }
  });

  test('deep JSON and overflowing durations cannot crash import', () {
    final nested = '${'[' * 130}0${']' * 130}';
    expect(
      () => parseWebsiteRecipes(
        '<script type="application/ld+json">$nested</script>',
        _source,
      ),
      _fails(WebsiteRecipeImportFailure.tooLarge),
    );
    final imported = parseWebsiteRecipes(
      _page(
        _recipe({
          'totalTime': 'PT${'9' * 400}H',
          'prepTime': null,
          'cookTime': null,
          'recipeYield': {
            '@type': 'QuantitativeValue',
            'value': 1,
            'unitText': 'cake',
          },
        }),
      ),
      _source,
    ).single;
    expect(imported.usedDefaultTime, isTrue);
    expect(imported.usedDefaultServings, isTrue);
  });

  test(
    'model validates source URLs and old JSON defaults to quantified ingredients',
    () {
      final recipe = parseWebsiteRecipes(
        _page(_recipe()),
        _source,
      ).single.recipe;
      expect(
        () => recipe.copyWith(sourceUrl: 'javascript:alert(1)'),
        throwsFormatException,
      );
      expect(
        PersonalRecipeIngredient.fromJson({
          'name': 'flour',
          'qty': 1,
          'unit': 'g',
        }).hasQuantity,
        isTrue,
      );
    },
  );

  test(
    'fetch follows relative redirects but never fetches images implicitly',
    () async {
      final paths = <String>[];
      final source = await _serve((request) {
        paths.add(request.uri.path);
        if (request.uri.path == '/recipe') {
          request.response.statusCode = 302;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            '/recipes/final',
          );
        } else {
          request.response.headers.contentType = ContentType.html;
          request.response.write(_page(_recipe({'image': 'photo.png'})));
        }
        request.response.close();
      });
      final imported = (await const WebsiteRecipeImporter().fetch(
        source,
      )).single;
      expect(paths, ['/recipe', '/recipes/final']);
      expect(
        imported.recipe.sourceUrl,
        source.resolve('/recipes/final').toString(),
      );
      expect(imported.imageUrl, source.resolve('/recipes/photo.png'));
    },
  );

  test('network byte limits apply to declared and streamed bodies', () async {
    final source = await _serve((request) {
      request.response.headers.contentType = ContentType.html;
      if (request.uri.query == 'length') request.response.contentLength = 1000;
      request.response.write('x' * 1000);
      request.response.close();
    });
    const importer = WebsiteRecipeImporter(maxPageBytes: 100);
    await expectLater(
      importer.fetch(source),
      _fails(WebsiteRecipeImportFailure.tooLarge),
    );
    await expectLater(
      importer.fetch(source.replace(query: 'length')),
      _fails(WebsiteRecipeImportFailure.tooLarge),
    );
  });

  test('redirect limits and unsafe redirect destinations fail', () async {
    final source = await _serve((request) {
      request.response.statusCode = 302;
      request.response.headers.set(
        HttpHeaders.locationHeader,
        request.uri.query == 'unsafe' ? 'file:///tmp/recipe' : '/recipe',
      );
      request.response.close();
    });
    await expectLater(
      const WebsiteRecipeImporter(maxRedirects: 1).fetch(source),
      _fails(WebsiteRecipeImportFailure.network),
    );
    await expectLater(
      const WebsiteRecipeImporter().fetch(source.replace(query: 'unsafe')),
      _fails(WebsiteRecipeImportFailure.invalidUrl),
    );
  });

  test('whole request timeout covers a server that never responds', () async {
    final source = await _serve((request) {});
    await expectLater(
      const WebsiteRecipeImporter(
        timeout: Duration(milliseconds: 100),
      ).fetch(source),
      _fails(WebsiteRecipeImportFailure.timeout),
    );
  });

  test(
    'unsupported content and HTTP errors produce actionable failures',
    () async {
      final source = await _serve((request) {
        if (request.uri.query == 'error') request.response.statusCode = 403;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{}');
        request.response.close();
      });
      await expectLater(
        const WebsiteRecipeImporter().fetch(source),
        _fails(WebsiteRecipeImportFailure.unsupportedPage),
      );
      await expectLater(
        const WebsiteRecipeImporter().fetch(source.replace(query: 'error')),
        _fails(WebsiteRecipeImportFailure.network),
      );
    },
  );

  test('explicit image download validates image bytes and size', () async {
    final source = await _serve((request) {
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(
        request.uri.query == 'invalid'
            ? utf8.encode('not an image')
            : testPngBytes(),
      );
      request.response.close();
    });
    expect(
      await const WebsiteRecipeImporter().fetchImage(source),
      orderedEquals(testPngBytes()),
    );
    await expectLater(
      const WebsiteRecipeImporter().fetchImage(
        source.replace(query: 'invalid'),
      ),
      _fails(WebsiteRecipeImportFailure.unsupportedImage),
    );
    await expectLater(
      const WebsiteRecipeImporter(maxImageBytes: 10).fetchImage(source),
      _fails(WebsiteRecipeImportFailure.tooLarge),
    );
  });
}
