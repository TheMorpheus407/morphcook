import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Why a backup could not be decrypted/read. Messages are actionable per
/// SPEC (wrong password / corrupted / not a backup at all).
enum DecryptionFailure { wrongPassword, corrupted, invalidFormat, needsPassword }

class DecryptionException implements Exception {
  final DecryptionFailure reason;

  const DecryptionException(this.reason);

  String get message => switch (reason) {
        DecryptionFailure.wrongPassword =>
          'Incorrect password. Please try again.',
        DecryptionFailure.corrupted =>
          'Backup file is corrupted and cannot be restored.',
        DecryptionFailure.invalidFormat =>
          'This file is not a valid MorphCook backup.',
        DecryptionFailure.needsPassword =>
          'This backup is encrypted. Enter the password to restore it.',
      };

  @override
  String toString() => 'DecryptionException: $message';
}

/// Magic bytes "ENC" marking an encrypted MorphCook backup.
const encryptionMagic = [0x45, 0x4E, 0x43];

/// GZip magic bytes.
const gzipMagic = [0x1f, 0x8b];

const _formatVersion = 1;
const _saltLength = 16;
const _ivLength = 12;
const _pbkdf2Iterations = 10000;
const _keyLengthBytes = 32; // AES-256

bool hasEncryptionMagic(List<int> bytes) =>
    bytes.length >= 3 &&
    bytes[0] == encryptionMagic[0] &&
    bytes[1] == encryptionMagic[1] &&
    bytes[2] == encryptionMagic[2];

bool hasGzipMagic(List<int> bytes) =>
    bytes.length >= 2 && bytes[0] == gzipMagic[0] && bytes[1] == gzipMagic[1];

Uint8List _deriveKey(String password, Uint8List salt) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, _pbkdf2Iterations, _keyLengthBytes));
  return derivator.process(Uint8List.fromList(utf8.encode(password)));
}

/// AES-256-GCM encrypt with PBKDF2 key derivation. Layout:
/// `"ENC" | version(1) | salt(16) | iv(12) | ciphertext+tag`.
/// A fresh random salt and IV are generated per call.
Uint8List encryptBackup(String plaintext, String password, {Random? random}) {
  final rng = random ?? Random.secure();
  final salt =
      Uint8List.fromList(List.generate(_saltLength, (_) => rng.nextInt(256)));
  final iv =
      Uint8List.fromList(List.generate(_ivLength, (_) => rng.nextInt(256)));
  final key = _deriveKey(password, salt);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(true,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final ciphertext =
      cipher.process(Uint8List.fromList(utf8.encode(plaintext)));

  final out = BytesBuilder()
    ..add(encryptionMagic)
    ..addByte(_formatVersion)
    ..add(salt)
    ..add(iv)
    ..add(ciphertext);
  return out.toBytes();
}

/// Decrypts an encrypted backup produced by [encryptBackup].
String decryptBackup(List<int> bytes, String password) {
  if (!hasEncryptionMagic(bytes)) {
    throw const DecryptionException(DecryptionFailure.invalidFormat);
  }
  const headerLength = 3 + 1 + _saltLength + _ivLength;
  if (bytes.length <= headerLength) {
    throw const DecryptionException(DecryptionFailure.corrupted);
  }
  final data = Uint8List.fromList(bytes);
  final version = data[3];
  if (version != _formatVersion) {
    throw const DecryptionException(DecryptionFailure.corrupted);
  }
  final salt = data.sublist(4, 4 + _saltLength);
  final iv = data.sublist(4 + _saltLength, headerLength);
  final ciphertext = data.sublist(headerLength);

  final key = _deriveKey(password, salt);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(false,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  try {
    final plain = cipher.process(ciphertext);
    return utf8.decode(plain);
  } on InvalidCipherTextException {
    // GCM auth failure: with an intact header this is almost always a
    // wrong password (a flipped ciphertext bit is indistinguishable, but
    // "try again" is the actionable advice either way).
    throw const DecryptionException(DecryptionFailure.wrongPassword);
  } on FormatException {
    throw const DecryptionException(DecryptionFailure.corrupted);
  }
}
