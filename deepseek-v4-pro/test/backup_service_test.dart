import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup_service.dart';
import 'package:morphcook/models/profile.dart';

void main() {
  final payload = BackupService.buildBackup(
    profile: const Profile(
      name: 'Ada',
      lang: 'de',
      avoidFlags: {'dairy'},
      avoidIngredients: {'produce.cilantro'},
      requiredAttributes: {'halal-compatible'},
      maxTimeMinutes: 45,
      calorieTarget: 550,
      preferredEffort: 'easy',
    ),
    saved: ['doener.vegan', 'pad-thai.classic'],
    mealPlan: {
      '2026-W33': {'mon.dinner': 'doener.vegan'},
    },
    history: [
      {'recipe_id': 'doener.vegan', 'cooked_at': '2026-08-10T18:00:00.000Z'},
    ],
    contentRequests: ['pad thai', 'sushi'],
  );

  group('export formats', () {
    test('plain json roundtrip', () {
      final json = BackupService.encodeBackupJson(payload);
      final bytes = BackupService.encodeJson(json);
      expect(BackupService.detect(bytes), BackupFormat.json);
      expect(BackupService.decode(bytes), json);
      expect(BackupService.parse(BackupService.decode(bytes)), isNotNull);
    });

    test('gzip roundtrip, with magic bytes 0x1f 0x8b', () {
      final json = BackupService.encodeBackupJson(payload);
      final gz = BackupService.encodeGz(json);
      expect(gz[0], 0x1f);
      expect(gz[1], 0x8b);
      expect(BackupService.detect(gz), BackupFormat.gzip);
      expect(BackupService.decode(gz), json);
      expect(BackupService.parse(BackupService.decode(gz))['profile'], isNotNull);
    });

    test('gzip compresses json by 70%+ on this payload', () {
      // Small payloads compress less; build a fatter one.
      final fat = BackupService.buildBackup(
        profile: Profile.fromJson(payload['profile'] as Map<String, dynamic>),
        saved: List.generate(200, (i) => 'recipe-id-$i-with-a-longer-name'),
        mealPlan: {
          '2026-W33': {
            for (var d = 0; d < 7; d++)
              for (final m in ['breakfast', 'lunch', 'dinner'])
                '${['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][d]}.$m':
                    'recipe-id-${d * 3}',
          },
        },
        history: const [],
      );
      final fatJson = BackupService.encodeBackupJson(fat);
      final fatGz = BackupService.encodeGz(fatJson);
      final ratio = 1 - (fatGz.length / utf8.encode(fatJson).length);
      expect(ratio, greaterThan(0.7));
    });

    test('encrypted json carries ENC magic bytes and is not readable', () {
      final json = BackupService.encodeBackupJson(payload);
      final enc = BackupService.encodeJson(json, password: 'hunter2');
      expect(enc[0], 0x45);
      expect(enc[1], 0x4E);
      expect(enc[2], 0x43);
      expect(BackupService.detect(enc), BackupFormat.encrypted);
      expect(() => BackupService.decode(enc), throwsA(isA<DecryptionException>()));
    });

    test('encryption is randomized: same input, different output', () {
      final json = BackupService.encodeBackupJson(payload);
      final a = BackupService.encodeJson(json, password: 'pw');
      final b = BackupService.encodeJson(json, password: 'pw');
      expect(a, isNot(equals(b)));
    });
  });

  group('encrypted roundtrip', () {
    test('decrypts with the right password', () {
      final json = BackupService.encodeBackupJson(payload);
      final enc = BackupService.encodeJson(json, password: 's3cret');
      final decoded = BackupService.decode(enc, password: 's3cret');
      expect(decoded, json);
      final parsed = BackupService.parse(decoded);
      expect(parsed['profile']['name'], 'Ada');
    });

    test('wrong password → wrongPassword reason with actionable message', () {
      final json = BackupService.encodeBackupJson(payload);
      final enc = BackupService.encodeJson(json, password: 'right');
      try {
        BackupService.decode(enc, password: 'wrong');
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'wrongPassword');
        expect(e.message('en'), 'Incorrect password. Please try again.');
        expect(e.message('de'), 'Falsches Passwort. Bitte versuche es erneut.');
      }
    });

    test('no password on encrypted file → needsPassword', () {
      final json = BackupService.encodeBackupJson(payload);
      final enc = BackupService.encodeJson(json, password: 'right');
      try {
        BackupService.decode(enc);
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'needsPassword');
      }
    });

    test('corrupted ciphertext → corrupted reason', () {
      final json = BackupService.encodeBackupJson(payload);
      final enc = BackupService.encodeJson(json, password: 'right');
      final mangled = Uint8List.fromList(enc)..[30] = enc[30] ^ 0xFF;
      try {
        BackupService.decode(mangled, password: 'right');
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'wrongPassword');
      }
    });

    test('truncated encrypted blob → corrupted', () {
      final json = BackupService.encodeBackupJson(payload);
      final enc = BackupService.encodeJson(json, password: 'right');
      final short = Uint8List.sublistView(enc, 0, 10);
      try {
        BackupService.decode(short, password: 'right');
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'corrupted');
      }
    });
  });

  group('import detection & validation', () {
    test('invalid garbage → invalid format', () {
      final bytes = Uint8List.fromList(utf8.encode('this is not json'));
      expect(BackupService.detect(bytes), BackupFormat.invalid);
      try {
        BackupService.decode(bytes);
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'invalid');
        expect(
          e.message('en'),
          'This file is not a valid MorphCook backup.',
        );
      }
    });

    test('valid json with wrong schema version → invalid', () {
      final bad = jsonEncode({'schema_version': 99, 'profile': {}});
      final bytes = BackupService.encodeJson(bad);
      expect(BackupService.detect(bytes), BackupFormat.json);
      try {
        BackupService.parse(BackupService.decode(bytes));
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'invalid');
      }
    });

    test('valid json without profile → invalid', () {
      final bad = jsonEncode({'schema_version': 1});
      try {
        BackupService.parse(bad);
        fail('expected DecryptionException');
      } on DecryptionException catch (e) {
        expect(e.reason, 'invalid');
      }
    });

    test('schema_version 1 passes', () {
      final json = BackupService.encodeBackupJson(payload);
      expect(BackupService.parse(json)['schema_version'], 1);
    });
  });

  group('backup payload shape', () {
    test('matches the documented schema', () {
      final json = BackupService.encodeBackupJson(payload);
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      expect(parsed.keys.toSet(), {
        'schema_version',
        'exported_at',
        'profile',
        'saved',
        'meal_plan',
        'history',
        'content_requests',
      });
      expect(parsed['schema_version'], 1);
      expect((parsed['saved'] as List).length, 2);
      expect(parsed['content_requests'], ['pad thai', 'sushi']);
    });
  });
}
