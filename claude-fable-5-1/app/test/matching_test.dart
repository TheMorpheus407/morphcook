import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/matching.dart';

import 'helpers.dart';

void main() {
  late CorpusRepository repo;
  setUpAll(() async => repo = await loadRepo(all: true));

  group('compound expansion', () {
    test('vegan expands to every animal flag', () {
      final e = repo.ontology.expandAvoidFlags({'vegan'});
      expect(e, containsAll(['pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'egg', 'dairy', 'honey', 'lactose']));
      expect(e, isNot(contains('gluten')));
    });

    test('halal expands to pork, alcohol and non-halal gelatin', () {
      expect(repo.ontology.expandAvoidFlags({'halal'}), {'pork', 'alcohol', 'gelatin-non-halal'});
    });

    test('parent flag includes its children', () {
      expect(repo.ontology.expandAvoidFlags({'tree-nuts'}), containsAll(['tree-nuts', 'almonds', 'walnuts', 'cashews']));
    });

    test('unknown ids pass through literally', () {
      expect(repo.ontology.expandAvoidFlags({'future-flag'}), {'future-flag'});
    });
  });

  group('ingredient tree', () {
    test('avoiding a parent covers all descendants', () {
      final ids = repo.ingredients.expandAvoidance({'dairy'});
      expect(ids, containsAll(['dairy', 'cow-milk', 'whole-milk', 'parmesan', 'feta', 'greek-yogurt']));
      expect(ids, isNot(contains('garlic')));
    });

    test('effective flags inherit from ancestors', () {
      expect(repo.ingredients.effectiveFlags('whole-milk'), containsAll(['dairy', 'lactose']));
      expect(repo.ingredients.effectiveFlags('parmesan'), {'dairy'});
      expect(repo.ingredients.effectiveFlags('almonds'), {'tree-nuts', 'almonds'});
    });

    test('typeahead finds leaves and parents in both languages', () {
      final en = repo.ingredients.search('cilan', 'en');
      expect(en.first.id, 'cilantro');
      final de = repo.ingredients.search('kori', 'de');
      expect(de.map((n) => n.id), contains('cilantro'));
      expect(repo.ingredients.search('nuts', 'en').map((n) => n.id), contains('nuts'));
    });
  });

  group('visible()', () {
    test('classic döner hidden for vegan, vegan döner visible', () {
      final ctx = ctxFor(repo, const Profile(avoidFlags: {'vegan'}));
      expect(isVisible(recipeOf(repo, 'doener-classic-easy'), ctx), isFalse);
      expect(isVisible(recipeOf(repo, 'doener-vegan-easy'), ctx), isTrue);
    });

    test('specific avoidance excludes by ingredient id with propagation', () {
      final ctx = ctxFor(repo, const Profile(avoidIngredients: {'yogurt'}));
      // classic döner uses greek yogurt (child of yogurt)
      final m = evaluate(recipeOf(repo, 'doener-classic-easy'), ctx);
      expect(m.visible, isFalse);
      expect(m.reasons, [HiddenReason.avoidIngredient]);
      expect(m.conflictingIngredients, containsAll(['greek-yogurt']));
      expect(isVisible(recipeOf(repo, 'doener-vegan-easy'), ctx), isTrue);
    });

    test('class avoidance and specific avoidance combine', () {
      final ctx = ctxFor(repo, const Profile(avoidFlags: {'gluten'}, avoidIngredients: {'cilantro'}));
      expect(isVisible(recipeOf(repo, 'doener-vegan-easy'), ctx), isFalse); // flatbread → gluten
      expect(isVisible(recipeOf(repo, 'doener-gluten-free-easy'), ctx), isTrue);
    });

    test('required attributes must be a subset of recipe attributes', () {
      final ctx = ctxFor(repo, const Profile(requiredAttributes: {'halal'}));
      final classic = recipeOf(repo, 'doener-classic-easy');
      expect(classic.attributes, contains('halal')); // chicken, no alcohol → halal-compatible
      expect(isVisible(classic, ctx), isTrue);
      final carbonara = recipeOf(repo, 'carbonara-classic-easy'); // guanciale = pork
      expect(carbonara.attributes, isNot(contains('halal')));
      final m = evaluate(carbonara, ctx);
      expect(m.reasons, contains(HiddenReason.missingAttribute));
    });

    test('time budget is a hard filter', () {
      final ctx = ctxFor(repo, const Profile(maxTimeMinutes: 30));
      expect(isVisible(recipeOf(repo, 'doener-classic-easy'), ctx), isTrue); // 30 min
      final m = evaluate(recipeOf(repo, 'doener-classic-medium'), ctx); // 90 min
      expect(m.reasons, [HiddenReason.tooLong]);
    });

    test('calorie target with tolerance, and the override', () {
      final ctx = ctxFor(repo, const Profile(calorieTarget: 500, calorieTolerance: 100));
      final bowl = recipeOf(repo, 'doener-keto-easy'); // 540
      final classic = recipeOf(repo, 'doener-classic-easy'); // 720
      expect(isVisible(bowl, ctx), isTrue);
      final m = evaluate(classic, ctx);
      expect(m.visible, isFalse);
      expect(m.onlyCaloriesOff, isTrue);
      expect(isVisible(classic, ctx, ignoreCalories: true), isTrue);
    });

    test('empty profile sees everything', () {
      final ctx = ctxFor(repo, const Profile());
      for (final r in repo.loadedRecipes) {
        expect(isVisible(r, ctx), isTrue, reason: r.id);
      }
    });

    test('every dish keeps at least one version for a vegan', () {
      final ctx = ctxFor(repo, const Profile(avoidFlags: {'vegan'}));
      final vegans = repo.dishes.where((d) => repo.variantsIfLoaded(d.id).any((r) => isVisible(r, ctx))).length;
      // Not every dish has a vegan cell by plan, but most do.
      expect(vegans, greaterThanOrEqualTo(20));
    });
  });
}
