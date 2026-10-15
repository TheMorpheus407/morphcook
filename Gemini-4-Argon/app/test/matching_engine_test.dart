import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/dish.dart';
import 'package:morphcook/models/ingredient_dictionary.dart';
import 'package:morphcook/models/ontology.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe.dart';
import 'package:morphcook/services/matching_engine.dart';

void main() {
  late Ontology ontology;
  late IngredientDictionary dictionary;
  late List<Dish> dishes;
  late List<Recipe> recipes;

  setUpAll(() {
    final assetPrefix = Directory('assets').existsSync() ? 'assets' : 'app/assets';
    ontology = Ontology.fromJson(
      jsonDecode(File('$assetPrefix/ontology.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    dictionary = IngredientDictionary.fromJson(
      jsonDecode(File('$assetPrefix/ingredients.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final dishesJson =
        jsonDecode(File('$assetPrefix/dishes.json').readAsStringSync())
            as Map<String, dynamic>;
    dishes = (dishesJson['dishes'] as List<dynamic>)
        .map((e) => Dish.fromJson(e as Map<String, dynamic>))
        .toList();
    final recipesJson =
        jsonDecode(File('$assetPrefix/recipes.json').readAsStringSync())
            as Map<String, dynamic>;
    recipes = (recipesJson['recipes'] as List<dynamic>)
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  group('MatchingEngine.visible pure function', () {
    test('excludes recipes whose contains-flags intersect avoid_flags', () {
      final classicDoener = recipes.firstWhere((r) => r.id == 'doener-classic');
      final veganDoener = recipes.firstWhere((r) => r.id == 'doener-vegan');

      const veganProfile = UserProfile(
        avoidFlags: {'vegan'},
        maxTimeMinutes: 60,
        calorieTarget: 600,
        calorieTolerance: 300,
      );

      expect(
        MatchingEngine.visible(
          classicDoener,
          veganProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isFalse,
      );
      expect(
        MatchingEngine.visible(
          veganDoener,
          veganProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isTrue,
      );
    });

    test('propagates parent ingredient avoidance to all descendant leaf ingredients', () {
      // Classic Alfredo uses 'parmesan' and 'butter' under 'dairy' -> 'cheese' -> 'parmesan'
      final classicAlfredo = recipes.firstWhere((r) => r.id == 'alfredo-classic');
      final veganAlfredo = recipes.firstWhere((r) => r.id == 'alfredo-vegan');

      const avoidCheeseParentProfile = UserProfile(
        avoidIngredients: {'cheese'}, // parent node of parmesan, feta, pecorino
        maxTimeMinutes: 60,
        calorieTarget: 600,
        calorieTolerance: 300,
      );

      expect(
        MatchingEngine.visible(
          classicAlfredo,
          avoidCheeseParentProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isFalse,
      );
      expect(
        MatchingEngine.visible(
          veganAlfredo,
          avoidCheeseParentProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isTrue,
      );

      // Avoiding 'tree-nuts' excludes 'cashew-cream' in vegan Alfredo
      const avoidTreeNutsProfile = UserProfile(
        avoidIngredients: {'tree-nuts'},
        maxTimeMinutes: 60,
        calorieTarget: 600,
        calorieTolerance: 300,
      );
      expect(
        MatchingEngine.visible(
          veganAlfredo,
          avoidTreeNutsProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isFalse,
      );
    });

    test('enforces required_attributes subset, max_time_minutes, and calorie_target tolerance', () {
      final halalLambDoener = recipes.firstWhere((r) => r.id == 'doener-halal'); // 55 min, 640 kcal
      final veganDoener = recipes.firstWhere((r) => r.id == 'doener-vegan'); // 25 min, 520 kcal

      const strictTimeProfile = UserProfile(
        requiredAttributes: {'halal'},
        maxTimeMinutes: 30,
        calorieTarget: 520,
        calorieTolerance: 50,
      );

      expect(
        MatchingEngine.visible(
          halalLambDoener,
          strictTimeProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isFalse, // 55m > 30m and 640 kcal outside 520±50
      );
      expect(
        MatchingEngine.visible(
          veganDoener,
          strictTimeProfile,
          ontology: ontology,
          dictionary: dictionary,
        ),
        isTrue,
      );

      // Per-dish calorie override allows out-of-range calories when time allows
      const relaxedTimeStrictCalProfile = UserProfile(
        maxTimeMinutes: 60,
        calorieTarget: 400,
        calorieTolerance: 50,
        calorieFilterEnabled: true,
      );
      expect(
        MatchingEngine.visible(
          halalLambDoener,
          relaxedTimeStrictCalProfile,
          ontology: ontology,
          dictionary: dictionary,
          ignoreCalorieFilter: false,
        ),
        isFalse,
      );
      expect(
        MatchingEngine.visible(
          halalLambDoener,
          relaxedTimeStrictCalProfile,
          ontology: ontology,
          dictionary: dictionary,
          ignoreCalorieFilter: true,
        ),
        isTrue,
      );
    });
  });

  group('Time-Aware & Staleness-Aware Ranking', () {
    test('awards +200 morning breakfast bonus, +90 evening dinner bonus, and +90 weekend effort bonus', () {
      final breakfastRecipe = recipes.firstWhere((r) => r.id == 'pancakes-classic'); // easy, breakfast
      final dinnerHardRecipe = recipes.firstWhere((r) => r.id == 'ramen-classic'); // hard, dinner

      // Wednesday 8:00 AM -> Morning context (+200 for breakfast)
      final wedMorning = DateTime(2026, 10, 14, 8, 0);
      expect(MatchingEngine.calculateTemporalBonus(breakfastRecipe, wedMorning), 200);
      expect(MatchingEngine.calculateTemporalBonus(dinnerHardRecipe, wedMorning), 0);

      // Wednesday 6:30 PM -> Evening context (+90 for dinner)
      final wedEvening = DateTime(2026, 10, 14, 18, 30);
      expect(MatchingEngine.calculateTemporalBonus(breakfastRecipe, wedEvening), 0);
      expect(MatchingEngine.calculateTemporalBonus(dinnerHardRecipe, wedEvening), 90);

      // Saturday 6:30 PM -> Weekend (+90 for medium/hard) + Evening (+90 for dinner) = +180
      final satEvening = DateTime(2026, 10, 17, 18, 30);
      expect(MatchingEngine.calculateTemporalBonus(dinnerHardRecipe, satEvening), 180);
    });

    test('awards +50 staleness bonus only when recipe was last cooked 30+ days ago', () {
      final now = DateTime(2026, 10, 14, 12, 0);
      final cooked45DaysAgo = now.subtract(const Duration(days: 45));
      final cooked10DaysAgo = now.subtract(const Duration(days: 10));

      expect(MatchingEngine.calculateStalenessBonus(null, now), 0);
      expect(MatchingEngine.calculateStalenessBonus(cooked10DaysAgo, now), 0);
      expect(MatchingEngine.calculateStalenessBonus(cooked45DaysAgo, now), 50);
    });

    test('buildDimensionMatrix marks unreachable combinations as disabled with a note rather than hiding them', () {
      final doenerVariants = recipes.where((r) => r.dishId == 'doener').toList();
      final veganDoener = doenerVariants.firstWhere((r) => r.id == 'doener-vegan');

      final matrix = MatchingEngine.buildDimensionMatrix(
        allDishVariants: doenerVariants,
        currentRecipe: veganDoener,
        profile: const UserProfile(lang: 'en'),
        ontology: ontology,
        dictionary: dictionary,
      );

      // Vegan Döner is 'easy'; there is no 'vegan' × 'hard' Döner variant
      final hardOption = matrix.effortOptions.firstWhere((o) => o.value == 'hard');
      expect(hardOption.isEnabled, isFalse);
      expect(hardOption.disabledReason, contains('no vegan × hard version yet'));
    });

    test('every dish in corpus has at least one visible variant for vegan, halal, gluten-free, and classic profiles', () {
      final testProfiles = [
        const UserProfile(avoidFlags: {'vegan'}, maxTimeMinutes: 90),
        const UserProfile(avoidFlags: {'halal'}, maxTimeMinutes: 90),
        const UserProfile(avoidFlags: {'gluten-free'}, maxTimeMinutes: 90),
        const UserProfile(maxTimeMinutes: 90),
      ];

      for (final dish in dishes) {
        final dishVariants = recipes.where((r) => r.dishId == dish.id).toList();
        expect(dishVariants.length, greaterThanOrEqualTo(4));
        for (final profile in testProfiles) {
          final best = MatchingEngine.selectBestVariant(
            dishVariants,
            profile,
            ontology: ontology,
            dictionary: dictionary,
            ignoreCalorieFilter: true,
          );
          expect(
            best,
            isNotNull,
            reason: 'Dish ${dish.id} should have a visible variant for ${profile.avoidFlags}',
          );
        }
      }
    });
  });
}
