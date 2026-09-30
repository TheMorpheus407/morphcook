import 'package:morphcook/core/i18n/localized_text.dart';
import 'package:morphcook/data/asset_source.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models/recipe.dart';

/// The bundled corpus read from `assets/`, loaded once per test file.
Future<Corpus> loadCorpus() => _corpus ??= Corpus.load(const FileAssetSource('assets'));
Future<Corpus>? _corpus;

/// A recipe reduced to what matching, ranking and search read.
class MetaFixture implements RecipeMeta {
  const MetaFixture({
    this.id = 'r',
    this.dishId = 'dish',
    this.contains = const <String>{},
    this.ingredientIds = const <String>{},
    this.attributes = const <String>{},
    this.timeMinutes = 30,
    this.caloriesPerServing = 500,
    this.effort = 'medium',
    this.meal = const <String>[],
  });

  @override
  final String id;
  @override
  final String dishId;
  @override
  final Set<String> contains;
  @override
  final Set<String> ingredientIds;
  @override
  final Set<String> attributes;
  @override
  final int timeMinutes;
  @override
  final int caloriesPerServing;
  @override
  final String effort;
  @override
  final List<String> meal;
}

/// A full [Recipe] with sensible defaults for tests that only care about a few fields.
Recipe recipeFixture({
  String id = 'test-recipe',
  String dishId = 'test-dish',
  String title = 'Test Recipe',
  String diet = 'classic',
  String effort = 'medium',
  int timeMinutes = 30,
  int servings = 2,
  int calories = 500,
  Set<String> contains = const <String>{},
  Set<String> attributes = const <String>{},
  List<String> meal = const <String>[],
  String timeBucket = '≤30',
  String calorieBucket = '≤600',
  Map<String, String> axes = const <String, String>{},
  List<RecipeIngredient> ingredients = const <RecipeIngredient>[],
  List<RecipeStep> steps = const <RecipeStep>[],
}) {
  return Recipe(
    id: id,
    dishId: dishId,
    title: LocalizedText(<String, String>{'en': title, 'de': title}),
    blurb: LocalizedText.empty,
    tip: LocalizedText.empty,
    diet: diet,
    effort: effort,
    timeMinutes: timeMinutes,
    servings: servings,
    caloriesPerServing: calories,
    macros: const Macros(protein: 20, carbs: 50, fat: 15),
    meal: meal,
    techniques: const <String>[],
    tags: const <String>[],
    axes: axes,
    contains: contains,
    attributes: attributes,
    ingredientIds: {for (final i in ingredients) i.id},
    timeBucket: timeBucket,
    calorieBucket: calorieBucket,
    ingredients: ingredients,
    steps: steps,
  );
}

RecipeIngredient line(String id, double? amount, String unit) => RecipeIngredient(id: id, amount: amount, unit: unit);

RecipeStep step(String text, {int? seconds}) =>
    RecipeStep(text: LocalizedText(<String, String>{'en': text, 'de': text}), timerSeconds: seconds);
