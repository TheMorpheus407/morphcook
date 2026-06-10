import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/models.dart';

void main() {
  group('Matching Algorithm Tests', () {
    late Recipe doenerClassic;
    late Recipe doenerVegan;
    late UserProfile profile;

    setUp(() {
      doenerClassic = Recipe(
        id: "doener-classic",
        dishId: "doener",
        name: { "en": "Classic Beef Döner", "de": "Klassischer Rinder-Döner" },
        description: { "en": "Classic", "de": "Klassisch" },
        containsFlags: ["beef", "dairy", "gluten", "high-fodmap"],
        attributes: ["medium", "≤30", "≤800", "pan-fry"],
        timeMinutes: 25,
        caloriesPerServing: 650,
        nutrition: {},
        ingredientIds: ["beef", "whole-milk", "wheat-flour", "garlic", "onions", "cabbage"],
        ingredients: [],
        steps: [],
      );

      doenerVegan = Recipe(
        id: "doener-vegan",
        dishId: "doener",
        name: { "en": "Vegan Tofu Döner", "de": "Veganer Tofu-Döner" },
        description: { "en": "Vegan", "de": "Vegan" },
        containsFlags: ["gluten", "soy"],
        attributes: ["easy", "≤30", "≤600", "pan-fry"],
        timeMinutes: 20,
        caloriesPerServing: 520,
        nutrition: {},
        ingredientIds: ["wheat-flour", "onions", "cabbage"],
        ingredients: [],
        steps: [],
      );

      profile = UserProfile.defaultProfile();
    });

    test('Default profile matches classic and vegan recipes', () {
      expect(isRecipeVisible(doenerClassic, profile), isTrue);
      expect(isRecipeVisible(doenerVegan, profile), isTrue);
    });

    test('Class-level avoidance filters out dairy', () {
      profile.avoidFlags.add("dairy");
      expect(isRecipeVisible(doenerClassic, profile), isFalse); // has dairy
      expect(isRecipeVisible(doenerVegan, profile), isTrue);  // no dairy
    });

    test('Specific-level ingredient avoidance filters out cabbage', () {
      profile.avoidIngredients.add("cabbage");
      expect(isRecipeVisible(doenerClassic, profile), isFalse); // has cabbage
      expect(isRecipeVisible(doenerVegan, profile), isFalse);  // has cabbage
    });

    test('Time limit filters out longer recipes', () {
      profile.maxTimeMinutes = 22;
      expect(isRecipeVisible(doenerClassic, profile), isFalse); // 25 mins
      expect(isRecipeVisible(doenerVegan, profile), isTrue);   // 20 mins
    });

    test('Calorie target with tolerance filters and overrides', () {
      profile.calorieTarget = 400; // tolerance is 150, so max 550
      expect(isRecipeVisible(doenerClassic, profile), isFalse); // 650 is too high (diff 250 > 150)
      expect(isRecipeVisible(doenerVegan, profile), isTrue);   // 520 is within range (diff 120 <= 150)

      // With override
      expect(isRecipeVisible(doenerClassic, profile, overrideCalorieTarget: true), isTrue);
    });
  });

  group('Ranking Algorithm Tests', () {
    late Recipe doenerClassic;
    late Recipe doenerVegan;
    late UserProfile profile;

    setUp(() {
      doenerClassic = Recipe(
        id: "doener-classic",
        dishId: "doener",
        name: { "en": "Classic Beef Döner" },
        description: { "en": "Classic" },
        containsFlags: ["beef", "dairy", "gluten"],
        attributes: ["medium", "≤30", "dinner"],
        timeMinutes: 25,
        caloriesPerServing: 650,
        nutrition: {},
        ingredientIds: [],
        ingredients: [],
        steps: [],
      );

      doenerVegan = Recipe(
        id: "doener-vegan",
        dishId: "doener",
        name: { "en": "Vegan Tofu Döner" },
        description: { "en": "Vegan" },
        containsFlags: ["gluten", "soy"],
        attributes: ["easy", "≤30", "dinner"],
        timeMinutes: 20,
        caloriesPerServing: 520,
        nutrition: {},
        ingredientIds: [],
        ingredients: [],
        steps: [],
      );

      profile = UserProfile.defaultProfile();
    });

    test('Scoring takes into account effort preferences', () {
      // Classic has medium, vegan has easy.
      profile.preferredEffort = "easy";
      profile.calorieTarget = 600;

      double scoreClassic = calculateRecipeScore(
        recipe: doenerClassic,
        profile: profile,
        currentTime: DateTime(2026, 5, 21, 14, 0), // afternoon, no meal time
        recentlyCookedIds: [],
      );

      double scoreVegan = calculateRecipeScore(
        recipe: doenerVegan,
        profile: profile,
        currentTime: DateTime(2026, 5, 21, 14, 0),
        recentlyCookedIds: [],
      );

      // Vegan should score higher since effort matches and calories are closer
      expect(scoreVegan, greaterThan(scoreClassic));
    });

    test('Temporal bonuses apply correctly', () {
      // 1. Evening context (5pm - 9pm): dinner dishes get +90
      DateTime eveningTime = DateTime(2026, 5, 21, 19, 0); // 7 PM
      DateTime afternoonTime = DateTime(2026, 5, 21, 14, 0); // 2 PM

      double afternoonScore = calculateRecipeScore(
        recipe: doenerClassic,
        profile: profile,
        currentTime: afternoonTime,
        recentlyCookedIds: [],
      );

      double eveningScore = calculateRecipeScore(
        recipe: doenerClassic,
        profile: profile,
        currentTime: eveningTime,
        recentlyCookedIds: [],
      );

      expect(eveningScore, equals(afternoonScore + 90.0));
    });
  });
}
