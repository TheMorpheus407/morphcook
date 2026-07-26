import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Reason an encrypted backup could not be opened. Each maps to a specific,
/// actionable message rather than a generic failure.
enum DecryptionFailure {
  wrongPassword,
  corrupted,
  invalidFormat,
  passwordRequired,
}

class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final DecryptionFailure reason;

  String get messageEn => switch (reason) {
    DecryptionFailure.wrongPassword => 'Incorrect password. Please try again.',
    DecryptionFailure.corrupted =>
      'Backup file is corrupted and cannot be restored.',
    DecryptionFailure.invalidFormat =>
      'This file is not a valid MorphCook backup.',
    DecryptionFailure.passwordRequired =>
      'This backup is encrypted. Enter its password to restore it.',
  };

  String get messageDe => switch (reason) {
    DecryptionFailure.wrongPassword =>
      'Falsches Passwort. Bitte versuche es erneut.',
    DecryptionFailure.corrupted =>
      'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.',
    DecryptionFailure.invalidFormat =>
      'Diese Datei ist keine gültige MorphCook-Sicherung.',
    DecryptionFailure.passwordRequired =>
      'Diese Sicherung ist verschlüsselt. Gib das Passwort ein, um sie wiederherzustellen.',
  };

  String message(String lang) => lang == 'de' ? messageDe : messageEn;

  @override
  String toString() => 'DecryptionException($reason): $messageEn';
}

/// AES-256-GCM with a PBKDF2-HMAC-SHA256 derived key.
///
/// Layout: `E N C | version | salt(16) | iv(12) | ciphertext+tag`
class BackupCrypto {
  BackupCrypto({Random? random}) : _random = random ?? Random.secure();

  /// ASCII "ENC" — the marker import uses to tell an encrypted file apart from
  /// a plain JSON one before it tries to parse anything.
  static const List<int> magic = [0x45, 0x4E, 0x43];
  static const int formatVersion = 1;
  static const int saltLength = 16;
  static const int ivLength = 12;
  static const int macLength = 16;
  static const int keyLength = 32;
  static const int pbkdf2Iterations = 10000;

  /// GZip's own magic, checked after ours.
  static const List<int> gzipMagic = [0x1f, 0x8b];

  final Random _random;

  static bool isEncrypted(List<int> bytes) =>
      bytes.length > magic.length &&
      bytes[0] == magic[0] &&
      bytes[1] == magic[1] &&
      bytes[2] == magic[2];

  static bool isGzip(List<int> bytes) =>
      bytes.length > 2 && bytes[0] == gzipMagic[0] && bytes[1] == gzipMagic[1];

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));

  Uint8List deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, keyLength));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List encrypt(String plaintext, String password) {
    if (password.isEmpty) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final salt = _randomBytes(saltLength);
    final iv = _randomBytes(ivLength);
    final key = deriveKey(password, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), macLength * 8, iv, Uint8List(0)),
      );
    final sealed = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));

    final out = BytesBuilder()
      ..add(magic)
      ..addByte(formatVersion)
      ..add(salt)
      ..add(iv)
      ..add(sealed);
    return out.toBytes();
  }

  String decrypt(List<int> bytes, String password) {
    if (!isEncrypted(bytes)) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    const headerLength = 3 + 1 + saltLength + ivLength;
    if (bytes.length < headerLength + macLength) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
    if (bytes[3] != formatVersion) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }

    final data = Uint8List.fromList(bytes);
    final salt = Uint8List.sublistView(data, 4, 4 + saltLength);
    final iv = Uint8List.sublistView(data, 4 + saltLength, headerLength);
    final payload = Uint8List.sublistView(data, headerLength);
    final key = deriveKey(password, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), macLength * 8, iv, Uint8List(0)),
      );

    late final Uint8List opened;
    try {
      opened = cipher.process(payload);
    } on InvalidCipherTextException {
      // GCM cannot distinguish a wrong key from a flipped bit; the tag simply
      // does not verify. A well-formed file with the right length is far more
      // likely to be the wrong password than a corrupted one.
      throw const DecryptionException(DecryptionFailure.wrongPassword);
    } on ArgumentError {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }

    try {
      return utf8.decode(opened);
    } on FormatException {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
  }
}
