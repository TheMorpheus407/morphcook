import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/backup/crypto.dart';

void main() {
  group('BackupCrypto', () {
    const sample = '{"schema_version":1,"profile":{"name":"cedric"}}';

    test('round-trip with correct password', () async {
      final bytes = await BackupCrypto.encryptJson(sample, 'pw-correct-1');
      expect(BackupCrypto.hasMagic(bytes), isTrue);
      final out =
          await BackupCrypto.decryptJson(bytes, 'pw-correct-1');
      expect(json.decode(out)['profile']['name'], 'cedric');
    });

    test('wrong password → DecryptionException.wrong_password', () async {
      final bytes = await BackupCrypto.encryptJson(sample, 'right');
      expect(
        () async => await BackupCrypto.decryptJson(bytes, 'wrong'),
        throwsA(predicate(
            (e) => e is DecryptionException && e.reason == 'wrong_password')),
      );
    });

    test('missing magic → invalid_format', () async {
      expect(
        () async => await BackupCrypto.decryptJson(
            Uint8List.fromList(utf8.encode('not encrypted')), 'pw'),
        throwsA(predicate(
            (e) => e is DecryptionException && e.reason == 'invalid_format')),
      );
    });

    test('truncated cipher → corrupted', () async {
      final bytes = await BackupCrypto.encryptJson(sample, 'pw');
      final trunc = bytes.sublist(0, bytes.length - 4);
      expect(
        () async => await BackupCrypto.decryptJson(trunc, 'pw'),
        throwsA(isA<DecryptionException>()),
      );
    });

    test('magic-byte detection ignores leading whitespace', () {
      expect(BackupCrypto.hasMagic([0x45, 0x4E, 0x43, 0x01]), isTrue);
      expect(BackupCrypto.hasMagic([0x00, 0x45, 0x4E, 0x43]), isFalse);
      expect(BackupCrypto.hasMagic([0x45, 0x4E]), isFalse);
    });
  });
}
