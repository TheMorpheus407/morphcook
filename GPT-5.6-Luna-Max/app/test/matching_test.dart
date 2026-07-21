import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:io';

import 'package:morphcook/backup_service.dart';
import 'package:morphcook/data.dart';
import 'package:morphcook/models.dart';
import 'package:morphcook/store.dart';

void main() {
  const baseProfile = Profile(
    name: 'Test',
    lang: 'en',
    dietPreference: 'flexible',
    avoidFlags: <String>{},
    avoidIngredients: <String>{},
    requiredAttributes: <String>{},
    maxTimeMinutes: 60,
    calorieTarget: 600,
    preferredEffort: 'easy',
    showVariantTags: true,
    reduceMotion: false,
    visualAlertEnabled: true,
    quickNextTapEnabled: false,
  );

  test('compound vegan avoidance excludes animal recipes', () {
    expect(
      matchesProfile(
        recipeFor('doener-vegan'),
        baseProfile.copyWith(avoidFlags: <String>{'vegan'}),
      ),
      isTrue,
    );
    expect(
      matchesProfile(
        recipeFor('doener-classic'),
        baseProfile.copyWith(avoidFlags: <String>{'vegan'}),
      ),
      isFalse,
    );
  });

  test('specific ingredient avoidance excludes a matching recipe', () {
    final profile = baseProfile.copyWith(
      avoidIngredients: <String>{'cucumber'},
    );
    expect(matchesProfile(recipeFor('doener-vegan'), profile), isFalse);
    expect(
      matchesProfile(
        recipeFor('golden-soup'),
        profile.copyWith(calorieTarget: 500),
      ),
      isTrue,
    );
  });

  test('time and calorie targets are hard filters', () {
    expect(
      matchesProfile(
        recipeFor('doener-classic'),
        baseProfile.copyWith(maxTimeMinutes: 20),
      ),
      isFalse,
    );
    expect(
      matchesProfile(
        recipeFor('alfredo-classic'),
        baseProfile.copyWith(calorieTarget: 300),
      ),
      isFalse,
    );
  });

  test('smart shopping combines matching ingredients', () {
    final store = AppStore();
    store.shoppingRecipeIds
      ..clear()
      ..addAll(<String>{'doener-vegan', 'doener-keto'});
    final cucumber = store.shoppingItems.firstWhere(
      (item) => item.id == 'cucumber',
    );
    expect(cucumber.amount, 1.5);
    expect(cucumber.recipeCount, 2);
  });

  test('backup decoder accepts readable JSON and GZip payloads', () async {
    final store = AppStore();
    final json = utf8.encode(store.backupJson());
    final readable = await BackupService.decode(json);
    final compressed = await BackupService.decode(gzip.encode(json));
    expect(readable['schema_version'], 1);
    expect(compressed['saved'], isA<List<dynamic>>());
  });
}
