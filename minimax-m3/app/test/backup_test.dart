import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/backup/backup_encryption.dart';
import 'package:morphcook/backup/backup_service.dart';

void main() {
  group('BackupEncryption', () {
    test('round-trips plaintext', () async {
      const password = 'correct horse battery staple';
      const payload = '{"hello":"world","number":42}';
      final encrypted =
          await BackupEncryption.encrypt(plaintext: payload, password: password);
      expect(BackupEncryption.isEncrypted(encrypted), isTrue);
      final decrypted =
          await BackupEncryption.decrypt(bytes: encrypted, password: password);
      expect(decrypted, equals(payload));
    });

    test('wrong password throws WrongPasswordException', () async {
      const password = 'correct';
      final encrypted = await BackupEncryption.encrypt(
        plaintext: '{"x":1}',
        password: password,
      );
      expect(
        () async => BackupEncryption.decrypt(bytes: encrypted, password: 'wrong'),
        throwsA(isA<WrongPasswordException>()),
      );
    });

    test('non-encrypted bytes throw InvalidBackupFormatException', () async {
      final bytes = utf8.encode('{"schema_version":1}');
      expect(
        () async => BackupEncryption.decrypt(bytes: bytes, password: 'x'),
        throwsA(isA<InvalidBackupFormatException>()),
      );
    });

    test('truncated ciphertext throws CorruptedBackupException', () async {
      final encrypted = await BackupEncryption.encrypt(
        plaintext: '{"x":1}',
        password: 'p',
      );
      final truncated = encrypted.sublist(0, encrypted.length - 8);
      expect(
        () async => BackupEncryption.decrypt(bytes: truncated, password: 'p'),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('isEncrypted detects magic bytes', () {
      expect(BackupEncryption.isEncrypted([0x45, 0x4E, 0x43, 0x01]), isTrue);
      expect(BackupEncryption.isEncrypted([0x1F, 0x8B, 0x08]), isFalse);
      expect(BackupEncryption.isEncrypted([0x7B]), isFalse); // "{"
    });
  });

  group('gzip', () {
    test('round-trips JSON payload', () {
      const src = '{"a":1,"b":[1,2,3]}';
      final gz = gzipString(src);
      expect(gz.length, lessThan(src.length + 30));
      final back = gunzipString(gz);
      expect(back, equals(src));
    });
  });
}
