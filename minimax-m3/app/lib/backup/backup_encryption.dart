import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM with a PBKDF2-SHA256 derived key (10 000 iterations).
/// Output layout:
///   [magic 3B "ENC"] [version 1B] [salt 16B] [nonce 12B] [ciphertext + mac]
///
/// Decryption surfaces typed exceptions so the UI can render specific copy.
class BackupEncryption {
  BackupEncryption._();

  static const magic = <int>[0x45, 0x4E, 0x43]; // "ENC"
  static const version = 0x01;
  static const _saltLen = 16;
  static const _nonceLen = 12;
  static const _macLen = 16;
  static const _iterations = 10000;

  /// Detect whether [bytes] starts with the encryption magic.
  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  static Future<Uint8List> encrypt({
    required String plaintext,
    required String password,
  }) async {
    final salt = _randomBytes(_saltLen);
    final key = await _deriveKey(password, salt);

    final algo = AesGcm.with256bits();
    final nonce = _randomBytes(_nonceLen);
    final secretBox = await algo.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final out = BytesBuilder()
      ..add(magic)
      ..addByte(version)
      ..add(salt)
      ..add(nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);
    return out.toBytes();
  }

  static Future<String> decrypt({
    required List<int> bytes,
    required String password,
  }) async {
    if (!isEncrypted(bytes)) {
      throw const InvalidBackupFormatException();
    }
    if (bytes.length < magic.length + 1 + _saltLen + _nonceLen + _macLen) {
      throw const CorruptedBackupException();
    }
    final ver = bytes[magic.length];
    if (ver != version) {
      throw const InvalidBackupFormatException();
    }
    var offset = magic.length + 1;
    final salt = bytes.sublist(offset, offset + _saltLen);
    offset += _saltLen;
    final nonce = bytes.sublist(offset, offset + _nonceLen);
    offset += _nonceLen;
    if (bytes.length < offset + _macLen) throw const CorruptedBackupException();
    final cipherText = bytes.sublist(offset, bytes.length - _macLen);
    final mac = bytes.sublist(bytes.length - _macLen);

    final key = await _deriveKey(password, salt);
    final algo = AesGcm.with256bits();
    try {
      final plain = await algo.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key),
      );
      return utf8.decode(plain);
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    } catch (_) {
      throw const CorruptedBackupException();
    }
  }

  static Future<List<int>> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final newSecretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return newSecretKey.extractBytes();
  }

  static List<int> _randomBytes(int n) {
    final rng = math.Random.secure();
    return List<int>.generate(n, (_) => rng.nextInt(256));
  }
}

/// Decryption exception hierarchy. UI maps these to user-friendly messages.
class DecryptionException implements Exception {
  final String message;
  const DecryptionException(this.message);
  @override
  String toString() => 'DecryptionException: $message';
}

class WrongPasswordException extends DecryptionException {
  const WrongPasswordException()
      : super('Incorrect password. Please try again.');
}

class CorruptedBackupException extends DecryptionException {
  const CorruptedBackupException()
      : super('Backup file is corrupted and cannot be restored.');
}

class InvalidBackupFormatException extends DecryptionException {
  const InvalidBackupFormatException()
      : super('This file is not a valid MorphCook backup.');
}
