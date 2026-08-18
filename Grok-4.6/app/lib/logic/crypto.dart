import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

enum DecryptionFailure {
  wrongPassword,
  corrupted,
  invalidFormat,
  needsPassword,
}

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

const encryptionMagic = [0x45, 0x4E, 0x43];
const gzipMagic = [0x1f, 0x8b];

const _formatVersion = 1;
const _saltLength = 16;
const _ivLength = 12;
const _pbkdf2Iterations = 10000;
const _keyLengthBytes = 32;

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

Uint8List encryptBackup(String plaintext, String password, {Random? random}) {
  final rng = random ?? Random.secure();
  final salt = Uint8List.fromList(
    List.generate(_saltLength, (_) => rng.nextInt(256)),
  );
  final iv = Uint8List.fromList(
    List.generate(_ivLength, (_) => rng.nextInt(256)),
  );
  final key = _deriveKey(password, salt);

  final cipher = GCMBlockCipher(AESEngine())
    ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  final ciphertext = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));

  return (BytesBuilder()
        ..add(encryptionMagic)
        ..addByte(_formatVersion)
        ..add(salt)
        ..add(iv)
        ..add(ciphertext))
      .toBytes();
}

String decryptBackup(List<int> bytes, String password) {
  if (!hasEncryptionMagic(bytes)) {
    throw const DecryptionException(DecryptionFailure.invalidFormat);
  }
  const headerLength = 3 + 1 + _saltLength + _ivLength;
  if (bytes.length <= headerLength) {
    throw const DecryptionException(DecryptionFailure.corrupted);
  }
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final version = data[3];
  if (version != _formatVersion) {
    throw const DecryptionException(DecryptionFailure.corrupted);
  }
  final salt = Uint8List.sublistView(data, 4, 4 + _saltLength);
  final iv = Uint8List.sublistView(data, 4 + _saltLength, headerLength);
  final ciphertext = Uint8List.sublistView(data, headerLength);

  final key = _deriveKey(password, salt);
  final cipher = GCMBlockCipher(AESEngine())
    ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
  try {
    final plain = cipher.process(ciphertext);
    return utf8.decode(plain);
  } on InvalidCipherTextException {
    throw const DecryptionException(DecryptionFailure.wrongPassword);
  } on FormatException {
    throw const DecryptionException(DecryptionFailure.corrupted);
  }
}
