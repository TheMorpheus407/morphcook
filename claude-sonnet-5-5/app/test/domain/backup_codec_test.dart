import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/domain/backup/backup_codec.dart';
import 'package:morphcook/domain/backup/backup_models.dart';
import 'package:morphcook/domain/shopping/insights.dart';

BackupData sampleData({int history = 3}) {
  return BackupData(
    exportedAt: DateTime.utc(2026, 4, 18, 12),
    profile: const <String, dynamic>{
      'name': 'Sam',
      'lang': 'de',
      'avoid_flags': ['dairy', 'nuts'],
      'avoid_ingredients': ['apples'],
      'max_time_minutes': 45,
    },
    saved: const ['recipe-id-1', 'recipe-id-2'],
    savedAt: {'recipe-id-1': DateTime.utc(2026, 4, 1), 'recipe-id-2': DateTime.utc(2026, 4, 2)},
    mealPlan: const {
      '2026-W16': {'mon.dinner': 'recipe-id-3'},
    },
    history: [
      for (var i = 0; i < history; i++)
        HistoryEntry(
          recipeId: 'recipe-id-${i % 5}',
          cookedAt: DateTime.utc(2026, 3, 1).add(Duration(days: i)),
          servings: 2,
        ),
    ],
    contentRequests: const ['pad thai', 'sushi'],
    shopping: const {
      'checked': ['garlic'],
    },
    shoppingHistory: [ShoppingEvent(ingredientId: 'garlic', at: DateTime.utc(2026, 4, 2), recipeId: 'recipe-id-1')],
    settings: const {'visualAlertEnabled': true, 'quickNextTapEnabled': false},
  );
}

void expectSame(BackupData a, BackupData b) {
  expect(a.schemaVersion, b.schemaVersion);
  expect(a.exportedAt.toUtc(), b.exportedAt.toUtc());
  expect(a.profile, b.profile);
  expect(a.saved, b.saved);
  expect(a.mealPlan, b.mealPlan);
  expect(a.history, b.history);
  expect(a.contentRequests, b.contentRequests);
  expect(a.shopping, b.shopping);
  expect(a.settings, b.settings);
  expect(a.shoppingHistory.map((e) => e.ingredientId), b.shoppingHistory.map((e) => e.ingredientId));
}

Future<void> expectFailure(Future<Object?> Function() body, DecryptionFailure reason, String message) async {
  try {
    await body();
    fail('expected DecryptionException($reason)');
  } on DecryptionException catch (e) {
    expect(e.reason, reason);
    expect(e.message, message);
  }
}

void main() {
  final codec = BackupCodec(random: Random(7));

  group('file names', () {
    test('the two files are morphcook-backup.json and morphcook-backup.json.gz', () {
      expect(BackupCodec.jsonFileName, 'morphcook-backup.json');
      expect(BackupCodec.gzipFileName, 'morphcook-backup.json.gz');
    });
  });

  group('plain JSON', () {
    test('is human readable and follows the documented format', () {
      final text = utf8.decode(codec.encodeJson(sampleData()));
      expect(text, contains('\n  "schema_version": 1'), reason: 'pretty printed');
      final json = jsonDecode(text) as Map<String, dynamic>;
      expect(json['schema_version'], 1);
      expect(json['exported_at'], '2026-04-18T12:00:00.000Z');
      expect(json['profile'], isA<Map<String, dynamic>>());
      expect(json['saved'], ['recipe-id-1', 'recipe-id-2']);
      expect(json['meal_plan'], {
        '2026-W16': {'mon.dinner': 'recipe-id-3'},
      });
      expect(json['history'], isA<List<Object?>>());
      expect(json['content_requests'], ['pad thai', 'sushi']);
    });

    test('round trips', () {
      final data = sampleData();
      expectSame(codec.decode(codec.encodeJson(data)), data);
    });

    test('content_requests is optional', () {
      final json = jsonDecode(utf8.decode(codec.encodeJson(sampleData()))) as Map<String, dynamic>;
      json.remove('content_requests');
      final back = codec.decode(utf8.encode(jsonEncode(json)));
      expect(back.contentRequests, isEmpty);
    });

    test('a minimal backup with only the required fields reads fine', () {
      final back = codec.decode(utf8.encode('{"schema_version":1,"profile":{"name":"A"}}'));
      expect(back.saved, isEmpty);
      expect(back.mealPlan, isEmpty);
      expect(back.history, isEmpty);
      expect(back.profile['name'], 'A');
    });

    test('never contains the bundled corpus', () {
      final text = utf8.decode(codec.encodeJson(sampleData()));
      expect(text, isNot(contains('"ingredient_ids"')));
      expect(text, isNot(contains('"steps"')));
      expect(text, isNot(contains('calories_per_serving')));
    });
  });

  group('GZip', () {
    test('starts with the GZip magic bytes 0x1f 0x8b', () {
      final bytes = codec.encodeGzip(sampleData());
      expect(bytes.take(2), [0x1f, 0x8b]);
      expect(BackupCodec.isGzip(bytes), isTrue);
      expect(BackupCodec.isEncrypted(bytes), isFalse);
    });

    test('is detected on import and round trips', () {
      final data = sampleData();
      expectSame(codec.decode(codec.encodeGzip(data)), data);
    });

    test('compresses typical data by 70 to 90 percent', () {
      final data = sampleData(history: 400);
      final plain = codec.encodeJson(data).length;
      final packed = codec.encodeGzip(data).length;
      final saved = 1 - packed / plain;
      expect(saved, greaterThan(0.7));
    });

    test('is never encrypted, so it stays compatible', () {
      final bytes = codec.encodeGzip(sampleData());
      expect(gzip.decode(bytes), isNotEmpty);
    });

    test('a damaged GZip file is reported as corrupted', () async {
      final bytes = codec.encodeGzip(sampleData()).toList();
      final broken = Uint8List.fromList([...bytes.take(12), ...List<int>.filled(20, 9)]);
      await expectFailure(
        () async => codec.decode(broken),
        DecryptionFailure.corrupted,
        DecryptionException.corruptedMessage,
      );
    });
  });

  group('encrypted JSON', () {
    test('starts with the magic bytes [0x45, 0x4E, 0x43] (ASCII "ENC")', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'correct horse');
      expect(bytes.take(3), [0x45, 0x4E, 0x43]);
      expect(ascii.decode(bytes.take(3).toList()), 'ENC');
      expect(BackupCodec.isEncrypted(bytes), isTrue);
    });

    test('round trips with the right password', () async {
      final data = sampleData();
      final bytes = await codec.encodeEncrypted(data, 'correct horse');
      expectSame(await codec.decodeEncrypted(bytes, 'correct horse'), data);
    });

    test('does not leak the content', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'pw');
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('recipe-id-1')));
      expect(utf8.decode(bytes, allowMalformed: true), isNot(contains('Sam')));
    });

    test('every export uses a fresh salt and IV', () async {
      final a = await codec.encodeEncrypted(sampleData(), 'pw');
      final b = await codec.encodeEncrypted(sampleData(), 'pw');
      List<int> salt(Uint8List x) => x.sublist(4, 20);
      List<int> iv(Uint8List x) => x.sublist(20, 32);
      expect(salt(a), isNot(salt(b)));
      expect(iv(a), isNot(iv(b)));
      expect(a, isNot(b));
    });

    test('follows the documented container: AES-256-GCM, PBKDF2 with 10,000 SHA-256 iterations', () async {
      final data = sampleData();
      final bytes = await codec.encodeEncrypted(data, 'open sesame');
      expect(bytes[3], BackupCodec.containerVersion);
      final salt = bytes.sublist(4, 20);
      final iv = bytes.sublist(20, 32);
      final cipherText = bytes.sublist(36, bytes.length - 16);
      final tag = bytes.sublist(bytes.length - 16);

      // An independent decryption with the parameters from the specification.
      final key = await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 10000,
        bits: 256,
      ).deriveKeyFromPassword(password: 'open sesame', nonce: salt);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: iv, mac: Mac(tag)),
        secretKey: key,
      );
      final json = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      expect(json['schema_version'], 1);
      expect(json['saved'], ['recipe-id-1', 'recipe-id-2']);
      expect(BackupCodec.pbkdf2Iterations, 10000);
    });

    test('import without a password asks for one', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'pw');
      await expectFailure(
        () async => codec.decode(bytes),
        DecryptionFailure.passwordRequired,
        DecryptionException.passwordRequiredMessage,
      );
    });

    test('a wrong password says "Incorrect password. Please try again."', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'right');
      await expectFailure(
        () => codec.decodeEncrypted(bytes, 'wrong'),
        DecryptionFailure.wrongPassword,
        'Incorrect password. Please try again.',
      );
    });

    test('damaged data says "Backup file is corrupted and cannot be restored."', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'pw');
      final broken = Uint8List.fromList(bytes)..[bytes.length ~/ 2] ^= 0xff;
      await expectFailure(
        () => codec.decodeEncrypted(broken, 'pw'),
        DecryptionFailure.corrupted,
        'Backup file is corrupted and cannot be restored.',
      );
    });

    test('a damaged authentication tag is corruption too', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'pw');
      final broken = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 0x01;
      await expectFailure(
        () => codec.decodeEncrypted(broken, 'pw'),
        DecryptionFailure.corrupted,
        DecryptionException.corruptedMessage,
      );
    });

    test('a truncated file is corruption', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'pw');
      await expectFailure(
        () => codec.decodeEncrypted(bytes.sublist(0, 20), 'pw'),
        DecryptionFailure.corrupted,
        DecryptionException.corruptedMessage,
      );
    });

    test('a container from a newer version is refused with a hint to update', () async {
      final bytes = await codec.encodeEncrypted(sampleData(), 'pw');
      final newer = Uint8List.fromList(bytes)..[3] = 9;
      await expectFailure(
        () => codec.decodeEncrypted(newer, 'pw'),
        DecryptionFailure.unsupportedVersion,
        DecryptionException.unsupportedVersionMessage,
      );
    });

    test('the password prompt also accepts plain and GZip files', () async {
      final data = sampleData();
      expectSame(await codec.decodeEncrypted(codec.encodeJson(data), 'ignored'), data);
      expectSame(await codec.decodeEncrypted(codec.encodeGzip(data), 'ignored'), data);
    });

    test('an empty and a long password both work', () async {
      final data = sampleData();
      expectSame(await codec.decodeEncrypted(await codec.encodeEncrypted(data, ''), ''), data);
      final long = 'ä' * 300;
      expectSame(await codec.decodeEncrypted(await codec.encodeEncrypted(data, long), long), data);
    });
  });

  group('invalid files', () {
    test('random bytes say "This file is not a valid MorphCook backup."', () async {
      await expectFailure(
        () async => codec.decode(List<int>.generate(64, (i) => (i * 37) % 251)),
        DecryptionFailure.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    });

    test('an empty file is invalid', () async {
      await expectFailure(
        () async => codec.decode(const <int>[]),
        DecryptionFailure.invalidFormat,
        DecryptionException.invalidFormatMessage,
      );
    });

    test('JSON that is not a backup is invalid', () async {
      for (final text in [
        '[]',
        '{}',
        '{"profile": {}}',
        '{"schema_version": "1", "profile": {}}',
        '{"schema_version": 1}',
        'null',
      ]) {
        await expectFailure(
          () async => codec.decode(utf8.encode(text)),
          DecryptionFailure.invalidFormat,
          DecryptionException.invalidFormatMessage,
        );
      }
    });

    test('a section of the wrong type is invalid instead of crashing', () async {
      await expectFailure(
        () async => codec.decode(utf8.encode('{"schema_version": 1, "profile": {}, "history": [1, 2]}')),
        DecryptionFailure.invalidFormat,
        DecryptionException.invalidFormatMessage,
      );
    });
  });

  group('schema_version', () {
    test('a newer schema is refused', () async {
      await expectFailure(
        () async => codec.decode(utf8.encode('{"schema_version": 2, "profile": {}}')),
        DecryptionFailure.unsupportedVersion,
        DecryptionException.unsupportedVersionMessage,
      );
    });

    test('the current schema is accepted', () {
      expect(BackupData.currentSchemaVersion, 1);
      expect(codec.decode(utf8.encode('{"schema_version": 1, "profile": {}}')).schemaVersion, 1);
    });
  });

  group('exceptions', () {
    test('toString names the reason', () {
      expect(const DecryptionException(DecryptionFailure.wrongPassword).toString(), contains('wrongPassword'));
    });
  });
}
