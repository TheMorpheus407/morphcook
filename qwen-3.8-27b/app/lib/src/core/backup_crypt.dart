import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/modes/gcm.dart';

class DecryptionException implements Exception {
  const DecryptionException(this.reason, [this.message]);

  /// 'wrong-password' | 'corrupted' | 'invalid-format'
  final String reason;
  final String? message;

  String localizedMessage(String lang) {
    final de = lang == 'de';
    switch (reason) {
      case 'wrong-password':
        return de ? 'Falsches Passwort. Bitte versuche es erneut.' : 'Incorrect password. Please try again.';
      case 'corrupted':
        return de
            ? 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'
            : 'Backup file is corrupted and cannot be restored.';
      default:
        return de
            ? 'Diese Datei ist keine gültige MorphCook-Sicherung.'
            : 'This file is not a valid MorphCook backup.';
    }
  }
}

/// Encrypted backup format
/// magic `ENC` (0x45 0x4E 0x43), version byte (1), salt(16), iv(12),
/// then AES-256-GCM ciphertext with appended 128-bit tag.
class BackupCrypto {
  BackupCrypto._();

  static const Uint8List magic = Uint8List.fromList([0x45, 0x4E, 0x43]);
  static const int version = 1;
  static const int iterations = 10000;
  static const int saltLen = 16;
  static const int ivLen = 12;
  static const int tagBits = 128;

  static bool looksEncrypted(List<int> bytes) =>
      bytes.length > 3 &&
      bytes[0] == magic[0] &&
      bytes[1] == magic[1] &&
      bytes[2] == magic[2];

  static Uint8List _rand(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => math.Random.secure().nextInt(256)));

  static Uint8List _key(Uint8List password, Uint8List salt) {
    final kd = PBKDF2(HMAC(SHA256Digest(), 64))
      ..init(KeyParameter(password, 0, password.length),
          ParametersWithIterations(ParametersWithIV(salt, 8), iterations));
    final out = Uint8List(32);
    kd.process(password, 0, out, 0, 32);
    return out;
  }

  static Uint8List encrypt(Uint8List plaintext, String password) {
    final pass = Uint8List.fromList(utf8.encode(password));
    final salt = _rand(saltLen);
    final iv = _rand(ivLen);
    final key = _key(pass, salt);
    final cipher = GCMBlockCipher(AESFastEngine())
      ..init(true, ParametersWithIV(KeyParameter(key, 0, 32), iv, tagBits));
    final enc = cipher.processFinal(plaintext);
    final tag = (cipher as StreamCipher).mac;
    return Uint8List.fromList(enc.toList() + tag.toList());
  }

  static Uint8List decrypt(Uint8List blob, String password) {
    if (blob.length < 3 || !(blob[0] == 0x45 && blob[1] == 0x4E && blob[2] == 0x43)) {
      throw const DecryptionException('invalid-format');
    }
    final ver = blob.length > 3 ? blob[3] : 0;
    if (ver != version) {
      throw const DecryptionException('corrupted');
    }
    int off = 4;
    if (blob.length < off + saltLen + ivLen + tagBits ~/ 8 + 1) {
      throw const DecryptionException('corrupted');
    }
    final salt = blob.sublist(off, off + saltLen);
    off += saltLen;
    final iv = blob.sublist(off, off + ivLen);
    off += ivLen;
    final ciphertext = blob.sublist(off, off + (blob.length - off) - tagBits ~/ 8);
    final tag = blob.sublist(blob.length - tagBits ~/ 8, blob.length);

    final pass = Uint8List.fromList(utf8.encode(password));
    final key = _key(pass, Uint8List.fromList(salt));
    final tagOnly = tag;
    final combined = Uint8List.fromList(ciphertext + tagOnly);

    final cipher = GCMBlockCipher(AESFastEngine())
      ..init(false, ParametersWithIV(KeyParameter(key, 0, 32), iv, tagBits));
    try {
      return cipher.processFinal(combined);
    } on Exception {
      throw const DecryptionException('wrong-password');
    }
  }
}
