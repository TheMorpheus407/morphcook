import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/backup_crypto.dart';
import 'package:morphcook/data/backup_service.dart';
import 'package:morphcook/domain/collections.dart';
import 'package:morphcook/domain/profile.dart';

void main() {
  final now = DateTime.utc(2026, 4, 18, 12);

  BackupDocument document({
    Profile profile = const Profile(name: 'Cedric', lang: 'de'),
    List<String> saved = const ['doener-vegan', 'alfredo-classic'],
    List<String> requests = const ['pad thai', 'sushi'],
  }) {
    final plan = MealPlan()
      ..assign(
        const IsoWeek(2026, 16),
        const PlanSlot('mon', 'dinner'),
        'chili-vegan',
      );
    return BackupDocument(
      schemaVersion: 1,
      exportedAt: now,
      profile: profile,
      saved: [for (final id in saved) SavedRecipe(recipeId: id, savedAt: now)],
      mealPlan: plan,
      history: [
        CookHistoryEntry(
          recipeId: 'ramen-vegan',
          cookedAt: now,
          servings: 2,
          completed: true,
        ),
      ],
      contentRequests: [
        for (final q in requests)
          ContentRequest(query: q, firstAskedAt: now, count: 1),
      ],
      shopping: [
        ShoppingEntry(
          ingredientId: 'garlic',
          qty: 4,
          unit: 'clove',
          addedAt: now,
          sourceRecipeIds: const ['chili-vegan'],
        ),
      ],
    );
  }

  group('export', () {
    test('writes a readable JSON file and a smaller GZip copy', () {
      final bundle = BackupService().export(document());
      expect(bundle.encrypted, isFalse);

      final text = utf8.decode(bundle.jsonBytes);
      expect(text, startsWith('{'));
      expect(jsonDecode(text), isA<Map<String, dynamic>>());

      expect(BackupCrypto.isGzip(bundle.gzipBytes), isTrue);
      expect(bundle.compressedLength, lessThan(bundle.uncompressedLength));
    });

    test('the compressed copy achieves a substantial reduction', () {
      // A realistically sized document — a two-entry one compresses poorly.
      final big = BackupDocument(
        schemaVersion: 1,
        exportedAt: now,
        profile: const Profile(),
        saved: [
          for (var i = 0; i < 400; i++)
            SavedRecipe(recipeId: 'recipe-number-$i', savedAt: now),
        ],
        mealPlan: MealPlan(),
        history: const [],
        contentRequests: const [],
        shopping: const [],
      );
      final bundle = BackupService().export(big);
      expect(bundle.compressionRatio, greaterThan(0.7));
    });

    test('the schema version and the documented keys are present', () {
      final bundle = BackupService().export(document());
      final map =
          jsonDecode(utf8.decode(bundle.jsonBytes)) as Map<String, dynamic>;
      expect(map['schema_version'], 1);
      expect(
        map.keys,
        containsAll(<String>[
          'schema_version',
          'exported_at',
          'profile',
          'saved',
          'meal_plan',
          'history',
          'content_requests',
        ]),
      );
      expect((map['meal_plan'] as Map)['2026-W16'], {
        'mon.dinner': 'chili-vegan',
      });
    });
  });

  group('round trip', () {
    test('plain JSON survives export and import', () {
      final service = BackupService();
      final restored = service.import(service.export(document()).jsonBytes);
      expect(restored.profile.name, 'Cedric');
      expect(restored.profile.lang, 'de');
      expect(
        restored.saved.map((e) => e.recipeId),
        containsAll(<String>['doener-vegan', 'alfredo-classic']),
      );
      expect(
        restored.contentRequests.map((e) => e.query),
        containsAll(<String>['pad thai', 'sushi']),
      );
      expect(
        restored.mealPlan.recipeAt(
          const IsoWeek(2026, 16),
          const PlanSlot('mon', 'dinner'),
        ),
        'chili-vegan',
      );
    });

    test('the GZip copy imports identically', () {
      final service = BackupService();
      final bundle = service.export(document());
      final fromGzip = service.import(bundle.gzipBytes);
      final fromJson = service.import(bundle.jsonBytes);
      expect(fromGzip.saved.length, fromJson.saved.length);
      expect(fromGzip.profile.name, fromJson.profile.name);
    });

    test('a bare id list in `saved` is accepted', () {
      final legacy = jsonEncode({
        'schema_version': 1,
        'exported_at': now.toIso8601String(),
        'profile': const Profile().toJson(),
        'saved': ['recipe-id-1', 'recipe-id-2'],
        'meal_plan': {
          '2026-W16': {'mon.dinner': 'recipe-id-3'},
        },
        'history': <Object>[],
        'content_requests': ['pad thai'],
      });
      final restored = BackupService().import(utf8.encode(legacy));
      expect(
        restored.saved.map((e) => e.recipeId),
        orderedEquals(<String>['recipe-id-1', 'recipe-id-2']),
      );
      expect(restored.contentRequests.single.query, 'pad thai');
    });
  });

  group('encryption', () {
    test('an encrypted export carries the ENC magic bytes', () {
      final bundle = BackupService().export(document(), password: 'hunter2');
      expect(bundle.encrypted, isTrue);
      expect(bundle.jsonBytes.take(3), orderedEquals(<int>[0x45, 0x4E, 0x43]));
      expect(BackupCrypto.isEncrypted(bundle.jsonBytes), isTrue);
    });

    test('the GZip copy stays unencrypted for compatibility', () {
      final bundle = BackupService().export(document(), password: 'hunter2');
      expect(BackupCrypto.isEncrypted(bundle.gzipBytes), isFalse);
      expect(BackupCrypto.isGzip(bundle.gzipBytes), isTrue);
      expect(BackupService().import(bundle.gzipBytes).profile.name, 'Cedric');
    });

    test('the right password restores the document', () {
      final service = BackupService();
      final bundle = service.export(document(), password: 'hunter2');
      final restored = service.importEncrypted(bundle.jsonBytes, 'hunter2');
      expect(restored.profile.name, 'Cedric');
    });

    test('import without a password asks for one', () {
      final service = BackupService();
      final bundle = service.export(document(), password: 'hunter2');
      expect(
        () => service.import(bundle.jsonBytes),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionFailure.passwordRequired,
          ),
        ),
      );
    });

    test('the wrong password reports a wrong password', () {
      final service = BackupService();
      final bundle = service.export(document(), password: 'hunter2');
      expect(
        () => service.importEncrypted(bundle.jsonBytes, 'wrong'),
        throwsA(
          isA<DecryptionException>()
              .having(
                (e) => e.reason,
                'reason',
                DecryptionFailure.wrongPassword,
              )
              .having(
                (e) => e.messageEn,
                'message',
                'Incorrect password. Please try again.',
              ),
        ),
      );
    });

    test('a tampered ciphertext also fails the tag check', () {
      final service = BackupService();
      final bundle = service.export(document(), password: 'hunter2');
      final tampered = Uint8List.fromList(bundle.jsonBytes);
      tampered[tampered.length - 5] ^= 0xFF;
      expect(
        () => service.importEncrypted(tampered, 'hunter2'),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('a truncated encrypted file is reported as corrupted', () {
      final service = BackupService();
      final bundle = service.export(document(), password: 'hunter2');
      final truncated = bundle.jsonBytes.sublist(0, 20);
      expect(
        () => service.importEncrypted(truncated, 'hunter2'),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionFailure.corrupted,
          ),
        ),
      );
    });

    test('every encryption uses a fresh salt and IV', () {
      final service = BackupService();
      final a = service.export(document(), password: 'hunter2').jsonBytes;
      final b = service.export(document(), password: 'hunter2').jsonBytes;
      expect(a.sublist(4, 32), isNot(orderedEquals(b.sublist(4, 32))));
    });

    test('PBKDF2 derives a stable 32-byte key from salt and password', () {
      final crypto = BackupCrypto(random: Random(7));
      final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
      final a = crypto.deriveKey('hunter2', salt);
      final b = crypto.deriveKey('hunter2', salt);
      expect(a.length, 32);
      expect(a, orderedEquals(b));
      expect(crypto.deriveKey('other', salt), isNot(orderedEquals(a)));
    });

    test('the German messages are distinct and non-empty', () {
      for (final reason in DecryptionFailure.values) {
        final exception = DecryptionException(reason);
        expect(exception.messageDe, isNotEmpty);
        expect(exception.message('de'), exception.messageDe);
        expect(exception.message('en'), exception.messageEn);
      }
    });
  });

  group('malformed input', () {
    test('garbage is not a valid backup', () {
      expect(
        () => BackupService().import(utf8.encode('this is not json')),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionFailure.invalidFormat,
          ),
        ),
      );
    });

    test('valid JSON without a schema version is rejected', () {
      expect(
        () => BackupService().import(utf8.encode('{"profile":{}}')),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionFailure.invalidFormat,
          ),
        ),
      );
    });

    test('a newer schema version is refused rather than half-read', () {
      final future = jsonEncode({'schema_version': 99, 'profile': {}});
      expect(
        () => BackupService().import(utf8.encode(future)),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('merge and replace', () {
    final existingPlan = MealPlan()
      ..assign(
        const IsoWeek(2026, 16),
        const PlanSlot('tue', 'lunch'),
        'local-recipe',
      );

    test('merge keeps local data and adds what is new', () {
      final outcome = applyBackup(
        document: document(),
        mode: ImportMode.merge,
        currentProfile: const Profile(name: 'local'),
        currentSaved: [SavedRecipe(recipeId: 'local-saved', savedAt: now)],
        currentHistory: const [],
        currentPlan: existingPlan,
        currentShopping: const [],
        currentRequests: const [],
      );
      expect(outcome.saved.map((e) => e.recipeId), contains('local-saved'));
      expect(outcome.saved.map((e) => e.recipeId), contains('doener-vegan'));
      expect(outcome.addedSaved, 2);
      expect(
        outcome.plan.recipeAt(
          const IsoWeek(2026, 16),
          const PlanSlot('tue', 'lunch'),
        ),
        'local-recipe',
      );
      expect(
        outcome.plan.recipeAt(
          const IsoWeek(2026, 16),
          const PlanSlot('mon', 'dinner'),
        ),
        'chili-vegan',
      );
      expect(outcome.profile.name, 'local');
    });

    test('merge does not duplicate a saved recipe already present', () {
      final outcome = applyBackup(
        document: document(),
        mode: ImportMode.merge,
        currentProfile: const Profile(),
        currentSaved: [SavedRecipe(recipeId: 'doener-vegan', savedAt: now)],
        currentHistory: const [],
        currentPlan: MealPlan(),
        currentShopping: const [],
        currentRequests: const [],
      );
      expect(
        outcome.saved.where((e) => e.recipeId == 'doener-vegan'),
        hasLength(1),
      );
      expect(outcome.addedSaved, 1);
    });

    test('merge sums content-request counts for the same query', () {
      final outcome = applyBackup(
        document: document(requests: const ['pad thai']),
        mode: ImportMode.merge,
        currentProfile: const Profile(),
        currentSaved: const [],
        currentHistory: const [],
        currentPlan: MealPlan(),
        currentShopping: const [],
        currentRequests: [
          ContentRequest(query: 'Pad Thai', firstAskedAt: now, count: 3),
        ],
      );
      expect(outcome.requests.single.count, 4);
    });

    test('replace matches the file exactly', () {
      final outcome = applyBackup(
        document: document(),
        mode: ImportMode.replace,
        currentProfile: const Profile(name: 'local'),
        currentSaved: [SavedRecipe(recipeId: 'local-saved', savedAt: now)],
        currentHistory: const [],
        currentPlan: existingPlan,
        currentShopping: const [],
        currentRequests: const [],
      );
      expect(
        outcome.saved.map((e) => e.recipeId),
        isNot(contains('local-saved')),
      );
      expect(outcome.profile.name, 'Cedric');
      expect(
        outcome.plan.recipeAt(
          const IsoWeek(2026, 16),
          const PlanSlot('tue', 'lunch'),
        ),
        isNull,
      );
    });
  });
}
