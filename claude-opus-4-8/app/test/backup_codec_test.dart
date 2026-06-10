import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup_codec.dart';

Map<String, dynamic> _sample() => {
      'schema_version': 1,
      'exported_at': '2026-04-18T12:00:00Z',
      'profile': {'name': 'Cedric', 'lang': 'de'},
      'saved': ['doener-vegan', 'alfredo-classic'],
      'meal_plan': {
        '2026-W16': {'mon.dinner': 'chili-vegan'}
      },
      'history': [],
      'content_requests': ['pad thai', 'sushi'],
    };

void main() {
  test('plain round-trip', () {
    final a = BackupCodec.encode(_sample());
    expect(a.encrypted, isFalse);
    // JSON file is plain utf8 JSON (no magic).
    expect(a.json[0], isNot(0x45));
    final decoded = BackupCodec.decode(a.json);
    expect(decoded['saved'], ['doener-vegan', 'alfredo-classic']);
  });

  test('gzip artifact has gzip magic and decodes', () {
    final a = BackupCodec.encode(_sample());
    expect(a.gzip[0], 0x1f);
    expect(a.gzip[1], 0x8b);
    final decoded = BackupCodec.decode(a.gzip);
    expect(decoded['content_requests'], ['pad thai', 'sushi']);
    // gzip should be smaller than (or near) the raw json for real payloads;
    // at minimum it must be non-empty.
    expect(a.gzip.isNotEmpty, isTrue);
  });

  test('encrypted artifact carries ENC magic and round-trips with password', () {
    final a = BackupCodec.encode(_sample(), password: 'hunter2');
    expect(a.encrypted, isTrue);
    expect(a.json.sublist(0, 3), BackupCodec.encMagic);
    final decoded = BackupCodec.decode(a.json, password: 'hunter2');
    expect(decoded['profile']['name'], 'Cedric');
  });

  test('encrypted without password throws passwordRequired', () {
    final a = BackupCodec.encode(_sample(), password: 'pw');
    expect(
      () => BackupCodec.decode(a.json),
      throwsA(isA<DecryptionException>().having(
          (e) => e.reason, 'reason', DecryptionReason.passwordRequired)),
    );
  });

  test('wrong password throws wrongPassword', () {
    final a = BackupCodec.encode(_sample(), password: 'right');
    expect(
      () => BackupCodec.decode(a.json, password: 'wrong'),
      throwsA(isA<DecryptionException>().having(
          (e) => e.reason, 'reason', DecryptionReason.wrongPassword)),
    );
  });

  test('non-backup JSON (no schema_version) is invalidFormat', () {
    final bytes = Uint8List.fromList(utf8.encode('{"hello":"world"}'));
    expect(
      () => BackupCodec.decode(bytes),
      throwsA(isA<DecryptionException>().having(
          (e) => e.reason, 'reason', DecryptionReason.invalidFormat)),
    );
  });

  test('garbage bytes are invalidFormat', () {
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);
    expect(() => BackupCodec.decode(bytes), throwsA(isA<DecryptionException>()));
  });

  test('unique salt/iv per encryption (ciphertext differs)', () {
    final a = BackupCodec.encode(_sample(), password: 'pw');
    final b = BackupCodec.encode(_sample(), password: 'pw');
    expect(a.json, isNot(equals(b.json)));
  });

  test('messages are localized', () {
    const e = DecryptionException(DecryptionReason.wrongPassword);
    expect(e.message(false), contains('Incorrect password'));
    expect(e.message(true), contains('Falsches Passwort'));
  });
}
