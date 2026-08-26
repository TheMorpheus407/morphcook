import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/backup_crypt.dart';

void main() {
  // 64 zero bytes as a stable test payload.
  final pt = Uint8List.fromList(List<int>.filled(64, 0));

  // Validate our blob format against a known plaintext/round trip and a fixed
  // password (fresh salt/nonce per run, so exact blob comparison is not done).
  test('round trip', () {
    final blob = encryptBackup(pt, 'hunter2');
    expect(isEncryptedBlob(blob.toList()), isTrue);
    expect(blob.length, 4 + 16 + 12 + pt.length + 16);
    final back = decryptBackup(Uint8List.fromList(blob.toList()), 'hunter2');
    expect(back, equals(pt));
  });
  test('wrong password fails', () {
    final blob = encryptBackup(pt, 'hunter2');
    expect(() => decryptBackup(Uint8List.fromList(blob.toList()), 'nope'),
        throwsA(isA<DecryptionException>().having((e) => e.reason, 'reason', 'wrong-password')));
  });
  test('invalid format', () {
    expect(() => decryptBackup(Uint8List(10), 'x'),
        throwsA(isA<DecryptionException>().having((e) => e.reason, 'reason', 'invalid-format')));
  });
  test('empty plaintext', () {
    final blob = encryptBackup(Uint8List(0), 'pw');
    final back = decryptBackup(Uint8List.fromList(blob.toList()), 'pw');
    expect(back, isEmpty);
  });
  test('blob uniqueness (fresh salt/nonce)', () {
    final b1 = encryptBackup(pt, 'pw');
    final b2 = encryptBackup(pt, 'pw');
    expect(b1, isNot(equals(b2)));
  });
}
