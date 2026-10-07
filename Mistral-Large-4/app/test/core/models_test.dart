import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/model/dish.dart';
import 'package:morphcook/core/model/ingredient.dart';
import 'package:morphcook/core/model/localized.dart';
import 'package:morphcook/core/model/meal_plan.dart';
import 'package:morphcook/core/model/ontology.dart';
import 'package:morphcook/core/model/profile.dart';
import 'package:morphcook/core/model/recipe.dart';
import 'package:morphcook/core/model/shopping.dart';

void main() {
  group('LocalizedText', () {
    const text = LocalizedText({'en': 'hello', 'de': 'hallo'});

    test('resolves the requested language', () {
      expect(text.resolve('de'), 'hallo');
      expect(text.resolve('en'), 'hello');
    });

    test('falls back to english, then to any value', () {
      expect(const LocalizedText({'en': 'hello'}).resolve('de'), 'hello');
      expect(const LocalizedText({'de': 'hallo'}).resolve('fr'), 'hallo');
    });

    test('empty strings fall through to the fallback', () {
      expect(const LocalizedText({'en': 'hello', 'de': ''}).resolve('de'), 'hello');
    });

    test('json roundtrip', () {
      expect(LocalizedText.fromJson(text.toJson()).toJson(), text.toJson());
      expect(text.toJson(), {'en': 'hello', 'de': 'hallo'});
    });
  });

  group('UserProfile', () {
    test('defaults are the documented v1 defaults', () {
      const p = UserProfile();
      expect(p.lang, 'en');
      expect(p.maxTimeMinutes, 60);
      expect(p.calorieTarget, 600);
      expect(p.preferredEffort, 'medium');
      expect(p.showVariantTags, true);
      expect(p.reduceMotion, isNull); // null follows the system setting
      expect(p.visualAlertEnabled, true);
      expect(p.quickNextTapEnabled, false);
      expect(p.onboardingComplete, false);
      expect(p.avoidFlags, isEmpty);
      expect(p.avoidIngredients, isEmpty);
      expect(p.requiredAttributes, isEmpty);
    });

    test('json roundtrip preserves every field', () {
      final p = UserProfile(
        name: 'sam',
        lang: 'de',
        avoidFlags: {'dairy', 'nuts'},
        avoidIngredients: {'cilantro'},
        requiredAttributes: {'halal'},
        maxTimeMinutes: 45,
        calorieTarget: 700,
        preferredEffort: 'easy',
        showVariantTags: false,
        reduceMotion: true,
        visualAlertEnabled: false,
        quickNextTapEnabled: true,
        onboardingComplete: true,
      );
      final restored = UserProfile.fromJson(p.toJson());
      expect(restored.toJson(), p.toJson());
      expect(restored.avoidFlags, {'dairy', 'nuts'});
      expect(restored.requiredAttributes, {'halal'});
    });

    test('copyWith overrides only what is passed', () {
      const p = UserProfile(name: 'sam', calorieTarget: 500);
      final updated = p.copyWith(calorieTarget: 800, lang: 'de');
      expect(updated.name, 'sam');
      expect(updated.calorieTarget, 800);
      expect(updated.lang, 'de');
    });

    test('copyWith can clear reduceMotion back to null', () {
      const p = UserProfile(reduceMotion: true);
      expect(p.copyWith(clearReduceMotion: true).reduceMotion, isNull);
      expect(p.copyWith(reduceMotion: false).reduceMotion, false);
    });
  });

  group('Recipe', () {
    final recipe = Recipe(
      id: 'doener-classic',
      dishId: 'doener',
      title: const LocalizedText({'en': 'Döner', 'de': 'Döner'}),
      subtitle: const LocalizedText({'en': 'the classic'}),
      diet: 'classic',
      effort: 'medium',
      timeMinutes: 35,
      caloriesPerServing: 780,
      servings: 2,
      contains: {'gluten'},
      attributes: {'medium'},
      tags: ['street-food'],
      mealType: 'dinner',
      ingredients: [
        const IngredientLine(ingredientId: 'garlic', amount: 2, unit: 'cloves'),
        const IngredientLine(ingredientId: 'lamb', amount: 300, unit: 'g'),
      ],
      steps: [
        CookStep(text: const LocalizedText({'en': 'Sear.'}), timerMinutes: 5),
        const CookStep(text: LocalizedText({'en': 'Rest.'})),
      ],
      macros: const Macros(kcal: 780, proteinG: 40, carbsG: 60, fatG: 38),
    );

    test('json roundtrip', () {
      final restored = Recipe.fromJson(recipe.toJson());
      expect(restored.id, recipe.id);
      expect(restored.title.resolve('en'), 'Döner');
      expect(restored.contains, {'gluten'});
      expect(restored.ingredients.length, 2);
      expect(restored.steps[0].timerMinutes, 5);
      expect(restored.steps[1].timerMinutes, isNull);
      expect(restored.macros.kcal, 780);
    });

    test('ingredientIds collects the used ids', () {
      expect(recipe.ingredientIds, {'garlic', 'lamb'});
    });

    test('scaled multiplies amounts by the servings factor', () {
      final line = recipe.scaled(recipe.ingredients[1], 4); // 2 -> 4 servings
      expect(line.amount, 600);
      expect(line.unit, 'g');
      expect(line.ingredientId, 'lamb');
    });

    test('copyWith can retarget servings', () {
      expect(recipe.copyWith(servings: 4).servings, 4);
      expect(recipe.servings, 2);
    });
  });

  group('Ontology', () {
    const ontology = Ontology(
      containsFlags: ['dairy', 'gluten', 'meat', 'egg'],
      compoundAvoidFlags: {
        'vegan': ['dairy', 'meat', 'egg'],
        'dairy-free': ['dairy'],
      },
      attributes: {
        'effort': ['easy', 'medium', 'hard'],
        'time_bucket': ['≤15', '≤30', '≤60', '>60'],
        'calorie_bucket': ['≤400', '≤600', '≤800', '>800'],
        'technique': ['one-pot'],
      },
      dietOptions: ['classic', 'vegan', 'keto'],
    );

    test('expandAvoidFlags resolves compound flags transitively', () {
      expect(ontology.expandAvoidFlags({'vegan'}), {'vegan', 'dairy', 'meat', 'egg'});
      expect(ontology.expandAvoidFlags({'dairy-free'}), {'dairy-free', 'dairy'});
      // plain contains-flags pass through untouched
      expect(ontology.expandAvoidFlags({'gluten'}), {'gluten'});
      expect(ontology.expandAvoidFlags(const {}), isEmpty);
    });

    test('buckets match the documented boundaries', () {
      expect(ontology.calorieBucketFor(400), '≤400');
      expect(ontology.calorieBucketFor(401), '≤600');
      expect(ontology.calorieBucketFor(600), '≤600');
      expect(ontology.calorieBucketFor(601), '≤800');
      expect(ontology.calorieBucketFor(800), '≤800');
      expect(ontology.calorieBucketFor(801), '>800');
      expect(ontology.timeBucketFor(15), '≤15');
      expect(ontology.timeBucketFor(16), '≤30');
      expect(ontology.timeBucketFor(30), '≤30');
      expect(ontology.timeBucketFor(31), '≤60');
      expect(ontology.timeBucketFor(60), '≤60');
      expect(ontology.timeBucketFor(61), '>60');
    });

    test('json roundtrip', () {
      final restored = Ontology.fromJson(ontology.toJsonForTest());
      expect(restored.containsFlags, ontology.containsFlags);
      expect(restored.compoundAvoidFlags['vegan'], ['dairy', 'meat', 'egg']);
      expect(restored.dietOptions, ['classic', 'vegan', 'keto']);
    });
  });

  group('IngredientDictionary', () {
    final dict = IngredientDictionary([
      IngredientNode(
        id: 'dairy',
        name: const LocalizedText({'en': 'dairy'}),
        aisle: 'dairy',
        children: [
          IngredientNode(
            id: 'milk',
            name: const LocalizedText({'en': 'milk'}),
            aisle: 'dairy',
            children: [
              IngredientNode(
                id: 'whole-milk',
                name: const LocalizedText({'en': 'whole milk'}),
                aisle: 'dairy',
              ),
            ],
          ),
        ],
      ),
      IngredientNode(
        id: 'garlic',
        name: const LocalizedText({'en': 'garlic', 'de': 'Knoblauch'}),
        aisle: 'produce',
      ),
    ]);

    test('find indexes every level of the tree', () {
      expect(dict.find('dairy')?.id, 'dairy');
      expect(dict.find('whole-milk')?.id, 'whole-milk');
      expect(dict.find('nope'), isNull);
    });

    test('avoidance propagates to all descendants', () {
      expect(dict.expandAvoidance({'dairy'}), {'dairy', 'milk', 'whole-milk'});
      expect(dict.expandAvoidance({'milk'}), {'milk', 'whole-milk'});
      expect(dict.expandAvoidance({'garlic'}), {'garlic'});
      // unknown ids pass through so a stale profile never crashes matching
      expect(dict.expandAvoidance({'ghost'}), {'ghost'});
    });

    test('searchable flattens the whole tree', () {
      expect(dict.searchable.map((n) => n.id), ['dairy', 'milk', 'whole-milk', 'garlic']);
    });

    test('nameOf and aisleOf resolve with fallbacks', () {
      expect(dict.nameOf('garlic', 'de'), 'Knoblauch');
      expect(dict.nameOf('garlic', 'fr'), 'garlic'); // falls back to en
      expect(dict.nameOf('ghost', 'en'), 'ghost');
      expect(dict.aisleOf('whole-milk'), 'dairy');
      expect(dict.aisleOf('ghost'), 'pantry');
    });

    test('descendantIds excludes the node itself', () {
      expect(dict.find('dairy')!.descendantIds(), {'milk', 'whole-milk'});
      expect(dict.find('garlic')!.isLeaf, true);
    });
  });

  group('Dish', () {
    test('json roundtrip keeps partition routing fields', () {
      final dish = Dish.fromJson({
        'id': 'doener',
        'name': {'en': 'Döner'},
        'hero': {'en': 'the late-night classic'},
        'cap_caption': {'en': 'wrapped, sauced'},
        'stripe_color': '#C1543C',
        'variant_ids': ['doener-classic', 'doener-vegan'],
        'partition_id': 'core',
        'secondary_partitions': ['cuisine-middle-eastern'],
        'cuisine_tags': ['middle-eastern'],
        'frequency_tier': 'core',
      });
      expect(dish.partitionId, 'core');
      expect(dish.secondaryPartitions, ['cuisine-middle-eastern']);
      expect(dish.frequencyTier, 'core');
      final restored = Dish.fromJson(dish.toJson());
      expect(restored.toJson(), dish.toJson());
    });
  });

  group('Shopping models', () {
    test('ShoppingItem json roundtrip and copyWith', () {
      final item = ShoppingItem(
        ingredientId: 'garlic',
        amount: 5,
        unit: 'cloves',
        sourceRecipeIds: ['doener-classic'],
        addedAt: DateTime.utc(2026, 10, 7, 12),
      );
      final restored = ShoppingItem.fromJson(item.toJson());
      expect(restored.ingredientId, 'garlic');
      expect(restored.checked, false);
      expect(restored.sourceRecipeIds, ['doener-classic']);
      expect(restored.copyWith(checked: true).checked, true);
      expect(restored.amount, 5);
    });

    test('ShoppingLogEntry keeps an optional recipe id', () {
      final entry = ShoppingLogEntry(
        ingredientId: 'lamb',
        amount: 300,
        unit: 'g',
        recipeId: 'doener-classic',
        addedAt: DateTime.utc(2026, 10, 7),
      );
      expect(ShoppingLogEntry.fromJson(entry.toJson()).recipeId, 'doener-classic');
      final bare = ShoppingLogEntry(
        ingredientId: 'lamb',
        amount: 300,
        unit: 'g',
        addedAt: DateTime.utc(2026, 10, 7),
      );
      expect(bare.toJson(), isNot(contains('recipe_id')));
    });

    test('HistoryEntry json roundtrip', () {
      final entry = HistoryEntry(
        recipeId: 'doener-classic',
        cookedAt: DateTime.utc(2026, 10, 6, 18, 30),
      );
      final restored = HistoryEntry.fromJson(entry.toJson());
      expect(restored.recipeId, entry.recipeId);
      expect(restored.cookedAt, entry.cookedAt);
    });
  });

  group('meal plan helpers', () {
    test('slotId joins day and meal', () {
      expect(slotId('mon', 'breakfast'), 'mon.breakfast');
      expect(slotId('sun', 'dinner'), 'sun.dinner');
    });

    test('allSlotIds covers 7 days × 3 meals', () {
      expect(allSlotIds().length, 21);
      expect(allSlotIds().first, 'mon.breakfast');
      expect(allSlotIds().last, 'sun.dinner');
    });

    test('weekIdFor is the ISO week of the date’s monday', () {
      // 2026-10-07 is a Wednesday in ISO week 41.
      expect(weekIdFor(DateTime(2026, 10, 7)), '2026-W41');
      // Sunday belongs to the week that started the monday before.
      expect(weekIdFor(DateTime(2026, 10, 11)), '2026-W41');
      expect(weekIdFor(DateTime(2026, 10, 12)), '2026-W42');
      // ISO year boundary: 2026-01-01 is a Thursday → week 1 of 2026.
      expect(weekIdFor(DateTime(2026, 1, 1)), '2026-W01');
    });

    test('mondayOfWeek inverts weekIdFor', () {
      final monday = mondayOfWeek('2026-W41');
      expect(monday.weekday, DateTime.monday);
      expect(weekIdFor(monday), '2026-W41');
      expect(mondayOfWeek('2026-W01'), DateTime(2025, 12, 29));
    });

    test('mondayOfWeek rejects malformed ids', () {
      expect(() => mondayOfWeek('W41'), throwsFormatException);
      expect(() => mondayOfWeek('2026-41'), throwsFormatException);
    });
  });
}

/// Ontology has no toJson in the app (assets are source-of-truth); this
/// helper exists only so the test can roundtrip through the same shape.
extension on Ontology {
  Map<String, dynamic> toJsonForTest() => {
        'contains_flags': containsFlags,
        'compound_avoid_flags': compoundAvoidFlags,
        'attributes': attributes,
        'diet_options': dietOptions,
      };
}
