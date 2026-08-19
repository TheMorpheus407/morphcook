import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/models.dart';
import 'package:morphcook/logic/matching.dart';
import 'package:morphcook/logic/profile.dart';

/// Loads the real bundled corpus so the matching algorithm is tested
/// against production data shapes.
Future<Corpus> loadCorpus() => Corpus.load();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;

  setUpAll(() async {
    corpus = await loadCorpus();
  });

  Recipe recipeById(String id) => corpus.recipes[id]!;

  group('matching — avoid flags', () {
    test('vegan avoid-flag hides every animal-derived variant', () {
      final p = const Profile(avoidFlags: {'vegan'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      for (final r in corpus.recipes.values) {
        final res = matchesRecipe(r, p, corpus.ontology, avoidance: av);
        final hasAnimal = r.contains.any((f) => av.flags.contains(f));
        expect(res.visible, !hasAnimal,
            reason: '${r.id} contains ${r.contains}');
      }
    });

    test('dairy avoidance hides classic alfredo but not the vegan one', () {
      final p = const Profile(avoidFlags: {'dairy'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      expect(
          matchesRecipe(recipeById('alfredo-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isFalse);
      expect(
          matchesRecipe(recipeById('alfredo-vegan'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isTrue);
    });

    test('compound flag expansion includes base flags', () {
      final p = const Profile(avoidFlags: {'vegan'});
      final expanded = corpus.ontology.expandAvoidFlags(p.avoidFlags);
      expect(expanded, containsAll(['pork', 'beef', 'dairy', 'egg', 'honey']));
    });

    test('halal avoid-flag hides pork & alcohol but not other meat', () {
      final p = const Profile(avoidFlags: {'halal'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      expect(
          matchesRecipe(recipeById('doener-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isFalse); // pork
      expect(
          matchesRecipe(recipeById('bolognese-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isFalse); // alcohol (wine)
      expect(
          matchesRecipe(recipeById('doener-halal'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isTrue);
    });
  });

  group('matching — specific ingredient avoidance', () {
    test('avoiding cilantro hides recipes using it', () {
      final p = const Profile(avoidIngredients: {'cilantro'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      final falafel =
          matchesRecipe(recipeById('falafel-classic'), p, corpus.ontology,
              avoidance: av);
      expect(falafel.visible, isFalse);
      expect(falafel.violations, contains('avoid_ingredient:cilantro'));
    });

    test('avoiding a parent node excludes all descendants', () {
      final p = const Profile(avoidIngredients: {'tree-nuts'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      // alfredo-vegan contains cashews, a tree-nut descendant
      expect(
          matchesRecipe(recipeById('alfredo-vegan'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isFalse);
    });

    test('avoiding a leaf does not exclude the parent-only recipe', () {
      final p = const Profile(avoidIngredients: {'walnuts'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      // hummus has no walnuts
      expect(
          matchesRecipe(recipeById('hummus-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isTrue);
    });
  });

  group('matching — required attributes', () {
    test('required halal expands to bans and filters recipes', () {
      final p = const Profile(requiredAttributes: {'halal'});
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      expect(
          matchesRecipe(recipeById('currywurst-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isFalse);
      expect(
          matchesRecipe(recipeById('currywurst-halal'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isTrue);
    });
  });

  group('matching — time & calories', () {
    test('time budget hides longer recipes', () {
      final p = const Profile(maxTimeMinutes: 30);
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      expect(
          matchesRecipe(recipeById('lasagna-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isFalse);
      expect(
          matchesRecipe(recipeById('currywurst-classic'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isTrue);
    });

    test('calorie target filters with ±150 tolerance', () {
      final p = const Profile(calorieTarget: 600);
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      final inRange = recipeById('doener-vegan'); // 590 → |10| ≤ 150
      final outOfRange = recipeById('doener-halal'); // 830 → |230| > 150
      expect(
          matchesRecipe(inRange, p, corpus.ontology, avoidance: av).visible,
          isTrue);
      expect(
          matchesRecipe(outOfRange, p, corpus.ontology, avoidance: av)
              .violations,
          contains('calories'));
    });

    test('calorie override switch disables the filter', () {
      final p = const Profile(calorieTarget: 600);
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      final res = matchesRecipe(
        recipeById('doener-halal'),
        p,
        corpus.ontology,
        avoidance: av,
        opts: const MatchOptions(calorieOverride: true),
      );
      expect(res.visible, isTrue);
    });

    test('exact tolerance boundary passes', () {
      final p = const Profile(calorieTarget: 450);
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      // pancakes-vegan = 450 → |0| ≤ 150
      expect(
          matchesRecipe(recipeById('pancakes-vegan'), p, corpus.ontology,
                  avoidance: av)
              .visible,
          isTrue);
    });
  });

  group('matching — combined class + specific', () {
    test('both avoidances combine', () {
      final p = const Profile(
        avoidFlags: {'dairy'},
        avoidIngredients: {'garlic'},
      );
      final av = Avoidance.of(p, corpus.ontology, corpus.ingredients);
      // vegan alfredo has no dairy but has garlic
      final res = matchesRecipe(
          recipeById('alfredo-vegan'), p, corpus.ontology,
          avoidance: av);
      expect(res.visible, isFalse);
      expect(res.violations, contains('avoid_ingredient:garlic'));
    });
  });
}
