import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/user_data.dart';
import 'package:morphcook/services/backup_service.dart';

void main() {
  final profile = const Profile(
    name: 'Ada',
    lang: 'de',
    avoidFlags: {'dairy'},
    avoidIngredients: {'apples'},
    requiredAttributes: {'halal'},
    onboardingComplete: true,
  );
  final snapshot = UserSnapshot(
    saved: [
      SavedRecipe(recipeId: 'vegan-doener', savedAt: DateTime.utc(2026, 4, 1)),
    ],
    history: [
      HistoryEntry(
        id: 'h1',
        recipeId: 'vegan-doener',
        cookedAt: DateTime.utc(2026, 4, 2),
        servings: 2,
      ),
    ],
    mealPlan: {
      '2026-W16': {'mon.dinner': 'vegan-doener'},
    },
    shoppingRecipeIds: const ['vegan-doener'],
    checkedShoppingItems: const {'garlic:count:clove'},
    shoppingEvents: [
      ShoppingEvent(
        id: 'e1',
        ingredientId: 'garlic',
        recipeId: 'vegan-doener',
        addedAt: DateTime.utc(2026, 4, 2),
        amount: 2,
        unit: 'clove',
      ),
    ],
    contentRequests: const ['sushi'],
    cookProgress: {
      'vegan-doener': CookProgress(
        recipeId: 'vegan-doener',
        stepIndex: 1,
        remainingSeconds: 30,
        servings: 3,
        isRunning: false,
        updatedAt: DateTime.utc(2026, 4, 2),
      ),
    },
  );

  test('plain JSON and GZip round-trip the complete local state', () async {
    final service = BackupService(random: Random(7));
    final exported = await service.create(
      profile,
      snapshot,
      exportedAt: DateTime.utc(2026, 4, 18, 12),
    );
    expect(utf8.decode(exported.jsonBytes), contains('"schema_version": 1'));
    expect(exported.gzipBytes.length, lessThan(exported.jsonBytes.length));
    for (final bytes in [exported.jsonBytes, exported.gzipBytes]) {
      final restored = await service.import(bytes);
      expect(restored.profile.name, 'Ada');
      expect(restored.profile.lang, 'de');
      expect(restored.snapshot.saved.single.recipeId, 'vegan-doener');
      expect(
        restored.snapshot.mealPlan['2026-W16']?['mon.dinner'],
        'vegan-doener',
      );
      expect(restored.snapshot.history.single.id, 'h1');
      expect(restored.snapshot.contentRequests, ['sushi']);
      expect(
        restored.snapshot.cookProgress['vegan-doener']?.remainingSeconds,
        30,
      );
      expect(restored.snapshot.shoppingEvents.single.ingredientId, 'garlic');
    }
  });

  test(
    'encrypted JSON uses ENC and fresh salt/IV while gzip stays readable',
    () async {
      final service = BackupService(random: Random(11));
      final first = await service.create(
        profile,
        snapshot,
        password: 'correct horse',
      );
      final second = await service.create(
        profile,
        snapshot,
        password: 'correct horse',
      );
      expect(first.jsonBytes.sublist(0, 3), [0x45, 0x4e, 0x43]);
      expect(first.jsonBytes, isNot(second.jsonBytes));
      expect(first.gzipBytes.sublist(0, 2), [0x1f, 0x8b]);
      expect(
        jsonDecode(
          utf8.decode(gzip.decode(first.gzipBytes)),
        )['profile']['name'],
        'Ada',
      );
      final restored = await service.import(
        first.jsonBytes,
        password: 'correct horse',
      );
      expect(restored.snapshot.saved.single.recipeId, 'vegan-doener');
    },
  );

  test(
    'encrypted import requires password and reports wrong password exactly',
    () async {
      final service = BackupService(random: Random(3));
      final exported = await service.create(
        profile,
        snapshot,
        password: 'secret',
      );
      try {
        await service.import(exported.jsonBytes);
        fail('Expected passwordRequired');
      } on DecryptionException catch (error) {
        expect(error.reason, DecryptionFailure.passwordRequired);
      }
      try {
        await service.import(exported.jsonBytes, password: 'wrong');
        fail('Expected wrongPassword');
      } on DecryptionException catch (error) {
        expect(error.reason, DecryptionFailure.wrongPassword);
        expect(error.message, 'Incorrect password. Please try again.');
      }
    },
  );

  test('detects corrupted and invalid files in magic-byte order', () async {
    final service = BackupService();
    try {
      await service.import(Uint8List.fromList([0x45, 0x4e, 0x43, 1, 2]));
      fail('Expected corrupted');
    } on DecryptionException catch (error) {
      expect(error.reason, DecryptionFailure.corrupted);
      expect(error.message, 'Backup file is corrupted and cannot be restored.');
    }
    try {
      await service.import(Uint8List.fromList([0x1f, 0x8b, 1, 2]));
      fail('Expected corrupted gzip');
    } on DecryptionException catch (error) {
      expect(error.reason, DecryptionFailure.corrupted);
    }
    try {
      await service.import(utf8.encode('not json'));
      fail('Expected invalidFormat');
    } on DecryptionException catch (error) {
      expect(error.reason, DecryptionFailure.invalidFormat);
      expect(error.message, 'This file is not a valid MorphCook backup.');
    }
  });

  test('rejects unsupported schema without touching corpus', () async {
    final service = BackupService();
    final bytes = utf8.encode(
      jsonEncode({'schema_version': 99, 'profile': {}}),
    );
    expect(
      () => service.import(bytes),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('merge unions collections and replace keeps incoming exact', () {
    final local = UserSnapshot(
      saved: [
        SavedRecipe(recipeId: 'local', savedAt: DateTime.utc(2026, 1, 1)),
      ],
      contentRequests: const ['local query'],
      mealPlan: {
        '2026-W16': {'mon.lunch': 'local'},
      },
    );
    final merged = local.mergedWith(snapshot);
    expect(
      merged.saved.map((item) => item.recipeId),
      containsAll(['local', 'vegan-doener']),
    );
    expect(merged.contentRequests, containsAll(['local query', 'sushi']));
    expect(merged.mealPlan['2026-W16'], {
      'mon.lunch': 'local',
      'mon.dinner': 'vegan-doener',
    });
  });
}
