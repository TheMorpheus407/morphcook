import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/logic/profile.dart';
import 'package:morphcook/logic/ranking.dart';
import 'package:morphcook/logic/variants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final corpusFuture = Corpus.load();

  test('variant state marks incompatible diets unreachable', () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['doener']!;
    final variants = corpus.variantsOf('doener');
    final veganProfile = const Profile(avoidFlags: {'vegan'});
    final selected =
        defaultVariantFor(dish, variants, veganProfile, corpus.ontology,
            RankContext(now: DateTime(2026, 8, 19, 18)));
    expect(selected, isNotNull);
    expect(selected!.diet, 'vegan');

    final state = variantStateFor(
        dish, variants, selected, veganProfile, corpus.ontology);
    expect(state.dietOptions['vegan']!.reachable, isTrue);
    expect(state.dietOptions['classic']!.reachable, isFalse); // pork
  });

  test('switching diet keeps effort intent when possible', () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['doener']!;
    final variants = corpus.variantsOf('doener');
    final p = const Profile();
    final next = switchVariant(
      dish: dish,
      variants: variants,
      fromDiet: 'classic',
      toDiet: 'vegan',
      p: p,
      onto: corpus.ontology,
      ctx: RankContext(now: DateTime(2026, 8, 19, 12)),
    );
    expect(next!.diet, 'vegan');
  });

  test('switching effort falls back within the diet when combo is missing',
      () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['doener']!;
    final variants = corpus.variantsOf('doener');
    final p = const Profile();
    // classic doener is medium; easy doesn't exist → diet is preserved
    final easy = switchVariant(
      dish: dish,
      variants: variants,
      fromDiet: 'classic',
      toEffort: 'easy',
      p: p,
      onto: corpus.ontology,
      ctx: RankContext(now: DateTime(2026, 8, 19, 12)),
    );
    expect(easy!.diet, 'classic');
    // keto bowl is the only easy variant — switching intent may land there
    expect(easy.effort, anyOf('easy', 'medium'));
  });

  test('exact combo resolves when it exists', () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['doener']!;
    final variants = corpus.variantsOf('doener');
    // keto bowl is the keto variant AND easy — ask for keto × easy exactly
    final p = const Profile(preferredEffort: 'easy');
    final keto = switchVariant(
      dish: dish,
      variants: variants,
      fromDiet: 'classic',
      toDiet: 'keto',
      toEffort: 'easy',
      p: p,
      onto: corpus.ontology,
      ctx: RankContext(now: DateTime(2026, 8, 19, 12)),
    );
    expect(keto!.id, 'doener-keto-bowl');
    expect(keto.effort, 'easy');
  });

  test('switching to a diet with no such combo keeps the diet variant',
      () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['alfredo']!;
    final variants = corpus.variantsOf('alfredo');
    final p = const Profile();
    // vegan alfredo exists; hard effort doesn't → returns the vegan variant
    final next = switchVariant(
      dish: dish,
      variants: variants,
      fromDiet: 'classic',
      toDiet: 'vegan',
      toEffort: 'hard',
      p: p,
      onto: corpus.ontology,
      ctx: RankContext(now: DateTime(2026, 8, 19, 12)),
    );
    expect(next!.diet, 'vegan');
    expect(next.effort, 'easy'); // vegan alfredo is easy
  });

  test('default variant respects visible > scored preference', () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['doener']!;
    final variants = corpus.variantsOf('doener');
    // pescatarian → only vegan variants remain visible (no fish/shellfish/meat)
    final p = const Profile(avoidFlags: {'pescatarian'});
    final sel =
        defaultVariantFor(dish, variants, p, corpus.ontology,
            RankContext(now: DateTime(2026, 8, 19, 18)));
    expect(sel!.diet, 'vegan');
  });

  test('calorie bucket options exist for the selected diet', () async {
    final corpus = await corpusFuture;
    final dish = corpus.dishes['doener']!;
    final variants = corpus.variantsOf('doener');
    final p = const Profile();
    final selected = variants.first;
    final state = variantStateFor(dish, variants, selected, p, corpus.ontology);
    // doener-classic is 820 kcal → >800 bucket has a recipe
    expect(state.calorieOptions['>800']!.recipe, isNotNull);
    expect(state.calorieOptions['>800']!.reachable, isTrue);
  });
}
