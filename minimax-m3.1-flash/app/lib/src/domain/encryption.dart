import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Why a backup could not be decrypted.
enum DecryptionFailure {
  /// The password does not match.
  wrongPassword,

  /// The file is damaged.
  corrupted,

  /// The file is not a MorphCook backup at all.
  invalidFormat,
}

/// Raised when an encrypted backup cannot be read.
class DecryptionException implements Exception {
  const DecryptionException(this.failure, [this.detail]);

  final DecryptionFailure failure;
  final String? detail;

  /// The message the UI shows to the user.
  String get message {
    switch (failure) {
      case DecryptionFailure.wrongPassword:
        return 'Incorrect password. Please try again.';
      case DecryptionFailure.corrupted:
        return 'Backup file is corrupted and cannot be restored.';
      case DecryptionFailure.invalidFormat:
        return 'This file is not a valid MorphCook backup.';
    }
  }

  @override
  String toString() => 'DecryptionException(${failure.name}): $message';
}

/// Password-based encryption for backups.
///
/// AES-256-GCM with a PBKDF2-HMAC-SHA256 key derivation (10,000
/// iterations). Every export generates a fresh random salt and nonce, so
/// two backups of the same data never look alike.
abstract final class BackupEncryption {
  const BackupEncryption._();

  /// Magic bytes: ASCII "ENC".
  static const List<int> magic = <int>[0x45, 0x4E, 0x43];

  /// GZip magic bytes.
  static const List<int> gzipMagic = <int>[0x1F, 0x8B];

  static const int formatVersion = 1;
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int iterations = 10000;

  static final AesGcm _algorithm = AesGcm.with256bits();
  static final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );

  /// Whether [bytes] starts with the encryption magic bytes.
  static bool isEncrypted(Uint8List bytes) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  /// Whether [bytes] starts with the GZip magic bytes.
  static bool isGZip(Uint8List bytes) {
    if (bytes.length < gzipMagic.length) return false;
    for (var i = 0; i < gzipMagic.length; i++) {
      if (bytes[i] != gzipMagic[i]) return false;
    }
    return true;
  }

  /// Encrypts [plainText] with [password].
  static Future<Uint8List> encryptString(
    String plainText,
    String password,
  ) async {
    final salt = _randomBytes(saltLength);
    final nonce = _randomBytes(nonceLength);

    final secretKey = await _kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKey,
      nonce: nonce,
    );

    final out = BytesBuilder(copy: false)
      ..add(magic)
      ..addByte(formatVersion)
      ..add(salt)
      ..add(nonce)
      ..add(secretBox.cipherText)
      ..add(secretBox.mac.bytes);
    return out.toBytes();
  }

  /// Decrypts bytes produced by [encryptString].
  ///
  /// Throws a [DecryptionException] with an actionable reason.
  static Future<String> decryptToString(
    Uint8List bytes,
    String password,
  ) async {
    if (!isEncrypted(bytes)) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }

    final headerLength = magic.length + 1 + saltLength + nonceLength;
    if (bytes.length < headerLength + macLength) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }

    final version = bytes[magic.length];
    if (version != formatVersion) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }

    final saltStart = magic.length + 1;
    final nonceStart = saltStart + saltLength;
    final payloadStart = nonceStart + nonceLength;

    final salt = Uint8List.sublistView(bytes, saltStart, nonceStart);
    final nonce = Uint8List.sublistView(bytes, nonceStart, payloadStart);
    final cipherText = Uint8List.sublistView(bytes, payloadStart, bytes.length - macLength);
    final mac = Uint8List.sublistView(bytes, bytes.length - macLength, bytes.length);

    try {
      final secretKey = await _kdf.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final clear = await _algorithm.decrypt(secretBox, secretKey: secretKey);
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const DecryptionException(DecryptionFailure.wrongPassword);
    } catch (error) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }
}
