import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Backup encode/decode. Two side-by-side artifacts:
///   * `morphcook-backup.json`    — human-readable (encrypted if a password is set)
///   * `morphcook-backup.json.gz` — GZip compressed, always unencrypted
///
/// Encrypted files: magic `ENC` + version + salt + iv + AES-256-GCM ciphertext.
/// PBKDF2(SHA-256, 10000 iters) derives the key. Import auto-detects the format.
class BackupCodec {
  static const List<int> encMagic = [0x45, 0x4E, 0x43]; // "ENC"
  static const List<int> gzipMagic = [0x1f, 0x8b];
  static const int formatVersion = 1;
  static const int _pbkdf2Iterations = 10000;
  static const int _saltLen = 16;
  static const int _ivLen = 12;
  static const int _keyLen = 32; // AES-256

  /// Produce both artifacts from a backup map.
  static BackupArtifacts encode(Map<String, dynamic> backup, {String? password}) {
    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    final jsonUtf8 = utf8.encode(jsonString);

    final Uint8List jsonFile;
    if (password != null && password.isNotEmpty) {
      jsonFile = _encrypt(jsonUtf8, password);
    } else {
      jsonFile = Uint8List.fromList(jsonUtf8);
    }
    final gz = Uint8List.fromList(gzip.encode(jsonUtf8));
    return BackupArtifacts(json: jsonFile, gzip: gz, encrypted: password != null && password.isNotEmpty);
  }

  /// Decode either artifact, auto-detecting the format. Throws
  /// [DecryptionException] when the data is encrypted (or wrong/corrupt).
  static Map<String, dynamic> decode(Uint8List bytes, {String? password}) {
    if (_hasMagic(bytes, encMagic)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionReason.passwordRequired);
      }
      final plain = _decrypt(bytes, password);
      return _parseAndValidate(plain);
    }
    if (_hasMagic(bytes, gzipMagic)) {
      try {
        final plain = gzip.decode(bytes);
        return _parseAndValidate(plain);
      } catch (_) {
        throw const DecryptionException(DecryptionReason.corrupted);
      }
    }
    return _parseAndValidate(bytes);
  }

  static bool _hasMagic(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  static Map<String, dynamic> _parseAndValidate(List<int> utf8Bytes) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(utf8.decode(utf8Bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    if (map['schema_version'] is! int) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    return map;
  }

  // --- crypto ---------------------------------------------------------------

  static Uint8List _encrypt(List<int> plain, String password) {
    final salt = enc.SecureRandom(_saltLen).bytes;
    final iv = enc.IV(enc.SecureRandom(_ivLen).bytes);
    final key = enc.Key(_deriveKey(password, salt));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);

    final out = BytesBuilder();
    out.add(encMagic);
    out.addByte(formatVersion);
    out.add(salt);
    out.add(iv.bytes);
    out.add(encrypted.bytes);
    return out.toBytes();
  }

  static List<int> _decrypt(Uint8List bytes, String password) {
    const headerLen = 3 + 1; // magic + version
    if (bytes.length < headerLen + _saltLen + _ivLen) {
      throw const DecryptionException(DecryptionReason.corrupted);
    }
    var offset = headerLen;
    final salt = bytes.sublist(offset, offset + _saltLen);
    offset += _saltLen;
    final iv = enc.IV(bytes.sublist(offset, offset + _ivLen));
    offset += _ivLen;
    final cipher = bytes.sublist(offset);
    final key = enc.Key(_deriveKey(password, salt));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    try {
      return encrypter.decryptBytes(enc.Encrypted(cipher), iv: iv);
    } catch (_) {
      // GCM auth-tag mismatch ⇒ wrong password (or tampered data).
      throw const DecryptionException(DecryptionReason.wrongPassword);
    }
  }

  /// PBKDF2-HMAC-SHA256. crypto exposes HMAC; the derivation loop is ours.
  static Uint8List _deriveKey(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    final out = Uint8List(_keyLen);
    var written = 0;
    var block = 1;
    while (written < _keyLen) {
      final intBytes = [
        (block >> 24) & 0xff,
        (block >> 16) & 0xff,
        (block >> 8) & 0xff,
        block & 0xff,
      ];
      var u = hmac.convert([...salt, ...intBytes]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < _pbkdf2Iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      final take = (_keyLen - written).clamp(0, t.length);
      out.setRange(written, written + take, t);
      written += take;
      block++;
    }
    return out;
  }
}

class BackupArtifacts {
  BackupArtifacts({required this.json, required this.gzip, required this.encrypted});
  final Uint8List json;
  final Uint8List gzip;
  final bool encrypted;
}

enum DecryptionReason { passwordRequired, wrongPassword, corrupted, invalidFormat }

class DecryptionException implements Exception {
  const DecryptionException(this.reason);
  final DecryptionReason reason;

  String message(bool german) {
    switch (reason) {
      case DecryptionReason.passwordRequired:
        return german
            ? 'Dieses Backup ist verschlüsselt. Bitte Passwort eingeben.'
            : 'This backup is encrypted. Please enter the password.';
      case DecryptionReason.wrongPassword:
        return german
            ? 'Falsches Passwort. Bitte erneut versuchen.'
            : 'Incorrect password. Please try again.';
      case DecryptionReason.corrupted:
        return german
            ? 'Die Backup-Datei ist beschädigt und kann nicht wiederhergestellt werden.'
            : 'Backup file is corrupted and cannot be restored.';
      case DecryptionReason.invalidFormat:
        return german
            ? 'Dies ist keine gültige MorphCook-Backup-Datei.'
            : 'This file is not a valid MorphCook backup.';
    }
  }

  @override
  String toString() => 'DecryptionException(${reason.name})';
}
