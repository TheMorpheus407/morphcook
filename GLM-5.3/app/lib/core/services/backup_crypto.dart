import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-256-GCM encryption for password-protected backups (SPEC):
/// PBKDF2 key derivation (10 000 iterations, SHA-256), a unique 16-byte salt
/// and 12-byte IV per encryption, and the magic bytes `ENC` (0x45 0x4E 0x43)
/// in front so the import can auto-detect the format.
class BackupCrypto {
  static const List<int> magicBytes = [0x45, 0x4E, 0x43]; // "ENC"
  static const int saltLength = 16;
  static const int ivLength = 12;
  static const int tagLength = 16;
  static const int iterations = 10000;
  static const int keyLength = 32; // 256 bits

  /// True when [bytes] starts with the encryption magic bytes.
  static bool isEncrypted(List<int> bytes) {
    if (bytes.length < magicBytes.length) return false;
    for (var i = 0; i < magicBytes.length; i++) {
      if (bytes[i] != magicBytes[i]) return false;
    }
    return true;
  }

  /// Derives the AES key from password + salt via PBKDF2-HMAC-SHA256.
  static Uint8List deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts [jsonText] with AES-256-GCM. Output layout:
  /// `ENC || salt(16) || iv(12) || ciphertext || tag(16)` — the GCM
  /// `process` result already ends with the 16-byte authentication tag.
  static List<int> encrypt(String jsonText, String password) {
    final secure = Random.secure();
    final salt = Uint8List.fromList(
        List<int>.generate(saltLength, (_) => secure.nextInt(256)));
    final iv = Uint8List.fromList(
        List<int>.generate(ivLength, (_) => secure.nextInt(256)));
    final key = deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), tagLength * 8, iv, Uint8List(0)));
    final sealed = cipher.process(Uint8List.fromList(utf8.encode(jsonText)));
    return [...magicBytes, ...salt, ...iv, ...sealed];
  }

  /// Decrypts a payload produced by [encrypt]. Throws [DecryptionException]
  /// with an actionable reason on any failure.
  static String decrypt(List<int> bytes, String password) {
    if (!isEncrypted(bytes)) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    if (bytes.length < magicBytes.length + saltLength + ivLength + tagLength) {
      throw const DecryptionException(DecryptionReason.corrupted);
    }
    var offset = magicBytes.length;
    final salt = Uint8List.fromList(bytes.sublist(offset, offset + saltLength));
    offset += saltLength;
    final iv = Uint8List.fromList(bytes.sublist(offset, offset + ivLength));
    offset += ivLength;
    final sealed = Uint8List.fromList(bytes.sublist(offset));
    try {
      final key = deriveKey(password, salt);
      final cipher = GCMBlockCipher(AESEngine())
        ..init(false, AEADParameters(KeyParameter(key), tagLength * 8, iv, Uint8List(0)));
      // GCM verifies the trailing tag inside process and throws on a
      // mismatch (wrong password or tampered bytes).
      final clear = cipher.process(sealed);
      return utf8.decode(clear);
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw const DecryptionException(DecryptionReason.wrongPassword);
    }
  }
}

enum DecryptionReason { needsPassword, wrongPassword, corrupted, invalidFormat }

/// Thrown by encrypted-backup imports (SPEC): the caller must prompt for the
/// password when the reason is [DecryptionReason.needsPassword].
class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final DecryptionReason reason;

  /// Actionable, user-facing message (bilingual).
  String message(String lang) {
    switch (reason) {
      case DecryptionReason.needsPassword:
        return lang == 'de'
            ? 'Diese Sicherung ist passwortgeschützt. Bitte Passwort eingeben.'
            : 'This backup is password protected. Please enter the password.';
      case DecryptionReason.wrongPassword:
        return lang == 'de'
            ? 'Falsches Passwort. Bitte erneut versuchen.'
            : 'Incorrect password. Please try again.';
      case DecryptionReason.corrupted:
        return lang == 'de'
            ? 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'
            : 'Backup file is corrupted and cannot be restored.';
      case DecryptionReason.invalidFormat:
        return lang == 'de'
            ? 'Diese Datei ist keine gültige MorphCook-Sicherung.'
            : 'This file is not a valid MorphCook backup.';
    }
  }

  @override
  String toString() => 'DecryptionException($reason)';
}
