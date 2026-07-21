import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data.dart';
import 'package:morphcook/models.dart';
import 'package:morphcook/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipeRepository repository;

  setUpAll(() async {
    repository = await RecipeRepository.load();
  });

  test('matching excludes contains flags and parent ingredient avoidance', () {
    final profile = Profile.fresh().copyWith(
      avoidFlags: {'dairy'},
      calorieTarget: 700,
    );
    expect(
      RecipeMatcher.isVisible(
        repository.recipes['doener-classic']!,
        profile,
        repository,
      ),
      isFalse,
    );
    expect(
      RecipeMatcher.isVisible(
        repository.recipes['doener-vegan']!,
        profile,
        repository,
      ),
      isTrue,
    );

    final cheeseAvoidingProfile = Profile.fresh().copyWith(
      avoidIngredients: {'cheese'},
      calorieTarget: 800,
    );
    expect(
      RecipeMatcher.isVisible(
        repository.recipes['alfredo-classic']!,
        cheeseAvoidingProfile,
        repository,
      ),
      isFalse,
    );
  });

  test(
    'shopping aggregation deduplicates count units and converts tablespoons to ml',
    () {
      final lines = ShoppingAggregator.aggregate([
        repository.recipes['doener-classic']!,
        repository.recipes['doener-vegan']!,
      ], repository.ingredientIndex);
      final garlic = lines.singleWhere(
        (line) => line.ingredient?.id == 'garlic',
      );
      final oliveOil = lines.singleWhere(
        (line) => line.ingredient?.id == 'olive-oil',
      );

      expect(garlic.amount, 5);
      expect(garlic.unit, 'cloves');
      expect(oliveOil.amount, 30);
      expect(oliveOil.unit, 'ml');
    },
  );

  test('encrypted backup has ENC magic and needs its password', () async {
    final payload = {
      'schema_version': 1,
      'exported_at': '2026-07-10T12:00:00Z',
      'profile': Profile.fresh().toJson(),
      'saved': ['doener-vegan'],
      'meal_plan': <String, String>{},
      'history': <Object>[],
      'content_requests': ['ramen'],
    };
    final bytes = await BackupService.encrypt(
      utf8.encode(BackupService.prettyJson(payload)),
      'quiet-kitchen',
    );

    expect(bytes.take(3), orderedEquals([0x45, 0x4e, 0x43]));
    expect(
      await BackupService.decode(bytes, password: 'quiet-kitchen'),
      payload,
    );
    expect(
      () => BackupService.decode(bytes, password: 'wrong'),
      throwsA(isA<DecryptionException>()),
    );
  });

  test('time-aware ranking gives breakfast a morning lift', () {
    final profile = Profile.fresh().copyWith(
      calorieTarget: 400,
      maxTimeMinutes: 60,
    );
    final breakfast = repository.recipes['overnight-oats-berry']!;
    final dinner = repository.recipes['doener-vegan']!;
    final morning = DateTime(2026, 7, 10, 8);

    expect(
      RecipeRanker.score(breakfast, profile, const [], now: morning),
      greaterThan(RecipeRanker.score(dinner, profile, const [], now: morning)),
    );
  });
}
