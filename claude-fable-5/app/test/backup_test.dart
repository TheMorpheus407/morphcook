import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup/backup_service.dart';
import 'package:morphcook/logic/backup/crypto.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe_image.dart';
import 'package:pointycastle/export.dart';

import 'helpers.dart';

PersonalRecipe personalBackupRecipe({
  String id = 'personal-0123456789abcdef0123456789abcdef',
  String title = 'Family noodles',
  DateTime? updatedAt,
  List<PersonalRecipeStep>? steps,
}) => PersonalRecipe(
  id: id,
  title: title,
  description: 'Handwritten at home.',
  timeMinutes: 20,
  servings: 2,
  ingredients: [PersonalRecipeIngredient(name: 'Noodles', qty: 250, unit: 'g')],
  steps: steps ?? [PersonalRecipeStep(text: 'Boil and toss.', timerMinutes: 8)],
  createdAt: DateTime.utc(2026, 4, 1),
  updatedAt: updatedAt ?? DateTime.utc(2026, 4, 2),
);

BackupData sampleData() => BackupData(
  profile: const Profile(
    name: 'cedric',
    lang: 'de',
    avoidFlags: {'vegan'},
    avoidIngredients: {'cilantro'},
    calorieTarget: 600,
  ),
  saved: [
    SavedRecipe(recipeId: 'doener-vegan', savedAt: DateTime.utc(2026, 4, 1)),
    SavedRecipe(recipeId: 'alfredo-vegan', savedAt: DateTime.utc(2026, 4, 2)),
  ],
  mealPlan: {
    '2026-W16': {'mon.dinner': 'doener-vegan'},
  },
  history: [
    HistoryEntry(recipeId: 'doener-vegan', cookedAt: DateTime.utc(2026, 4, 3)),
  ],
  contentRequests: const ['pad thai', 'sushi'],
  personalRecipes: [personalBackupRecipe()],
  recipeImages: [
    RecipeImage(
      recipeId: 'doener-vegan',
      bytes: testPngBytes(),
      updatedAt: DateTime.utc(2026, 4, 4),
    ),
  ],
);

Uint8List legacyEncryptedBackup(String plaintext, String password) {
  final salt = Uint8List.fromList(List<int>.generate(16, (i) => i));
  final iv = Uint8List.fromList(List<int>.generate(12, (i) => i + 16));
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, 10000, 32));
  final key = derivator.process(Uint8List.fromList(utf8.encode(password)));
  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final ciphertext = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
  return (BytesBuilder()
        ..add(encryptionMagic)
        ..addByte(1)
        ..add(salt)
        ..add(iv)
        ..add(ciphertext))
      .takeBytes();
}

void main() {
  group('export', () {
    test('produces side-by-side json and gzip with correct schema', () {
      final export = BackupService.export(
        sampleData(),
        exportedAt: DateTime.utc(2026, 4, 18, 12),
      );
      final jsonMap =
          json.decode(utf8.decode(export.jsonFile)) as Map<String, dynamic>;
      expect(jsonMap['schema_version'], 2);
      expect(jsonMap['exported_at'], '2026-04-18T12:00:00.000Z');
      expect(jsonMap['saved'], ['doener-vegan', 'alfredo-vegan']);
      expect(jsonMap['content_requests'], ['pad thai', 'sushi']);
      expect((jsonMap['meal_plan'] as Map)['2026-W16'], {
        'mon.dinner': 'doener-vegan',
      });
      expect(
        (jsonMap['personal_recipes'] as List).single['title'],
        'Family noodles',
      );
      expect(
        (jsonMap['recipe_images'] as List).single['mime_type'],
        'image/png',
      );

      // GZip file carries magic bytes and decodes to the same JSON.
      expect(hasGzipMagic(export.gzipFile!), isTrue);
      final gunzipped = json.decode(utf8.decode(gzip.decode(export.gzipFile!)));
      expect(gunzipped, jsonMap);
    });

    test('gzip compresses substantially', () {
      // Pad with repetitive data to make compression observable.
      final data = BackupData(
        profile: const Profile(name: 'x'),
        saved: [
          for (var i = 0; i < 300; i++)
            SavedRecipe(
              recipeId: 'recipe-$i',
              savedAt: DateTime.utc(2026, 1, 1),
            ),
        ],
        mealPlan: const {},
        history: const [],
      );
      final export = BackupService.export(data);
      expect(export.gzipFile!.length, lessThan(export.jsonFile.length * 0.35));
    });

    test('password encrypts the json file but never the gzip file', () {
      final export = BackupService.export(sampleData(), password: 'hunter2');
      expect(hasEncryptionMagic(export.jsonFile), isTrue);
      expect(hasGzipMagic(export.gzipFile!), isTrue);
      expect(() => utf8.decode(export.jsonFile), throwsFormatException);
    });

    test('encrypted sharing can omit every plaintext sidecar', () {
      final exportedAt = DateTime.utc(2026, 4, 18);
      final plain = BackupService.export(
        sampleData(),
        exportedAt: exportedAt,
        includePlainGzip: false,
      );
      final export = BackupService.export(
        sampleData(),
        password: 'hunter2',
        exportedAt: exportedAt,
        includePlainGzip: false,
      );
      expect(hasEncryptionMagic(export.jsonFile), isTrue);
      expect(
        export.jsonFile.length,
        plain.jsonFile.length + encryptionEnvelopeOverheadBytes,
      );
      expect(export.gzipFile, isNull);
    });

    test('oversized authored text is rejected before JSON materialization', () {
      final longStep = List<String>.filled(maxPersonalStepLength, 'x').join();
      final recipes = [
        for (var i = 0; i < 30; i++)
          personalBackupRecipe(
            id: 'personal-${i.toRadixString(16).padLeft(32, '0')}',
            title: 'Large recipe $i',
            steps: [
              for (var step = 0; step < maxPersonalRecipeSteps; step++)
                PersonalRecipeStep(text: longStep),
            ],
          ),
      ];
      final data = BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        personalRecipes: recipes,
      );
      expect(personalRecipesFitBackup(recipes), isFalse);
      expect(
        () => BackupService.export(data),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.reason,
            'reason',
            DecryptionFailure.tooLarge,
          ),
        ),
      );
      final encoded = utf8.encode(
        json.encode(data.toJson(DateTime.utc(2026, 4, 18))),
      );
      expect(encoded.length, lessThan(maxBackupDecodedBytes));
      expect(
        () => BackupService.import(encoded),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.reason,
            'reason',
            DecryptionFailure.tooLarge,
          ),
        ),
      );
    });
  });

  group('import auto-detection', () {
    test('plain json roundtrip', () {
      final export = BackupService.export(sampleData());
      final imported = BackupService.import(export.jsonFile);
      expect(imported.profile.name, 'cedric');
      expect(imported.profile.avoidFlags, {'vegan'});
      expect(imported.saved.map((s) => s.recipeId), [
        'doener-vegan',
        'alfredo-vegan',
      ]);
      expect(imported.mealPlan['2026-W16']?['mon.dinner'], 'doener-vegan');
      expect(imported.history, hasLength(1));
      expect(imported.contentRequests, ['pad thai', 'sushi']);
      expect(imported.personalRecipes.single.title, 'Family noodles');
      expect(imported.personalRecipes.single.steps.single.timerMinutes, 8);
      expect(imported.recipeImages.single.bytes, orderedEquals(testPngBytes()));
    });

    test('gzip roundtrip', () {
      final export = BackupService.export(sampleData());
      final imported = BackupService.import(export.gzipFile!);
      expect(imported.profile.name, 'cedric');
    });

    test('encrypted roundtrip with correct password', () {
      final export = BackupService.export(sampleData(), password: 'hunter2');
      final imported = BackupService.import(
        export.jsonFile,
        password: 'hunter2',
      );
      expect(imported.profile.name, 'cedric');
      expect(imported.profile.calorieTarget, 600);
      expect(imported.recipeImages.single.bytes, orderedEquals(testPngBytes()));
    });

    test('legacy version-1 encrypted backups remain importable', () {
      final jsonText = json.encode(
        sampleData().toJson(DateTime.utc(2026, 4, 18)),
      );
      final legacy = legacyEncryptedBackup(jsonText, 'old-password');
      expect(legacy[3], 1);

      final imported = BackupService.import(legacy, password: 'old-password');
      expect(imported.profile.name, 'cedric');
      expect(imported.personalRecipes.single.title, 'Family noodles');
    });

    test('encrypted import without password asks for one', () {
      final export = BackupService.export(sampleData(), password: 'hunter2');
      expect(BackupService.isEncrypted(export.jsonFile), isTrue);
      expect(
        () => BackupService.import(export.jsonFile),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionFailure.needsPassword,
          ),
        ),
      );
    });

    test('wrong password yields the actionable message', () {
      final export = BackupService.export(sampleData(), password: 'hunter2');
      expect(
        () => BackupService.import(export.jsonFile, password: 'nope'),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.message,
            'message',
            'Incorrect password. Please try again.',
          ),
        ),
      );
    });

    test('corrupted encrypted data is reported as corrupted or wrong key', () {
      final export = BackupService.export(sampleData(), password: 'hunter2');
      final corrupted = List<int>.from(export.jsonFile);
      corrupted[corrupted.length - 1] ^= 0xFF;
      expect(
        () => BackupService.import(corrupted, password: 'hunter2'),
        throwsA(isA<DecryptionException>()),
      );
      final truncated = export.jsonFile.sublist(0, 10);
      expect(
        () => BackupService.import(truncated, password: 'hunter2'),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.message,
            'message',
            'Backup file is corrupted and cannot be restored.',
          ),
        ),
      );
    });

    test('garbage input is not a valid backup', () {
      expect(
        () => BackupService.import(utf8.encode('{"hello": "world"}')),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.message,
            'message',
            'This file is not a valid MorphCook backup.',
          ),
        ),
      );
      expect(
        () => BackupService.import(const [0x00, 0x01, 0x02]),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('oversized input and gzip expansion are rejected safely', () {
      expect(
        () => BackupService.import(Uint8List(maxBackupFileBytes + 1)),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.reason,
            'reason',
            DecryptionFailure.tooLarge,
          ),
        ),
      );

      final expanded = Uint8List(maxBackupDecodedBytes + 1);
      final compressed = gzip.encode(expanded);
      expect(
        () => BackupService.import(compressed),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.reason,
            'reason',
            DecryptionFailure.tooLarge,
          ),
        ),
      );
    });

    test('unsupported schema_version is rejected', () {
      final map = sampleData().toJson(DateTime.utc(2026, 1, 1));
      map['schema_version'] = 99;
      expect(
        () => BackupService.import(utf8.encode(json.encode(map))),
        throwsA(isA<DecryptionException>()),
      );
    });

    test(
      'schema v1 remains importable with empty personal recipes and images',
      () {
        final map = sampleData().toJson(DateTime.utc(2026, 1, 1));
        map['schema_version'] = 1;
        map.remove('personal_recipes');
        map.remove('recipe_images');
        final imported = BackupService.import(utf8.encode(json.encode(map)));
        expect(imported.profile.name, 'cedric');
        expect(imported.personalRecipes, isEmpty);
        expect(imported.recipeImages, isEmpty);
      },
    );

    test('malformed personal recipe is reported as an invalid backup', () {
      final map = sampleData().toJson(DateTime.utc(2026, 1, 1));
      (map['personal_recipes'] as List).single['title'] = '';
      expect(
        () => BackupService.import(utf8.encode(json.encode(map))),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('duplicate personal recipe ids are rejected', () {
      final map = sampleData().toJson(DateTime.utc(2026, 1, 1));
      final original = (map['personal_recipes'] as List).single;
      map['personal_recipes'] = [original, Map<String, dynamic>.from(original)];
      expect(
        () => BackupService.import(utf8.encode(json.encode(map))),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('malformed image data is reported as an invalid backup', () {
      final map = sampleData().toJson(DateTime.utc(2026, 1, 1));
      (map['recipe_images'] as List).single['data_base64'] = 'not base64!';
      expect(
        () => BackupService.import(utf8.encode(json.encode(map))),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('each encryption uses a fresh salt and IV', () {
      final a = BackupService.export(sampleData(), password: 'p').jsonFile;
      final b = BackupService.export(sampleData(), password: 'p').jsonFile;
      expect(a[3], 2);
      expect(a.sublist(4, 32), isNot(b.sublist(4, 32)));
    });
  });

  group('merge', () {
    test('union of saved & history, incoming wins profile and slots', () {
      final current = sampleData();
      final incoming = BackupData(
        profile: const Profile(name: 'other', lang: 'en'),
        saved: [
          SavedRecipe(
            recipeId: 'doener-vegan',
            savedAt: DateTime.utc(2026, 5, 1),
          ),
          SavedRecipe(
            recipeId: 'ramen-vegan',
            savedAt: DateTime.utc(2026, 5, 2),
          ),
        ],
        mealPlan: {
          '2026-W16': {'mon.dinner': 'ramen-vegan'},
          '2026-W17': {'tue.lunch': 'falafel-baked'},
        },
        history: [
          HistoryEntry(
            recipeId: 'ramen-vegan',
            cookedAt: DateTime.utc(2026, 5, 3),
          ),
        ],
        contentRequests: const ['sushi', 'pho'],
      );
      final merged = BackupService.merge(current, incoming);
      expect(merged.profile.name, 'other');
      expect(merged.saved.map((s) => s.recipeId).toSet(), {
        'doener-vegan',
        'alfredo-vegan',
        'ramen-vegan',
      });
      expect(merged.mealPlan['2026-W16']?['mon.dinner'], 'ramen-vegan');
      expect(merged.mealPlan['2026-W17']?['tue.lunch'], 'falafel-baked');
      expect(merged.history, hasLength(2));
      expect(merged.contentRequests.toSet(), {'pad thai', 'sushi', 'pho'});
    });

    test('personal recipe merge keeps the newest edit for each id', () {
      final current = sampleData();
      final incoming = BackupData(
        profile: const Profile(name: 'incoming'),
        saved: const [],
        mealPlan: const {},
        history: const [],
        personalRecipes: [
          personalBackupRecipe(
            title: 'New family noodles',
            updatedAt: DateTime.utc(2026, 5, 1),
          ),
          personalBackupRecipe(
            id: 'personal-fedcba9876543210fedcba9876543210',
            title: 'Second recipe',
          ),
        ],
      );
      final merged = BackupService.merge(current, incoming);
      expect(merged.personalRecipes, hasLength(2));
      expect(
        merged.personalRecipes
            .singleWhere((r) => r.id == personalBackupRecipe().id)
            .title,
        'New family noodles',
      );
    });

    test('recipe image merge keeps the newest bytes for each recipe', () {
      final current = sampleData();
      final replacement = [...testPngBytes(), 0];
      final incoming = BackupData(
        profile: const Profile(name: 'incoming'),
        saved: const [],
        mealPlan: const {},
        history: const [],
        recipeImages: [
          RecipeImage(
            recipeId: 'doener-vegan',
            bytes: replacement,
            updatedAt: DateTime.utc(2026, 5, 1),
          ),
        ],
      );
      final merged = BackupService.merge(current, incoming);
      expect(merged.recipeImages.single.bytes, orderedEquals(replacement));
    });

    test('recipe image merge rejects a collection beyond the safe limit', () {
      RecipeImage image(int index) => RecipeImage(
        recipeId: 'recipe-$index',
        bytes: testPngBytes(),
        updatedAt: DateTime.utc(2026, 5, 1),
      );
      final current = BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        recipeImages: [for (var i = 0; i < 100; i++) image(i)],
      );
      final incoming = BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        recipeImages: [image(100)],
      );
      expect(
        () => BackupService.merge(current, incoming),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('personal recipe merge enforces the same limit as import', () {
      PersonalRecipe recipe(int index) => personalBackupRecipe(
        id: 'personal-${index.toRadixString(16).padLeft(32, '0')}',
        title: 'Recipe $index',
      );
      final current = BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        personalRecipes: [for (var i = 0; i < 300; i++) recipe(i)],
      );
      final incoming = BackupData(
        profile: const Profile(),
        saved: const [],
        mealPlan: const {},
        history: const [],
        personalRecipes: [
          for (var i = 300; i <= maxPersonalRecipes; i++) recipe(i),
        ],
      );
      expect(
        () => BackupService.merge(current, incoming),
        throwsA(isA<DecryptionException>()),
      );
    });
  });
}
