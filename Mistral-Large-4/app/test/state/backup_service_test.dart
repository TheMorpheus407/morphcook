import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/state/backup_service.dart';

void main() {
  final service = BackupService();

  final payload = BackupService().buildPayload(
    profile: {'name': 'sam', 'lang': 'de', 'calorie_target': 700},
    saved: ['doener-classic', 'ramen-vegan'],
    mealPlan: {
      '2026-W41': {'mon.dinner': 'doener-classic'},
    },
    history: [
      {'recipe_id': 'doener-classic', 'cooked_at': '2026-10-06T18:30:00.000Z'},
    ],
    contentRequests: ['korean stew', 'korean stew', '  '],
  );

  group('buildPayload', () {
    test('carries schema version, timestamp and all collections', () {
      expect(payload['schema_version'], BackupService.schemaVersion);
      expect(payload['exported_at'], isA<String>());
      expect(payload['profile'], {'name': 'sam', 'lang': 'de', 'calorie_target': 700});
      expect(payload['saved'], ['doener-classic', 'ramen-vegan']);
      expect(payload['meal_plan'], isA<Map>());
      expect(payload['history'], hasLength(1));
      expect(payload['content_requests'], ['korean stew', 'korean stew', '  ']);
    });

    test('omits empty optional collections', () {
      final minimal = BackupService().buildPayload(
        profile: const {},
        saved: const [],
        mealPlan: const {},
        history: const [],
      );
      expect(minimal, isNot(contains('shopping')));
      expect(minimal, isNot(contains('shopping_log')));
      expect(minimal, contains('content_requests'));
    });
  });

  group('export/import roundtrip', () {
    test('plain JSON export is human-readable and parses back', () async {
      final bytes = await service.exportBytes(payload);
      // human-readable: indented JSON, no magic bytes
      expect(bytes.json.sublist(0, 2), isNot(BackupService.encryptionMagic));
      final text = utf8.decode(bytes.json);
      expect(text, contains('\n  "schema_version"'));
      final parsed = await service.parseBackup(bytes.json);
      expect(parsed['schema_version'], BackupService.schemaVersion);
      expect(parsed['saved'], ['doener-classic', 'ramen-vegan']);
      expect(parsed['profile']['name'], 'sam');
    });

    test('gzip export is detected by magic bytes and parses back', () async {
      final bytes = await service.exportBytes(payload);
      expect(bytes.gzip.sublist(0, 2), BackupService.gzipMagic);
      // GZip typically achieves 70–90% size reduction for JSON data.
      expect(bytes.gzip.length, lessThan(bytes.json.length));
      final parsed = await service.parseBackup(bytes.gzip);
      expect(parsed['saved'], ['doener-classic', 'ramen-vegan']);
      expect(parsed['meal_plan'], {'2026-W41': {'mon.dinner': 'doener-classic'}});
    });

    test('import auto-detects plain JSON without any magic bytes', () async {
      final raw = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      final parsed = await service.parseBackup(raw);
      expect(parsed['schema_version'], BackupService.schemaVersion);
    });
  });

  group('password-based encryption (AES-256-GCM)', () {
    test('encrypted export carries the ENC magic bytes', () async {
      final bytes = await service.exportBytes(payload, password: 'hunter2');
      expect(bytes.json.sublist(0, 3), BackupService.encryptionMagic);
      // …and the gzip sibling stays unencrypted for compatibility
      expect(bytes.gzip.sublist(0, 2), BackupService.gzipMagic);
      final parsed = await service.parseBackup(bytes.gzip);
      expect(parsed['saved'], ['doener-classic', 'ramen-vegan']);
    });

    test('encrypted import without a password asks for one', () async {
      final bytes = await service.exportBytes(payload, password: 'hunter2');
      expect(
        () => service.parseBackup(bytes.json),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'password-required')),
      );
    });

    test('wrong password is reported, not a crash', () async {
      final bytes = await service.exportBytes(payload, password: 'hunter2');
      expect(
        () => service.parseBackup(bytes.json, password: 'hunter3'),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'wrong-password')),
      );
    });

    test('correct password roundtrips the payload', () async {
      final bytes = await service.exportBytes(payload, password: 'hunter2');
      final parsed = await service.parseBackup(bytes.json, password: 'hunter2');
      expect(parsed['profile']['name'], 'sam');
      expect(parsed['content_requests'], ['korean stew', 'korean stew', '  ']);
    });

    test('each encryption uses a unique salt and IV', () async {
      final a = await service.exportBytes(payload, password: 'hunter2');
      final b = await service.exportBytes(payload, password: 'hunter2');
      expect(a.json, isNot(b.json));
      // salt lives at bytes 4..20, IV at 20..32
      expect(a.json.sublist(4, 20), isNot(b.json.sublist(4, 20)));
      expect(a.json.sublist(20, 32), isNot(b.json.sublist(20, 32)));
    });

    test('truncated ciphertext is reported as a decryption failure', () async {
      final bytes = await service.exportBytes(payload, password: 'hunter2');
      final truncated = bytes.json.sublist(0, bytes.json.length - 8);
      expect(
        () => service.parseBackup(truncated, password: 'hunter2'),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('decryptJson rejects non-encrypted input', () async {
      expect(
        () => service.decryptJson(Uint8List.fromList(utf8.encode('{}')), 'x'),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason', 'not-encrypted')),
      );
    });
  });

  group('malformed backups', () {
    test('unsupported schema versions are rejected', () async {
      final bumped = jsonEncode({...payload, 'schema_version': 99});
      final raw = Uint8List.fromList(utf8.encode(bumped));
      expect(
        () => service.parseBackup(raw),
        throwsA(isA<FormatException>()
            .having((e) => e.message, 'message', 'unsupported schema_version')),
      );
    });

    test('non-object JSON is rejected', () async {
      final raw = Uint8List.fromList(utf8.encode('[1, 2, 3]'));
      expect(
        () => service.parseBackup(raw),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'not an object')),
      );
    });

    test('non-UTF8 bytes are rejected', () async {
      final raw = Uint8List.fromList([0xff, 0xfe, 0x00, 0x01]);
      expect(
        () => service.parseBackup(raw),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', 'not utf-8')),
      );
    });
  });
}
