import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/matching.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';
import 'fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecipeRepository repository;
  setUpAll(() async {
    repository = RecipeRepository();
    await repository.initialize();
    await repository.loadAll();
  });
  bool matches(Recipe recipe, Profile profile, {bool ignoreCalories = false}) =>
      visible(
        recipe,
        profile,
        repository.ontology,
        repository.dictionary,
        ignoreCalories: ignoreCalories,
      );

  test('hard filter boundaries are inclusive', () {
    final profile = Profile(
      calorieTarget: 500,
      calorieTolerance: 100,
      maxTimeMinutes: 30,
    );
    expect(matches(makeRecipe(minutes: 30, calories: 400), profile), isTrue);
    expect(matches(makeRecipe(minutes: 30, calories: 600), profile), isTrue);
    expect(matches(makeRecipe(minutes: 31), profile), isFalse);
    expect(matches(makeRecipe(calories: 399), profile), isFalse);
    expect(matches(makeRecipe(calories: 601), profile), isFalse);
  });
  test('positive attributes are required, not merely ranked', () {
    final profile = Profile(requiredAttributes: {'halal', 'keto'});
    expect(matches(makeRecipe(attributes: {'halal'}), profile), isFalse);
    expect(matches(makeRecipe(attributes: {'halal', 'keto'}), profile), isTrue);
  });
  test(
    'calorie override preserves time, dietary and specific restrictions',
    () {
      expect(
        matches(makeRecipe(calories: 1000), Profile(), ignoreCalories: true),
        isTrue,
      );
      expect(
        matches(
          makeRecipe(calories: 1000, contains: {'dairy'}),
          Profile(avoidFlags: {'dairy'}),
          ignoreCalories: true,
        ),
        isFalse,
      );
      expect(
        matches(
          makeRecipe(calories: 1000, minutes: 60),
          Profile(),
          ignoreCalories: true,
        ),
        isFalse,
      );
      expect(
        matches(
          makeRecipe(calories: 1000),
          Profile(avoidIngredients: {'vegetables'}),
          ignoreCalories: true,
        ),
        isFalse,
      );
    },
  );
  test('ingredient parents propagate through arbitrarily deep hierarchy', () {
    expect(repository.dictionary.isWithin('whole-milk', 'dairy'), isTrue);
    expect(repository.dictionary.isWithin('parmesan', 'dairy'), isTrue);
    expect(repository.dictionary.isWithin('almonds', 'nuts'), isTrue);
    expect(repository.dictionary.isWithin('peanut-butter', 'nuts'), isTrue);
    expect(repository.dictionary.isWithin('carrot', 'dairy'), isFalse);
    expect(repository.dictionary.isWithin('unknown', 'unknown'), isTrue);
  });
  test(
    'ingredient-derived flags protect against incomplete recipe metadata',
    () {
      final recipe = makeRecipe(
        ingredients: [
          {'id': 'whole-milk', 'quantity': 100, 'unit': 'ml'},
        ],
      );
      expect(matches(recipe, Profile(avoidFlags: {'dairy'})), isFalse);
      expect(matches(recipe, Profile(diet: 'vegan')), isFalse);
      expect(matches(recipe, Profile(avoidIngredients: {'cow-milk'})), isFalse);
    },
  );
  test('compound nuts exclude peanuts and all tree nuts', () {
    final expanded = repository.ontology.expand({'nuts'});
    expect(expanded, containsAll(['nuts', 'tree-nuts', 'peanuts']));
  });
  test('pescatarian permits fish and rejects poultry', () {
    expect(
      matches(makeRecipe(contains: {'fish'}), Profile(diet: 'pescatarian')),
      isTrue,
    );
    expect(
      matches(makeRecipe(contains: {'poultry'}), Profile(diet: 'pescatarian')),
      isFalse,
    );
  });
  test('halal and kosher constraints preserve sourcing attributes', () {
    final profile = Profile();
    repository.ontology.applyDiet(profile, 'halal');
    expect(profile.requiredAttributes, contains('halal'));
    expect(
      matches(makeRecipe(contains: {'pork'}, attributes: {'halal'}), profile),
      isFalse,
    );
    repository.ontology.applyDiet(profile, 'kosher');
    expect(profile.requiredAttributes, isNot(contains('halal')));
    expect(
      matches(
        makeRecipe(contains: {'meat-dairy-combo'}, attributes: {'kosher'}),
        profile,
      ),
      isFalse,
    );
  });
  test(
    'diet changes retain explicit allergies and extra positive requirements',
    () {
      final profile = Profile(
        avoidFlags: {'soy'},
        requiredAttributes: {'bake', 'keto'},
      );
      repository.ontology.applyDiet(profile, 'vegan');
      expect(profile.avoidFlags, {'soy'});
      expect(profile.requiredAttributes, {'bake'});
    },
  );
  test('language fallback and profile extensions survive round trips', () {
    expect(translate({'en': 'Hello', 'de': 'Hallo'}, 'fr'), 'Hello');
    final profile = Profile.fromJson({
      ...Profile().toJson(),
      'b2b': {'company': 'Example'},
    });
    expect(profile.copy().toJson()['b2b'], {'company': 'Example'});
    expect(
      Profile.fromJson(Profile(reduceMotion: null).toJson()).reduceMotion,
      isNull,
    );
  });
  test('German and accented searches normalize deterministically', () {
    expect(normalizeSearch('DÖNER, Äpfel & Crème'), 'doner apfel creme');
    expect(
      repository.dictionary.search('äpf', 'de').map((i) => i.id),
      contains('apples'),
    );
  });
  test('ranking respects effort, then time, then calories', () {
    final profile = Profile(
      maxTimeMinutes: 45,
      preferredEffort: 'easy',
      calorieTarget: 600,
    );
    final now = DateTime(2026, 9, 30, 12);
    final easy = makeRecipe(effort: 'easy', minutes: 10, calories: 350);
    final medium = makeRecipe(effort: 'medium', minutes: 45, calories: 600);
    expect(
      rankRecipe(easy, profile, now, []),
      greaterThan(rankRecipe(medium, profile, now, [])),
    );
    expect(
      rankRecipe(makeRecipe(minutes: 30, calories: 400), profile, now, []),
      greaterThan(
        rankRecipe(makeRecipe(minutes: 25, calories: 600), profile, now, []),
      ),
    );
  });
  test('morning, evening, weekend and staleness bonuses are exact', () {
    final recipe = makeRecipe(tags: {'breakfast', 'dinner'}, effort: 'medium');
    final profile = Profile();
    final daytime = rankRecipe(recipe, profile, DateTime(2026, 9, 30, 12), []);
    expect(
      rankRecipe(recipe, profile, DateTime(2026, 9, 30, 5), []) - daytime,
      200,
    );
    expect(
      rankRecipe(recipe, profile, DateTime(2026, 9, 30, 11), []) - daytime,
      0,
    );
    expect(
      rankRecipe(recipe, profile, DateTime(2026, 9, 30, 17), []) - daytime,
      90,
    );
    expect(
      rankRecipe(recipe, profile, DateTime(2026, 9, 30, 21), []) - daytime,
      0,
    );
    expect(
      rankRecipe(recipe, profile, DateTime(2026, 10, 3, 12), []) - daytime,
      90,
    );
    final now = DateTime(2026, 9, 30, 12);
    expect(
      rankRecipe(recipe, profile, now, [
            CookingRecord(recipe.id, now.subtract(const Duration(days: 30)), 2),
          ]) -
          daytime,
      closeTo(50, 1e-9),
    );
    expect(
      rankRecipe(recipe, profile, now, [
            CookingRecord(recipe.id, now.subtract(const Duration(days: 40)), 2),
            CookingRecord(recipe.id, now.subtract(const Duration(days: 1)), 2),
          ]) -
          daytime,
      0,
    );
  });
  test('best variant is deterministic and rejects empty choices', () {
    final now = DateTime(2026, 9, 30, 12);
    expect(
      bestVariant(
        [],
        Profile(),
        repository.ontology,
        repository.dictionary,
        now,
        [],
      ),
      isNull,
    );
    expect(
      bestVariant(
        [makeRecipe(id: 'b'), makeRecipe(id: 'a')],
        Profile(),
        repository.ontology,
        repository.dictionary,
        now,
        [],
      )!.id,
      'a',
    );
  });
  for (final diet in [
    'vegan',
    'vegetarian',
    'pescatarian',
    'gluten-free',
    'halal',
    'kosher',
    'sugar-free',
    'lactose-free',
    'low-fodmap',
  ]) {
    test('entire shipped corpus honors $diet exclusions', () {
      final profile = Profile(
        diet: diet,
        maxTimeMinutes: 120,
        calorieTarget: 600,
        calorieTolerance: 1000,
      );
      repository.ontology.applyDiet(profile, diet);
      final forbidden = repository.ontology.expand({diet});
      final visibleRecipes = repository.recipes.values
          .where((r) => matches(r, profile))
          .toList();
      expect(visibleRecipes, isNotEmpty);
      for (final recipe in visibleRecipes) {
        expect(
          recipe.contains.intersection(forbidden),
          isEmpty,
          reason: recipe.id,
        );
        for (final item in recipe.ingredients) {
          expect(
            repository.dictionary.flagsFor(item.id).intersection(forbidden),
            isEmpty,
            reason: '${recipe.id}: ${item.id}',
          );
        }
      }
    });
  }
}
