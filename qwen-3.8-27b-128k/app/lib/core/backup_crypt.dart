/// Optional password encryption for backups: AES-256-GCM with PBKDF2
/// key derivation (10 000 iterations, SHA-256), unique salt + nonce per run.
///
/// On-disk format (magic bytes `45 4E 43` = "ENC"):
///   [0..3)   "ENC"
///   [3)      version byte (1)
///   [4..20)  salt  (16 bytes)
///   [20..32) nonce (12 bytes)
///   [32..)   ciphertext  (followed by...)
///   trailing 16-byte GCM authentication tag
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  /// 'wrong-password' | 'corrupted' | 'invalid-format'
  final String reason;

  @override
  String toString() => 'DecryptionException($reason)';
}

final _rnd = math.Random.secure();

Uint8List _rand(int n) =>
    Uint8List.fromList(List<int>.generate(n, (_) => _rnd.nextInt(256)));

Uint8List _deriveKey(Uint8List password, Uint8List salt) {
  final mac = HMac.withDigest(SHA256Digest()) as Mac;
  final kd = PBKDF2KeyDerivator(mac);
  kd.init(Pbkdf2Parameters(salt, 10000, 32));
  final out = Uint8List(32);
  kd.deriveKey(password, 0, out, 0);
  return out;
}

Uint8List _concat(List<Uint8List> parts) {
  final out = Uint8List(parts.fold<int>(0, (s, p) => s + p.length));
  var off = 0;
  for (final p in parts) {
    out.setRange(off, off + p.length, p);
    off += p.length;
  }
  return out;
}

/// Encrypts [plaintext] with [password] into the ENC blob format.
Uint8List encryptBackup(Uint8List plaintext, String password) {
  final salt = _rand(16);
  final nonce = _rand(12);
  final key = _deriveKey(Uint8List.fromList(utf8.encode(password)), salt);

  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
      true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List.fromList([])));
  // `process` returns ciphertext followed by the 128-bit GCM tag.
  final encrypted = cipher.process(plaintext);

  return _concat([
    Uint8List.fromList([0x45 /*E*/, 0x4E /*N*/, 0x43 /*C*/, 1 /* version */]),
    salt,
    nonce,
    encrypted,
  ]);
}

bool isEncryptedBlob(List<int> bytes) =>
    bytes.length >= 3 &&
    bytes[0] == 0x45 &&
    bytes[1] == 0x4E &&
    bytes[2] == 0x43;

/// Decrypts an ENC blob; throws [DecryptionException] with a machine reason.
Uint8List decryptBackup(Uint8List blob, String password) {
  if (!isEncryptedBlob(blob.toList())) {
    throw const DecryptionException('invalid-format');
  }
  if (blob[3] != 1) {
    throw const DecryptionException('corrupted');
  }
  const saltLen = 16;
  const nonceLen = 12;
  const tagLen = 16;
  if (blob.length < 4 + saltLen + nonceLen + tagLen) {
    throw const DecryptionException('corrupted');
  }
  final salt = Uint8List.fromList(blob.sublist(4, 4 + saltLen));
  final nonce =
      Uint8List.fromList(blob.sublist(4 + saltLen, 4 + saltLen + nonceLen));
  // ciphertext followed by the 16-byte tag
  final ciphertextAndTag =
      Uint8List.fromList(blob.sublist(4 + saltLen + nonceLen));

  final key =
      _deriveKey(Uint8List.fromList(utf8.encode(password)), salt);
  final cipher = GCMBlockCipher(AESEngine());
  cipher.init(
      false,
      AEADParameters(KeyParameter(key), 128, nonce, Uint8List.fromList([])));
  try {
    return cipher.process(ciphertextAndTag);
  } on Exception {
    throw const DecryptionException('wrong-password');
  } on ArgumentError {
    throw const DecryptionException('corrupted');
  }
}
