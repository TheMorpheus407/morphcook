import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup_codec.dart';

Map<String, dynamic> sampleDoc() => {
  'schema_version': 1,
  'exported_at': '2026-04-18T12:00:00Z',
  'profile': {
    'name': 'Ada',
    'lang': 'de',
    'avoid_flags': ['vegan'],
  },
  'saved': ['doener-vegan', 'pad-thai-vegan'],
  'meal_plan': {
    '2026-W16': {'mon.dinner': 'chili-sin-carne'},
  },
  'history': [
    for (var i = 0; i < 40; i++)
      {'recipe_id': 'recipe-$i', 'cooked_at': '2026-04-0${i % 9 + 1}T19:00:00.000', 'servings': 2},
  ],
  'content_requests': ['pad thai', 'sushi'],
};

void main() {
  final codec = BackupCodec();

  test('plain JSON round-trips and is human-readable', () {
    final files = codec.encode(sampleDoc());
    expect(files.encrypted, isFalse);
    final text = utf8.decode(files.json);
    expect(text, contains('"schema_version": 1'));
    expect(text, contains('\n  "saved"'));
    expect(codec.decode(files.json), sampleDoc());
  });

  test('gzip is detected, decodes, and is much smaller', () {
    final files = codec.encode(sampleDoc());
    expect(files.gzip.sublist(0, 2), gzipMagic);
    expect(BackupCodec.detect(files.gzip), BackupFormat.gzip);
    expect(codec.decode(files.gzip), sampleDoc());
    final reduction = 1 - files.gzip.length / files.json.length;
    expect(reduction, greaterThan(0.7));
  });

  test('password encrypts the JSON file only; gzip stays plain', () {
    final files = codec.encode(sampleDoc(), password: 'hunter2');
    expect(files.encrypted, isTrue);
    expect(files.json.sublist(0, 3), encMagic);
    expect(BackupCodec.detect(files.json), BackupFormat.encrypted);
    expect(BackupCodec.detect(files.gzip), BackupFormat.gzip);
    expect(codec.decode(files.gzip), sampleDoc());
  });

  test('encrypted import requires the password', () {
    final files = codec.encode(sampleDoc(), password: 'hunter2');
    expect(
      () => codec.decode(files.json),
      throwsA(isA<DecryptionException>().having((e) => e.reason, 'reason', DecryptionFailure.passwordRequired)),
    );
    expect(codec.decodeEncrypted(files.json, 'hunter2'), sampleDoc());
  });

  test('wrong password → actionable message', () {
    final files = codec.encode(sampleDoc(), password: 'hunter2');
    expect(
      () => codec.decodeEncrypted(files.json, 'Hunter2'),
      throwsA(
        isA<DecryptionException>()
            .having((e) => e.reason, 'reason', DecryptionFailure.wrongPassword)
            .having((e) => e.message, 'message', 'Incorrect password. Please try again.'),
      ),
    );
  });

  test('truncated encrypted file → corrupted', () {
    final files = codec.encode(sampleDoc(), password: 'pw');
    final cut = Uint8List.fromList(files.json.sublist(0, 20));
    expect(
      () => codec.decodeEncrypted(cut, 'pw'),
      throwsA(
        isA<DecryptionException>()
            .having((e) => e.reason, 'reason', DecryptionFailure.corrupted)
            .having((e) => e.message, 'message', 'Backup file is corrupted and cannot be restored.'),
      ),
    );
  });

  test('truncated JSON → corrupted; truncated gzip → corrupted', () {
    final files = codec.encode(sampleDoc());
    final cutJson = Uint8List.fromList(files.json.sublist(0, files.json.length ~/ 2));
    expect(
      () => codec.decode(cutJson),
      throwsA(isA<DecryptionException>().having((e) => e.reason, 'r', DecryptionFailure.corrupted)),
    );
    final cutGz = Uint8List.fromList(files.gzip.sublist(0, files.gzip.length ~/ 2));
    expect(
      () => codec.decode(cutGz),
      throwsA(isA<DecryptionException>().having((e) => e.reason, 'r', DecryptionFailure.corrupted)),
    );
  });

  test('foreign files → invalid format', () {
    Matcher invalid() => throwsA(
      isA<DecryptionException>()
          .having((e) => e.reason, 'r', DecryptionFailure.invalidFormat)
          .having((e) => e.message, 'm', 'This file is not a valid MorphCook backup.'),
    );
    expect(() => codec.decode(Uint8List.fromList(utf8.encode('hello world'))), invalid());
    expect(() => codec.decode(Uint8List.fromList(utf8.encode('{"foo": 1}'))), invalid());
    expect(() => codec.decode(Uint8List.fromList(utf8.encode('{"schema_version": 99}'))), invalid());
    expect(() => codec.decode(Uint8List.fromList(gzip.encode(utf8.encode('[1,2]')))), invalid());
  });

  test('each encryption uses a fresh salt and IV', () {
    final a = codec.encrypt(Uint8List.fromList([1, 2, 3]), 'pw');
    final b = codec.encrypt(Uint8List.fromList([1, 2, 3]), 'pw');
    expect(a.sublist(4, 4 + 16 + 12), isNot(equals(b.sublist(4, 4 + 16 + 12))));
    expect(codec.decrypt(a, 'pw'), [1, 2, 3]);
    expect(codec.decrypt(b, 'pw'), [1, 2, 3]);
  });

  test('PBKDF2-SHA256 with 10,000 iterations derives a 256-bit key', () {
    expect(pbkdf2Iterations, 10000);
    final key = BackupCodec.deriveKey('password', Uint8List.fromList(utf8.encode('salt')));
    expect(key.length, 32);
    // RFC 7914 §11 style check value for PBKDF2-HMAC-SHA256(password, salt, 10000)
    expect(
      key.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      '5ec02b91a4b59c6f59dd5fbe4ca649ece4fa8568cdb8ba36cf41426e8805522b',
    );
  });
}
