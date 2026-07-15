import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/recipe.dart';

/// AssetBundle that reads straight from the package directory, so tests
/// exercise the real bundled corpus without a device.
class FileAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      File(key).readAsString();
}

Future<CorpusRepository> loadRealCorpus({bool all = true}) async {
  final corpus = CorpusRepository(bundle: FileAssetBundle());
  await corpus.initialize();
  if (all) await corpus.ensureAllLoaded();
  return corpus;
}

Map<String, dynamic> readJsonFile(String path) =>
    json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

Uint8List testPngBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

/// Minimal recipe factory for pure-logic tests.
Recipe makeRecipe({
  String id = 'test-recipe',
  String dishId = 'test-dish',
  String diet = 'classic',
  String effort = 'easy',
  String calorie = 'le600',
  Set<String> contains = const {},
  Set<String> attributes = const {},
  List<String> meal = const ['lunch', 'dinner'],
  int timeMinutes = 30,
  int calories = 500,
  int servings = 2,
  List<String> ingredientIds = const ['garlic'],
}) {
  return Recipe(
    id: id,
    dishId: dishId,
    title: LocalizedText({'en': id, 'de': id}),
    caption: LocalizedText.empty,
    intro: LocalizedText.empty,
    variant: VariantCoords(diet: diet, effort: effort, calorie: calorie),
    contains: contains,
    attributes: {...attributes, effort, calorie},
    meal: meal,
    timeMinutes: timeMinutes,
    servings: servings,
    caloriesPerServing: calories,
    macros: Macros(calories: calories, proteinG: 20, carbsG: 50, fatG: 20),
    ingredients: [
      for (final ing in ingredientIds)
        RecipeIngredient(ingredientId: ing, qty: 1, unit: 'piece'),
    ],
    steps: const [
      RecipeStep(text: LocalizedText({'en': 'cook', 'de': 'kochen'})),
    ],
    tags: LocalizedList.empty,
  );
}
