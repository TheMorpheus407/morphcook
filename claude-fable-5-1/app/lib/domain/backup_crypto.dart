// Optional password protection for backups: AES-256-GCM with a key derived
// by PBKDF2-HMAC-SHA256 (10 000 iterations). Each encryption gets a fresh
// random salt and IV.
//
//   magic "ENC" (3) | version (1) | salt (16) | iv (12) | ciphertext+tag
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

enum DecryptionReason { needsPassword, wrongPassword, corrupted, invalidFormat }

class DecryptionException implements Exception {
  const DecryptionException(this.reason);
  final DecryptionReason reason;

  /// Actionable, user-facing English message (UI localises by [reason]).
  String get message => switch (reason) {
        DecryptionReason.needsPassword => 'This backup is password protected. Enter the password to restore it.',
        DecryptionReason.wrongPassword => 'Incorrect password. Please try again.',
        DecryptionReason.corrupted => 'Backup file is corrupted and cannot be restored.',
        DecryptionReason.invalidFormat => 'This file is not a valid MorphCook backup.',
      };

  @override
  String toString() => 'DecryptionException(${reason.name}): $message';
}

class BackupCrypto {
  static const List<int> magic = [0x45, 0x4E, 0x43]; // "ENC"
  static const int version = 1;
  static const int saltLength = 16;
  static const int ivLength = 12;
  static const int tagBits = 128;
  static const int iterations = 10000;
  static const int keyLength = 32;

  static bool isEncrypted(List<int> bytes) =>
      bytes.length >= 3 && bytes[0] == magic[0] && bytes[1] == magic[1] && bytes[2] == magic[2];

  static Uint8List deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));
    return derivator.process(Uint8List.fromList(password.codeUnits.length == password.length
        ? password.codeUnits
        : _utf8(password)));
  }

  static List<int> _utf8(String s) {
    // Avoid importing dart:convert just for this; String.codeUnits is UTF-16.
    final out = <int>[];
    for (final r in s.runes) {
      if (r < 0x80) {
        out.add(r);
      } else if (r < 0x800) {
        out..add(0xC0 | (r >> 6))..add(0x80 | (r & 0x3F));
      } else if (r < 0x10000) {
        out..add(0xE0 | (r >> 12))..add(0x80 | ((r >> 6) & 0x3F))..add(0x80 | (r & 0x3F));
      } else {
        out
          ..add(0xF0 | (r >> 18))
          ..add(0x80 | ((r >> 12) & 0x3F))
          ..add(0x80 | ((r >> 6) & 0x3F))
          ..add(0x80 | (r & 0x3F));
      }
    }
    return out;
  }

  static Uint8List _randomBytes(int n, Random rng) => Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));

  static Uint8List encrypt(Uint8List plaintext, String password, {Random? random}) {
    final rng = random ?? Random.secure();
    final salt = _randomBytes(saltLength, rng);
    final iv = _randomBytes(ivLength, rng);
    final key = deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())..init(true, AEADParameters(KeyParameter(key), tagBits, iv, Uint8List(0)));
    final out = cipher.process(plaintext);
    final b = BytesBuilder()
      ..add(magic)
      ..addByte(version)
      ..add(salt)
      ..add(iv)
      ..add(out);
    return b.toBytes();
  }

  static Uint8List decrypt(Uint8List data, String password) {
    if (!isEncrypted(data)) throw const DecryptionException(DecryptionReason.invalidFormat);
    const header = 3 + 1 + saltLength + ivLength;
    if (data.length < header + tagBits ~/ 8) throw const DecryptionException(DecryptionReason.corrupted);
    if (data[3] != version) throw const DecryptionException(DecryptionReason.invalidFormat);
    final salt = Uint8List.sublistView(data, 4, 4 + saltLength);
    final iv = Uint8List.sublistView(data, 4 + saltLength, header);
    final body = Uint8List.sublistView(data, header);
    final key = deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())..init(false, AEADParameters(KeyParameter(key), tagBits, iv, Uint8List(0)));
    try {
      return cipher.process(body);
    } on InvalidCipherTextException {
      throw const DecryptionException(DecryptionReason.wrongPassword);
    } catch (_) {
      throw const DecryptionException(DecryptionReason.corrupted);
    }
  }
}
