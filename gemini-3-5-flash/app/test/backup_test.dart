import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/backup_service.dart';

void main() {
  group('Backup & Restore Service Tests', () {
    const testJson = '{"schema_version":1,"exported_at":"2026-05-21T12:00:00Z","profile":{"name":"Cedric","lang":"en","avoid_flags":[],"avoid_ingredients":[],"required_attributes":[],"max_time_minutes":45,"calorie_target":600,"preferred_effort":"medium","show_variant_tags":true,"reduce_motion":false},"saved":["doener-classic"],"meal_plan":{},"history":[]}';

    test('GZip compression and decompression works', () {
      final compressed = BackupService.compressGZip(testJson);
      expect(compressed.length, lessThan(testJson.length)); // should compress

      // Decompress
      final decompressed = BackupService.decompressGZip(compressed);
      expect(decompressed, equals(testJson));
    });

    test('AES-256-GCM encryption and decryption works with correct password', () {
      const password = 'SecretPassword123';
      final encrypted = BackupService.encryptGCM(testJson, password);
      
      // Magic bytes "ENC" at the start
      expect(encrypted[0], equals(0x45));
      expect(encrypted[1], equals(0x4E));
      expect(encrypted[2], equals(0x43));

      // Decrypt
      final decrypted = BackupService.decryptGCM(encrypted, password);
      expect(decrypted, equals(testJson));
    });

    test('AES-256-GCM decryption fails with incorrect password', () {
      const password = 'SecretPassword123';
      final encrypted = BackupService.encryptGCM(testJson, password);

      expect(
        () => BackupService.decryptGCM(encrypted, 'WrongPassword'),
        throwsA(isA<DecryptionException>().having((e) => e.message, 'message', contains('Incorrect password'))),
      );
    });

    test('Auto-detection of backup bytes', () {
      // 1. Plain text JSON
      final rawBytes = Uint8List.fromList(utf8.encode(testJson));
      final parsedRaw = BackupService.parseBackupBytes(rawBytes);
      expect(parsedRaw, equals(testJson));

      // 2. GZipped JSON
      final gzipped = BackupService.compressGZip(testJson);
      final parsedGzipped = BackupService.parseBackupBytes(gzipped);
      expect(parsedGzipped, equals(testJson));

      // 3. Encrypted JSON (requires password)
      final encrypted = BackupService.encryptGCM(testJson, 'my_pwd');
      
      expect(
        () => BackupService.parseBackupBytes(encrypted),
        throwsA(isA<DecryptionException>().having((e) => e.message, 'message', equals('PASSWORD_REQUIRED'))),
      );

      final parsedEncrypted = BackupService.parseBackupBytes(encrypted, password: 'my_pwd');
      expect(parsedEncrypted, equals(testJson));
    });
  });
}
