import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/src/domain/backup.dart';
import 'package:morphcook/src/domain/encryption.dart';
import 'package:morphcook/src/models/history.dart';
import 'package:morphcook/src/models/meal_plan.dart';

import 'support/fixtures.dart';

BackupDocument buildDocument() {
  return BackupDocument(
    schemaVersion: BackupDocument.currentSchemaVersion,
    exportedAt: DateTime.utc(2026, 4, 18, 12),
    profile: buildProfile(name: 'Sam'),
    saved: <String>['recipe-a', 'recipe-b'],
    mealPlan: MealPlan(<String, Map<String, String>>{
      '2026-W16': <String, String>{'mon.dinner': 'recipe-c'},
    }),
    history: <CookingEntry>[
      CookingEntry(recipeId: 'recipe-a', cookedAt: DateTime.utc(2026, 4, 17)),
    ],
    contentRequests: <String>['pad thai', 'sushi'],
  );
}

void main() {
  group('encryption', () {
    test('a round trip returns the original text', () async {
      const text = 'morphcook backup payload';
      final encrypted = await BackupEncryption.encryptString(text, 'hunter2');

      expect(encrypted, isNot(contains(text.codeUnits)));
      expect(
        await BackupEncryption.decryptToString(encrypted, 'hunter2'),
        text,
      );
    });

    test('the output carries the ENC magic bytes', () async {
      final encrypted = await BackupEncryption.encryptString('x', 'p');

      expect(encrypted.take(3), <int>[0x45, 0x4E, 0x43]);
      expect(BackupEncryption.isEncrypted(encrypted), isTrue);
    });

    test('two encryptions of the same text differ', () async {
      final a = await BackupEncryption.encryptString('x', 'p');
      final b = await BackupEncryption.encryptString('x', 'p');

      expect(a, isNot(equals(b)));
    });

    test('the wrong password is reported as such', () async {
      final encrypted = await BackupEncryption.encryptString('x', 'right');

      await expectLater(
        BackupEncryption.decryptToString(encrypted, 'wrong'),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.failure,
            'failure',
            DecryptionFailure.wrongPassword,
          ),
        ),
      );
    });

    test('the error message is actionable', () {
      expect(
        const DecryptionException(DecryptionFailure.wrongPassword).message,
        'Incorrect password. Please try again.',
      );
      expect(
        const DecryptionException(DecryptionFailure.corrupted).message,
        'Backup file is corrupted and cannot be restored.',
      );
      expect(
        const DecryptionException(DecryptionFailure.invalidFormat).message,
        'This file is not a valid MorphCook backup.',
      );
    });

    test('a truncated file is reported as corrupted', () async {
      final encrypted = await BackupEncryption.encryptString('x', 'p');

      await expectLater(
        BackupEncryption.decryptToString(encrypted.sublist(0, 20), 'p'),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.failure,
            'failure',
            DecryptionFailure.corrupted,
          ),
        ),
      );
    });
  });

  group('format detection', () {
    test('plain JSON is detected', () {
      final bytes = Uint8List.fromList(utf8.encode('{"schema_version":1}'));

      expect(BackupCodec.detect(bytes), BackupFormat.plainJson);
    });

    test('gzip is detected', () {
      final bytes = Uint8List.fromList(
        gzip.encode(Uint8List.fromList(utf8.encode('{"a":1}'))),
      );

      expect(BackupCodec.detect(bytes), BackupFormat.gzipped);
    });

    test('an encrypted payload is detected', () async {
      final bytes = await BackupEncryption.encryptString('{"a":1}', 'p');

      expect(BackupCodec.detect(bytes), BackupFormat.encrypted);
    });

    test('random bytes are unknown', () {
      final bytes = Uint8List.fromList(<int>[0x00, 0x01, 0x02, 0x03]);

      expect(BackupCodec.detect(bytes), BackupFormat.unknown);
    });

    test('encryption is checked before gzip', () async {
      final bytes = await BackupEncryption.encryptString('{"a":1}', 'p');

      expect(
        BackupCodec.detect(bytes),
        BackupFormat.encrypted,
      );
    });
  });

  group('encoding and decoding', () {
    test('the document keeps every section', () {
      final json = buildDocument().toJson();

      expect(json['schema_version'], 1);
      expect(json['saved'], <String>['recipe-a', 'recipe-b']);
      expect(json['meal_plan'], contains('2026-W16'));
      expect(json['history'], hasLength(1));
      expect(json['content_requests'], <String>['pad thai', 'sushi']);
      expect(json['profile'], isA<Map<String, dynamic>>());
    });

    test('a plain backup round trips', () {
      final document = buildDocument();
      final bytes = Uint8List.fromList(utf8.encode(document.encode()));

      final restored = BackupCodec.decodePlain(bytes);

      expect(restored.saved, document.saved);
      expect(restored.profile.name, 'Sam');
      expect(restored.mealPlan.recipeFor('2026-W16', 'mon.dinner'), 'recipe-c');
      expect(restored.history, hasLength(1));
      expect(restored.contentRequests, contains('sushi'));
    });

    test('a gzip backup round trips', () {
      final document = buildDocument();
      final bytes = Uint8List.fromList(
        gzip.encode(
          Uint8List.fromList(utf8.encode(document.encode())),
        ),
      );

      final restored = BackupCodec.decodeGZip(bytes);

      expect(restored.saved, document.saved);
    });

    test('an encrypted backup round trips', () async {
      final document = buildDocument();
      final plain = document.encode();
      final bytes = await BackupEncryption.encryptString(plain, 'secret');

      final restored = await BackupCodec.decodeEncrypted(bytes, 'secret');

      expect(restored.saved, document.saved);
    });

    test('auto detection refuses an encrypted file without a password', () async {
      final bytes = await BackupEncryption.encryptString('{"a":1}', 'p');

      await expectLater(
        BackupCodec.decodeAuto(bytes),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('auto detection reads a plain file', () async {
      final bytes = Uint8List.fromList(utf8.encode(buildDocument().encode()));

      final restored = await BackupCodec.decodeAuto(bytes);

      expect(restored.saved, isNotEmpty);
    });

    test('a file that is not a backup is rejected', () {
      final bytes = Uint8List.fromList(utf8.encode('{"hello":"world"}'));

      expect(
        () => BackupCodec.decodePlain(bytes),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('an unsupported schema version is rejected', () {
      final bytes = Uint8List.fromList(
        utf8.encode('{"schema_version": 99, "profile": {}}'),
      );

      expect(
        () => BackupCodec.decodePlain(bytes),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('the encoded document is human readable', () {
      final text = buildDocument().encode();

      expect(text, contains('\n'));
      expect(text, contains('"schema_version": 1'));
    });
  });

  group('writing files', () {
    late Directory scratch;

    setUp(() {
      scratch = Directory.systemTemp.createTempSync('morphcook-backup-test');
    });

    tearDown(() {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    test('both files are written side by side', () async {
      final service = BackupService();
      final files = await service.writeFiles(
        buildDocument(),
        directory: scratch,
      );

      expect(File(files.jsonPath).existsSync(), isTrue);
      expect(File(files.gzipPath).existsSync(), isTrue);
      expect(files.jsonPath.endsWith('morphcook-backup.json'), isTrue);
      expect(files.gzipPath.endsWith('morphcook-backup.json.gz'), isTrue);
    });

    test('the gzip file is smaller than the plain one', () async {
      final service = BackupService();
      final files = await service.writeFiles(
        buildDocument(),
        directory: scratch,
      );

      final plainSize = await File(files.jsonPath).length();
      final gzipSize = await File(files.gzipPath).length();

      expect(gzipSize, lessThan(plainSize));
    });

    test('a password encrypts the json file but not the gzip one', () async {
      final service = BackupService();
      final files = await service.writeFiles(
        buildDocument(),
        password: 'secret',
        directory: scratch,
      );

      final jsonBytes = await File(files.jsonPath).readAsBytes();
      final gzipBytes = await File(files.gzipPath).readAsBytes();

      expect(BackupEncryption.isEncrypted(jsonBytes), isTrue);
      expect(BackupEncryption.isGZip(gzipBytes), isTrue);
    });
  });
}
