import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/backup/backup_service.dart';
import 'package:morphcook/core/models/profile.dart';

void main() {
  final service = BackupService();

  Map<String, dynamic> samplePayload() => service.buildPayload(
        profile: const UserProfile(
            name: 'julia', lang: 'de', avoidFlags: {'vegan'}),
        localData: {
          'saved': ['r1', 'r2'],
          'meal_plan': {
            '2026-W16': {'mon.dinner': 'r3'}
          },
          'history': [
            {'recipe_id': 'r1', 'cooked_at': 1}
          ],
          'content_requests': ['sushi'],
        },
        exportedAt: DateTime.utc(2026, 4, 18, 12),
      );

  group('export/import round-trip', () {
    test('plain JSON export is human-readable and re-importable', () {
      final bytes = service.exportJson(samplePayload());
      final text = utf8.decode(bytes);
      expect(text, contains('"schema_version": 1'));
      final payload = service.importBackup(bytes);
      expect(payload['schema_version'], 1);
      expect((payload['profile'] as Map)['name'], 'julia');
      expect(payload['saved'], ['r1', 'r2']);
      expect(payload['content_requests'], ['sushi']);
    });

    test('gzip export is smaller and auto-detected on import', () {
      final payload = samplePayload();
      final plain = service.exportJson(payload);
      final gz = service.exportGzip(payload);
      expect(gz.length, lessThan(plain.length));
      expect(BackupService.isGzip(gz), isTrue);
      final restored = service.importBackup(gz);
      expect((restored['profile'] as Map)['lang'], 'de');
    });

    test('encrypted export carries ENC magic bytes and needs a password', () {
      final bytes = service.exportJson(samplePayload(), password: 'secret');
      expect(bytes.sublist(0, 3), [0x45, 0x4E, 0x43]);
      expect(BackupService.isEncrypted(bytes), isTrue);
      expect(
        () => service.importBackup(bytes),
        throwsA(predicate((e) =>
            e is DecryptionException &&
            e.reason == DecryptionFailure.needsPassword)),
      );
    });

    test('wrong password fails with an actionable message', () {
      final bytes = service.exportJson(samplePayload(), password: 'secret');
      expect(
        () => service.importBackup(bytes, password: 'wrong'),
        throwsA(predicate((e) =>
            e is DecryptionException &&
            e.reason == DecryptionFailure.wrongPassword &&
            e.message == 'Incorrect password. Please try again.')),
      );
    });

    test('correct password restores the payload', () {
      final original = samplePayload();
      final bytes = service.exportJson(original, password: 'secret');
      final restored = service.importBackup(bytes, password: 'secret');
      expect(restored['exported_at'], original['exported_at']);
      expect((restored['meal_plan'] as Map)['2026-W16'],
          {'mon.dinner': 'r3'});
    });

    test('each encryption uses a unique salt and IV', () {
      final a = service.exportJson(samplePayload(), password: 'pw');
      final b = service.exportJson(samplePayload(), password: 'pw');
      expect(a, isNot(equals(b)));
    });

    test('garbage input reports invalid format', () {
      expect(
        () => service.importBackup(Uint8List.fromList([1, 2, 3, 4, 5])),
        throwsA(predicate((e) =>
            e is DecryptionException &&
            e.reason == DecryptionFailure.invalidFormat &&
            e.message == 'This file is not a valid MorphCook backup.')),
      );
    });

    test('a future schema_version is rejected', () {
      final bytes = Uint8List.fromList(
          utf8.encode(jsonEncode({'schema_version': 99})));
      expect(
        () => service.importBackup(bytes),
        throwsA(predicate((e) =>
            e is DecryptionException &&
            e.reason == DecryptionFailure.invalidFormat)),
      );
    });
  });
}
