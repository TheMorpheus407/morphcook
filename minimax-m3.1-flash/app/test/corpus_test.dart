import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/data/corpus.dart';
import 'package:morphcook/src/data/repositories.dart';
import 'package:morphcook/src/domain/matching.dart';
import 'package:morphcook/src/models/profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;

  setUpAll(() async {
    corpus = await Corpus.load();
  });

  group('the corpus loads', () {
    test('the manifest is read', () {
      expect(corpus.manifest.partitions, isNotEmpty);
      expect(corpus.manifest.corpusVersion, isNotEmpty);
    });

    test('the core partition is loaded at launch', () {
      expect(corpus.loadedPartitions, contains('core'));
      expect(corpus.recipeCount, greaterThan(10));
    });

    test('the ontology is complete', () {
      expect(corpus.ontology.contains, isNotEmpty);
      expect(corpus.ontology.avoid, isNotEmpty);
      expect(corpus.ontology.axes.keys, contains('effort'));
    });

    test('the ingredient tree is hierarchical', () {
      expect(corpus.ingredients.roots, isNotEmpty);
      expect(corpus.ingredients.descendantsOf('dairy'), contains('dairy.milk'));
    });

    test('every dish points at real recipes', () async {
      await corpus.loadAll();

      for (final dish in corpus.dishes.values) {
        expect(dish.variantIds, isNotEmpty, reason: 'dish ${dish.id}');
        for (final variantId in dish.variantIds) {
          expect(
            corpus.recipe(variantId),
            isNotNull,
            reason: '${dish.id} references missing $variantId',
          );
        }
      }
    });

    test('every recipe points at a real dish', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        expect(
          corpus.dish(recipe.dishId),
          isNotNull,
          reason: '${recipe.id} references missing dish ${recipe.dishId}',
        );
      }
    });

    test('every ingredient id exists in the dictionary', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        for (final ingredient in recipe.ingredients) {
          expect(
            corpus.ingredients.node(ingredient.ingredientId),
            isNotNull,
            reason: '${recipe.id} uses unknown ${ingredient.ingredientId}',
          );
        }
      }
    });

    test('every contains-flag exists in the ontology', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        for (final flag in recipe.contains) {
          expect(
            corpus.ontology.containsFlag(flag),
            isNotNull,
            reason: '${recipe.id} uses unknown flag $flag',
          );
        }
      }
    });

    test('every recipe has ingredients, steps and macros', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        expect(recipe.ingredients, isNotEmpty, reason: recipe.id);
        expect(recipe.steps, isNotEmpty, reason: recipe.id);
        expect(recipe.calories, greaterThan(0), reason: recipe.id);
        expect(recipe.timeMinutes, greaterThan(0), reason: recipe.id);
      }
    });

    test('every recipe is written in both languages', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        expect(recipe.title.resolve('en'), isNotEmpty, reason: recipe.id);
        expect(recipe.title.resolve('de'), isNotEmpty, reason: recipe.id);
        for (final step in recipe.steps) {
          expect(step.instruction.resolve('en'), isNotEmpty, reason: recipe.id);
          expect(step.instruction.resolve('de'), isNotEmpty, reason: recipe.id);
        }
      }
    });
  });

  group('the ontology is self-consistent', () {
    test('every avoid-flag expands to known contains-flags', () {
      for (final flag in corpus.ontology.avoid.values) {
        for (final target in flag.expands) {
          expect(
            corpus.ontology.containsFlag(target),
            isNotNull,
            reason: '${flag.id} expands to unknown $target',
          );
        }
      }
    });

    test('every certification has a blocker list', () {
      for (final certification in corpus.ontology.compoundCertifications) {
        expect(
          corpus.ontology.expandAvoid(<String>{certification}),
          isNotEmpty,
          reason: certification,
        );
      }
    });

    test('every technique a recipe uses exists on the technique axis', () async {
      await corpus.loadAll();

      final axis = corpus.ontology.axes['technique'];
      expect(axis, isNotNull);

      for (final recipe in corpus.allRecipes) {
        for (final technique in recipe.techniques) {
          expect(
            axis!.values.map((value) => value.id),
            contains(technique),
            reason: '${recipe.id} uses the unknown technique "$technique"',
          );
        }
      }
    });
  });

  group('the recipes agree with their flags', () {
    test('a vegan recipe contains no animal flags', () async {
      await corpus.loadAll();

      const animal = <String>{
        'pork',
        'beef',
        'lamb',
        'poultry',
        'fish',
        'shellfish',
        'molluscs',
        'egg',
        'dairy',
        'honey',
      };

      for (final recipe in corpus.allRecipes) {
        if (!recipe.certifications.contains('vegan')) continue;
        expect(
          recipe.contains.intersection(animal),
          isEmpty,
          reason: '${recipe.id} claims vegan but contains animal flags',
        );
      }
    });

    test('a halal recipe contains no pork or alcohol', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        if (!recipe.certifications.contains('halal')) continue;
        expect(recipe.contains.contains('pork'), isFalse, reason: recipe.id);
        expect(recipe.contains.contains('alcohol'), isFalse, reason: recipe.id);
      }
    });

    test('a gluten-free recipe contains no gluten', () async {
      await corpus.loadAll();

      for (final recipe in corpus.allRecipes) {
        if (recipe.diet != 'gluten-free') continue;
        expect(
          recipe.contains.contains('gluten'),
          isFalse,
          reason: '${recipe.id} is gluten-free but contains gluten',
        );
      }
    });
  });

  group('the matcher works against the real corpus', () {
    test('a vegan profile hides every recipe with animal flags', () async {
      await corpus.loadAll();
      final matcher = RecipeMatcher(
        ontology: corpus.ontology,
        ingredients: corpus.ingredients,
      );
      final profile = buildVeganProfile();

      for (final recipe in corpus.allRecipes) {
        final result = matcher.evaluate(recipe, profile);
        if (result.visible) continue;
        expect(
          result.reasons.contains(VisibilityReason.containsFlag),
          isTrue,
          reason: '${recipe.id} is hidden for the wrong reason',
        );
      }
    });

    test('a vegan profile still sees the vegan recipes', () async {
      await corpus.loadAll();
      final matcher = RecipeMatcher(
        ontology: corpus.ontology,
        ingredients: corpus.ingredients,
      );
      final profile = buildVeganProfile();

      final visible = corpus.allRecipes
          .where((recipe) => matcher.isVisible(recipe, profile))
          .toList();

      expect(visible, isNotEmpty);
      expect(
        visible.any((recipe) => recipe.diet == 'vegan'),
        isTrue,
      );
    });
  });

  group('the repositories load', () {
    test('the FAQ has entries in every category', () async {
      final faqs = await FaqRepository.load();

      expect(faqs.entries, isNotEmpty);
      for (final entry in faqs.entries) {
        expect(entry.question.resolve('en'), isNotEmpty);
        expect(entry.question.resolve('de'), isNotEmpty);
        expect(entry.answer.resolve('en'), isNotEmpty);
        expect(entry.answer.resolve('de'), isNotEmpty);
      }
    });

    test('the FAQ is searchable', () async {
      final faqs = await FaqRepository.load();

      expect(faqs.search('vegan'), isNotEmpty);
      expect(faqs.search('something nobody asked about'), isEmpty);
    });

    test('the ingredient guide has bilingual entries', () async {
      final guide = await IngredientGuideRepository.load();

      expect(guide.entries, isNotEmpty);
      for (final entry in guide.entries.values) {
        expect(entry.description.resolve('en'), isNotEmpty);
        expect(entry.description.resolve('de'), isNotEmpty);
      }
    });
  });
}

/// A profile that avoids every animal product.
Profile buildVeganProfile() {
  return Profile(
    name: 'Vera',
    lang: 'en',
    avoidFlags: <String>{'vegan'},
    avoidIngredients: const <String>{},
    requiredAttributes: const <String>{},
    maxTimeMinutes: 180,
    calorieTarget: 900,
    calorieTolerance: 800,
    preferredEffort: 'easy',
    showVariantTags: true,
    reduceMotion: null,
    visualAlertEnabled: true,
    quickNextTapEnabled: false,
    onboardingComplete: true,
    dishesOutsideCalorieTarget: const <String>{},
  );
}
