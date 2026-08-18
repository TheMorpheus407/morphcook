import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/backup_data.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/cooking_history_item.dart';
import 'package:morphcook/models/shopping_item.dart';
import 'package:morphcook/models/localized_string.dart';
import 'package:morphcook/services/backup_service.dart';

void main() {
  group('BackupService Encryption, Compression, and Restore Tests', () {
    late BackupData sampleBackup;

    setUp(() {
      sampleBackup = BackupData(
        schemaVersion: 1,
        exportedAt: '2026-08-14T10:00:00Z',
        profile: UserProfile(
          name: 'Nostalgic Cook',
          lang: 'de',
          avoidFlags: {'pork', 'dairy'},
          avoidIngredients: {'cilantro'},
          requiredAttributes: {'easy'},
          calorieTarget: 550,
          maxTimeMinutes: 30,
        ),
        saved: ['doener-vegan', 'carbonara-classic'],
        mealPlan: {
          '2026-W33': {'mon.dinner': 'doener-vegan', 'tue.lunch': 'carbonara-classic'}
        },
        history: [
          CookingHistoryItem(
            recipeId: 'doener-vegan',
            dishId: 'doener',
            cookedAt: DateTime(2026, 8, 10),
            timeSpentMinutes: 25,
          )
        ],
        shoppingList: [
          ShoppingItem(
            id: 's1',
            ingredientId: 'garlic',
            name: const LocalizedString({'en': 'Garlic', 'de': 'Knoblauch'}),
            amount: 2.0,
            unit: 'cloves',
            aisle: 'Produce',
          )
        ],
        contentRequests: ['sushi rolls', 'pho'],
      );
    });

    test('Unencrypted export and restore via plain JSON', () {
      final exportResult = BackupService.exportBackup(data: sampleBackup);
      expect(exportResult.isEncrypted, isFalse);
      expect(BackupService.isEncryptedBytes(exportResult.jsonBytes), isFalse);

      final restored = BackupService.restoreFromBytes(bytes: exportResult.jsonBytes);
      expect(restored.profile.name, equals('Nostalgic Cook'));
      expect(restored.profile.lang, equals('de'));
      expect(restored.saved, contains('doener-vegan'));
      expect(restored.contentRequests, contains('sushi rolls'));
    });

    test('Unencrypted export and restore via GZip compression', () {
      final exportResult = BackupService.exportBackup(data: sampleBackup);
      expect(BackupService.isGzipBytes(exportResult.gzipBytes), isTrue);

      final restored = BackupService.restoreFromBytes(bytes: exportResult.gzipBytes);
      expect(restored.profile.name, equals('Nostalgic Cook'));
      expect(restored.saved.length, equals(2));
      expect(restored.mealPlan['2026-W33']?['mon.dinner'], equals('doener-vegan'));
    });

    test('AES-256-GCM encryption with correct password succeeds', () {
      const password = 'SuperSecretVintagePassword123!';
      final exportResult = BackupService.exportBackup(
        data: sampleBackup,
        password: password,
      );

      expect(exportResult.isEncrypted, isTrue);
      expect(BackupService.isEncryptedBytes(exportResult.jsonBytes), isTrue);

      // Restore with correct password
      final restored = BackupService.restoreFromBytes(
        bytes: exportResult.jsonBytes,
        password: password,
      );

      expect(restored.profile.name, equals('Nostalgic Cook'));
      expect(restored.profile.avoidFlags, contains('pork'));
      expect(restored.history.first.recipeId, equals('doener-vegan'));
    });

    test('AES-256-GCM decryption with wrong password throws DecryptionException', () {
      const password = 'CorrectPassword';
      final exportResult = BackupService.exportBackup(
        data: sampleBackup,
        password: password,
      );

      expect(
        () => BackupService.restoreFromBytes(
          bytes: exportResult.jsonBytes,
          password: 'WrongPassword',
        ),
        throwsA(isA<DecryptionException>().having(
          (e) => e.message,
          'message',
          contains('Incorrect password'),
        )),
      );
    });

    test('Merge mode unions saved recipes, meal plans, and shopping items', () {
      final current = BackupData(
        exportedAt: '2026-08-14T00:00:00Z',
        profile: UserProfile(name: 'Current User', avoidFlags: {'dairy'}),
        saved: ['recipe-1'],
        mealPlan: {
          '2026-W33': {'mon.lunch': 'recipe-1'}
        },
        history: [],
        shoppingList: [
          ShoppingItem(
            id: 'item-1',
            ingredientId: 'garlic',
            name: const LocalizedString({'en': 'Garlic'}),
            amount: 2.0,
            unit: 'cloves',
            aisle: 'Produce',
          )
        ],
        contentRequests: ['risotto'],
      );

      final incoming = BackupData(
        exportedAt: '2026-08-14T01:00:00Z',
        profile: UserProfile(name: 'Incoming User', avoidFlags: {'pork'}),
        saved: ['recipe-2'],
        mealPlan: {
          '2026-W33': {'mon.dinner': 'recipe-2'},
          '2026-W34': {'tue.dinner': 'recipe-3'}
        },
        history: [],
        shoppingList: [
          ShoppingItem(
            id: 'item-2',
            ingredientId: 'garlic',
            name: const LocalizedString({'en': 'Garlic'}),
            amount: 3.0,
            unit: 'cloves',
            aisle: 'Produce',
          )
        ],
        contentRequests: ['paella'],
      );

      final merged = BackupService.mergeData(current: current, incoming: incoming);

      expect(merged.profile.avoidFlags, containsAll(['dairy', 'pork']));
      expect(merged.saved, containsAll(['recipe-1', 'recipe-2']));
      expect(merged.mealPlan['2026-W33']?['mon.lunch'], equals('recipe-1'));
      expect(merged.mealPlan['2026-W33']?['mon.dinner'], equals('recipe-2'));
      expect(merged.mealPlan['2026-W34']?['tue.dinner'], equals('recipe-3'));

      // Shopping list unit-aware aggregation: 2 cloves + 3 cloves = 5 cloves
      expect(merged.shoppingList.length, equals(1));
      expect(merged.shoppingList.first.amount, equals(5.0));
      expect(merged.contentRequests, containsAll(['risotto', 'paella']));
    });
  });
}
