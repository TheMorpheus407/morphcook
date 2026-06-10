import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// AES-256-GCM via PBKDF2-SHA256(10_000) with per-export salt + IV.
/// Wire layout for encrypted JSON backup:
///   [0..2]   magic = 'E','N','C'        (0x45 0x4E 0x43)
///   [3]      version = 1
///   [4..19]  salt (16 bytes)
///   [20..31] nonce/iv (12 bytes)
///   [32..]   ciphertext + auth tag      (GCM appends 16-byte tag)
const List<int> backupMagic = [0x45, 0x4E, 0x43];
const int backupVersion = 1;
const int saltLen = 16;
const int ivLen = 12;

class DecryptionException implements Exception {
  final String reason; // 'wrong_password' | 'corrupted' | 'invalid_format'
  final String message;
  DecryptionException(this.reason, this.message);
  @override
  String toString() => 'DecryptionException($reason): $message';
}

class BackupCrypto {
  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256,
  );
  static final _gcm = AesGcm.with256bits();

  static bool hasMagic(List<int> bytes) {
    if (bytes.length < backupMagic.length) return false;
    for (int i = 0; i < backupMagic.length; i++) {
      if (bytes[i] != backupMagic[i]) return false;
    }
    return true;
  }

  static Future<Uint8List> encryptJson(
      String plaintextJson, String password) async {
    final salt = SecretKeyData.random(length: saltLen).bytes;
    final nonce = _gcm.newNonce();
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final secret = await _gcm.encrypt(
      utf8.encode(plaintextJson),
      secretKey: key,
      nonce: nonce,
    );

    // ENC || ver || salt || iv || cipher || mac(16)
    final out = BytesBuilder();
    out.add(backupMagic);
    out.addByte(backupVersion);
    out.add(salt);
    out.add(nonce);
    out.add(secret.cipherText);
    out.add(secret.mac.bytes);
    return out.toBytes();
  }

  static Future<String> decryptJson(
      Uint8List bytes, String password) async {
    if (!hasMagic(bytes)) {
      throw DecryptionException('invalid_format',
          'This file is not a valid MorphCook backup.');
    }
    if (bytes.length < 3 + 1 + saltLen + ivLen + 16) {
      throw DecryptionException('corrupted',
          'Backup file is corrupted and cannot be restored.');
    }
    // skip magic + ver
    int p = 3 + 1;
    final salt = bytes.sublist(p, p + saltLen);
    p += saltLen;
    final nonce = bytes.sublist(p, p + ivLen);
    p += ivLen;
    final macStart = bytes.length - 16;
    if (macStart <= p) {
      throw DecryptionException('corrupted',
          'Backup file is corrupted and cannot be restored.');
    }
    final cipher = bytes.sublist(p, macStart);
    final mac = bytes.sublist(macStart);

    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    try {
      final clear = await _gcm.decrypt(
        SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw DecryptionException(
          'wrong_password', 'Incorrect password. Please try again.');
    } catch (e) {
      throw DecryptionException(
          'corrupted', 'Backup file is corrupted and cannot be restored.');
    }
  }
}
