import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/ranking.dart';
import 'package:morphcook/domain/variant_lattice.dart';

import 'helpers.dart';

void main() {
  late CorpusRepository repo;
  late VariantLattice lattice;
  setUpAll(() async {
    repo = await loadRepo();
    final dish = repo.dish('doener')!;
    lattice = VariantLattice(dish: dish, recipes: repo.variantsIfLoaded('doener'), ontology: repo.ontology);
  });

  test('dimensions follow ontology order and only include present ones', () {
    expect(lattice.dimensions, ['diet', 'effort', 'calorie_level']);
    expect(lattice.valuesOf('diet'), ['classic', 'vegetarian', 'vegan', 'keto', 'halal', 'gluten-free']);
    expect(lattice.valuesOf('effort'), ['easy', 'medium']);
  });

  test('selection round-trips through recipeFor', () {
    final r = recipeOf(repo, 'doener-vegan-easy');
    expect(lattice.recipeFor(lattice.selectionOf(r))!.id, r.id);
  });

  test('default is the best visible variant for the profile', () {
    final vegan = ctxFor(repo, const Profile(avoidFlags: {'vegan'}));
    final now = RankContext(now: DateTime(2026, 9, 1, 12));
    expect(lattice.defaultRecipe(vegan, now)!.id, 'doener-vegan-easy');
    // Both medium halal-compatible versions qualify; the 45-minute lamb one is closer to the time budget.
    final halal = ctxFor(repo, const Profile(requiredAttributes: {'halal'}, preferredEffort: 'medium', calorieTarget: 780, calorieTolerance: 50));
    expect(lattice.defaultRecipe(halal, now)!.id, 'doener-halal-medium');
  });

  test('default falls back to closest when nothing is visible', () {
    final strict = ctxFor(repo, const Profile(calorieTarget: 200, calorieTolerance: 10));
    final now = RankContext(now: DateTime(2026, 9, 1, 12));
    expect(lattice.defaultRecipe(strict, now), isNotNull);
  });

  test('unreachable combos are disabled with an alternative, not hidden', () {
    final ctx = ctxFor(repo, const Profile());
    final current = lattice.selectionOf(recipeOf(repo, 'doener-classic-easy'));
    final diet = lattice.optionsFor('diet', current, ctx);
    final byValue = {for (final o in diet) o.value: o};
    expect(byValue['vegan']!.state, OptionState.available);
    expect(byValue['halal']!.state, OptionState.unreachable); // halal only exists as medium
    expect(byValue['halal']!.alternative!.id, 'doener-halal-medium');
    expect(byValue['vegetarian']!.state, OptionState.unreachable);
    final effort = lattice.optionsFor('effort', current, ctx);
    expect(effort.map((o) => o.value), ['easy', 'medium']);
    expect(effort.firstWhere((o) => o.value == 'medium').state, OptionState.available);
  });

  test('profile colours options: conflicts vs outside calories', () {
    final veganCtx = ctxFor(repo, const Profile(avoidFlags: {'vegan'}));
    final current = lattice.selectionOf(recipeOf(repo, 'doener-vegan-easy'));
    final diet = lattice.optionsFor('diet', current, veganCtx);
    final classic = diet.firstWhere((o) => o.value == 'classic');
    expect(classic.state, OptionState.conflicts);
    expect(classic.conflictingFlags, contains('poultry'));

    final calCtx = ctxFor(repo, const Profile(calorieTarget: 540, calorieTolerance: 50));
    final keto = lattice.optionsFor('diet', lattice.selectionOf(recipeOf(repo, 'doener-keto-easy')), calCtx);
    final classicChip = keto.firstWhere((o) => o.value == 'classic');
    expect(classicChip.state, OptionState.outsideCalories);
    final overridden = lattice.optionsFor('diet', lattice.selectionOf(recipeOf(repo, 'doener-keto-easy')), calCtx, calorieOverride: true);
    expect(overridden.firstWhere((o) => o.value == 'classic').state, OptionState.available);
  });

  test('switching diet re-resolves the derived calorie level', () {
    final ctx = ctxFor(repo, const Profile());
    final current = lattice.selectionOf(recipeOf(repo, 'doener-keto-easy')); // balanced
    final classic = lattice.optionsFor('diet', current, ctx).firstWhere((o) => o.value == 'classic');
    expect(classic.state, OptionState.available);
    expect(classic.recipe!.id, 'doener-classic-easy'); // hearty, but reachable
    final levels = lattice.optionsFor('calorie_level', current, ctx);
    expect(levels.firstWhere((o) => o.value == 'balanced').state, OptionState.available);
    expect(levels.firstWhere((o) => o.value == 'hearty').state, OptionState.unreachable);
  });

  test('unreachable note reads "no vegan × medium version yet"', () {
    final ctx = ctxFor(repo, const Profile());
    final current = lattice.selectionOf(recipeOf(repo, 'doener-classic-medium'));
    final vegan = lattice.optionsFor('diet', current, ctx).firstWhere((o) => o.value == 'vegan');
    expect(vegan.state, OptionState.unreachable);
    expect(lattice.unreachableNote(vegan, current, 'en'), 'no vegan × medium version yet');
  });
}
