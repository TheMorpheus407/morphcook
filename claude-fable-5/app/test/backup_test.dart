import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup/backup_service.dart';
import 'package:morphcook/logic/backup/crypto.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/profile.dart';

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
        SavedRecipe(
            recipeId: 'alfredo-vegan', savedAt: DateTime.utc(2026, 4, 2)),
      ],
      mealPlan: {
        '2026-W16': {'mon.dinner': 'doener-vegan'},
      },
      history: [
        HistoryEntry(
            recipeId: 'doener-vegan', cookedAt: DateTime.utc(2026, 4, 3)),
      ],
      contentRequests: const ['pad thai', 'sushi'],
    );

void main() {
  group('export', () {
    test('produces side-by-side json and gzip with correct schema', () {
      final export = BackupService.export(sampleData(),
          exportedAt: DateTime.utc(2026, 4, 18, 12));
      final jsonMap = json.decode(utf8.decode(export.jsonFile))
          as Map<String, dynamic>;
      expect(jsonMap['schema_version'], 1);
      expect(jsonMap['exported_at'], '2026-04-18T12:00:00.000Z');
      expect(jsonMap['saved'], ['doener-vegan', 'alfredo-vegan']);
      expect(jsonMap['content_requests'], ['pad thai', 'sushi']);
      expect((jsonMap['meal_plan'] as Map)['2026-W16'],
          {'mon.dinner': 'doener-vegan'});

      // GZip file carries magic bytes and decodes to the same JSON.
      expect(hasGzipMagic(export.gzipFile), isTrue);
      final gunzipped =
          json.decode(utf8.decode(gzip.decode(export.gzipFile)));
      expect(gunzipped, jsonMap);
    });

    test('gzip compresses substantially', () {
      // Pad with repetitive data to make compression observable.
      final data = BackupData(
        profile: const Profile(name: 'x'),
        saved: [
          for (var i = 0; i < 300; i++)
            SavedRecipe(
                recipeId: 'recipe-$i', savedAt: DateTime.utc(2026, 1, 1)),
        ],
        mealPlan: const {},
        history: const [],
      );
      final export = BackupService.export(data);
      expect(export.gzipFile.length,
          lessThan(export.jsonFile.length * 0.35));
    });

    test('password encrypts the json file but never the gzip file', () {
      final export =
          BackupService.export(sampleData(), password: 'hunter2');
      expect(hasEncryptionMagic(export.jsonFile), isTrue);
      expect(hasGzipMagic(export.gzipFile), isTrue);
      expect(() => utf8.decode(export.jsonFile), throwsFormatException);
    });
  });

  group('import auto-detection', () {
    test('plain json roundtrip', () {
      final export = BackupService.export(sampleData());
      final imported = BackupService.import(export.jsonFile);
      expect(imported.profile.name, 'cedric');
      expect(imported.profile.avoidFlags, {'vegan'});
      expect(imported.saved.map((s) => s.recipeId),
          ['doener-vegan', 'alfredo-vegan']);
      expect(imported.mealPlan['2026-W16']?['mon.dinner'], 'doener-vegan');
      expect(imported.history, hasLength(1));
      expect(imported.contentRequests, ['pad thai', 'sushi']);
    });

    test('gzip roundtrip', () {
      final export = BackupService.export(sampleData());
      final imported = BackupService.import(export.gzipFile);
      expect(imported.profile.name, 'cedric');
    });

    test('encrypted roundtrip with correct password', () {
      final export =
          BackupService.export(sampleData(), password: 'hunter2');
      final imported =
          BackupService.import(export.jsonFile, password: 'hunter2');
      expect(imported.profile.name, 'cedric');
      expect(imported.profile.calorieTarget, 600);
    });

    test('encrypted import without password asks for one', () {
      final export =
          BackupService.export(sampleData(), password: 'hunter2');
      expect(BackupService.isEncrypted(export.jsonFile), isTrue);
      expect(
          () => BackupService.import(export.jsonFile),
          throwsA(isA<DecryptionException>().having(
              (e) => e.reason,
              'reason',
              DecryptionFailure.needsPassword)));
    });

    test('wrong password yields the actionable message', () {
      final export =
          BackupService.export(sampleData(), password: 'hunter2');
      expect(
          () => BackupService.import(export.jsonFile, password: 'nope'),
          throwsA(isA<DecryptionException>().having((e) => e.message,
              'message', 'Incorrect password. Please try again.')));
    });

    test('corrupted encrypted data is reported as corrupted or wrong key',
        () {
      final export =
          BackupService.export(sampleData(), password: 'hunter2');
      final corrupted = List<int>.from(export.jsonFile);
      corrupted[corrupted.length - 1] ^= 0xFF;
      expect(
          () => BackupService.import(corrupted, password: 'hunter2'),
          throwsA(isA<DecryptionException>()));
      final truncated = export.jsonFile.sublist(0, 10);
      expect(
          () => BackupService.import(truncated, password: 'hunter2'),
          throwsA(isA<DecryptionException>().having((e) => e.message,
              'message', 'Backup file is corrupted and cannot be restored.')));
    });

    test('garbage input is not a valid backup', () {
      expect(
          () => BackupService.import(utf8.encode('{"hello": "world"}')),
          throwsA(isA<DecryptionException>().having((e) => e.message,
              'message', 'This file is not a valid MorphCook backup.')));
      expect(
          () => BackupService.import(const [0x00, 0x01, 0x02]),
          throwsA(isA<DecryptionException>()));
    });

    test('unsupported schema_version is rejected', () {
      final map = sampleData().toJson(DateTime.utc(2026, 1, 1));
      map['schema_version'] = 99;
      expect(
          () => BackupService.import(utf8.encode(json.encode(map))),
          throwsA(isA<DecryptionException>()));
    });

    test('each encryption uses a fresh salt and IV', () {
      final a = BackupService.export(sampleData(), password: 'p').jsonFile;
      final b = BackupService.export(sampleData(), password: 'p').jsonFile;
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
              recipeId: 'doener-vegan', savedAt: DateTime.utc(2026, 5, 1)),
          SavedRecipe(
              recipeId: 'ramen-vegan', savedAt: DateTime.utc(2026, 5, 2)),
        ],
        mealPlan: {
          '2026-W16': {'mon.dinner': 'ramen-vegan'},
          '2026-W17': {'tue.lunch': 'falafel-baked'},
        },
        history: [
          HistoryEntry(
              recipeId: 'ramen-vegan', cookedAt: DateTime.utc(2026, 5, 3)),
        ],
        contentRequests: const ['sushi', 'pho'],
      );
      final merged = BackupService.merge(current, incoming);
      expect(merged.profile.name, 'other');
      expect(merged.saved.map((s) => s.recipeId).toSet(),
          {'doener-vegan', 'alfredo-vegan', 'ramen-vegan'});
      expect(merged.mealPlan['2026-W16']?['mon.dinner'], 'ramen-vegan');
      expect(merged.mealPlan['2026-W17']?['tue.lunch'], 'falafel-baked');
      expect(merged.history, hasLength(2));
      expect(merged.contentRequests.toSet(),
          {'pad thai', 'sushi', 'pho'});
    });
  });
}
