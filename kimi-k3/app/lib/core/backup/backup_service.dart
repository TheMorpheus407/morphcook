import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pointycastle/export.dart' as pc;

import '../models/profile.dart';

/// Thrown when an encrypted backup cannot be decrypted.
class DecryptionException implements Exception {
  final DecryptionFailure reason;
  final String message;
  const DecryptionException(this.reason, this.message);

  @override
  String toString() => message;
}

enum DecryptionFailure { wrongPassword, corrupted, invalidFormat, needsPassword }

/// File-based backup/restore.
///
/// Export produces two payloads side by side:
/// - `morphcook-backup.json` — human-readable (AES-256-GCM encrypted when a
///   password is provided; magic bytes "ENC")
/// - `morphcook-backup.json.gz` — GZip compressed, always unencrypted.
class BackupService {
  static const schemaVersion = 1;
  static const encMagic = [0x45, 0x4E, 0x43]; // "ENC"
  static const gzMagic = [0x1f, 0x8b];
  static const _pbkdf2Iterations = 10000;

  // ---- export -------------------------------------------------------------

  Map<String, dynamic> buildPayload({
    required UserProfile profile,
    required Map<String, dynamic> localData,
    DateTime? exportedAt,
  }) {
    return {
      'schema_version': schemaVersion,
      'exported_at': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'profile': profile.toJson(),
      ...localData,
    };
  }

  /// Plain human-readable JSON bytes (or encrypted when [password] is set).
  Uint8List exportJson(Map<String, dynamic> payload, {String? password}) {
    final pretty = const JsonEncoder.withIndent('  ').convert(payload);
    final bytes = Uint8List.fromList(utf8.encode(pretty));
    if (password == null || password.isEmpty) return bytes;
    return encryptBytes(bytes, password);
  }

  /// GZip-compressed JSON, always unencrypted.
  Uint8List exportGzip(Map<String, dynamic> payload) {
    final json = jsonEncode(payload);
    final compressed =
        GZipEncoder().encode(Uint8List.fromList(utf8.encode(json)));
    return Uint8List.fromList(compressed!);
  }

  // ---- import -------------------------------------------------------------

  static bool isEncrypted(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == encMagic[0] &&
      bytes[1] == encMagic[1] &&
      bytes[2] == encMagic[2];

  static bool isGzip(Uint8List bytes) =>
      bytes.length >= 2 && bytes[0] == gzMagic[0] && bytes[1] == gzMagic[1];

  /// Auto-detects the format (encryption magic → GZip magic → plain JSON) and
  /// returns the decoded payload. Throws [DecryptionException] with
  /// [DecryptionFailure.needsPassword] when the file is encrypted and no
  /// password was given — the caller must prompt and call again with one.
  Map<String, dynamic> importBackup(Uint8List bytes, {String? password}) {
    Uint8List jsonBytes;
    if (isEncrypted(bytes)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionFailure.needsPassword,
            'This backup is protected by a password.');
      }
      jsonBytes = decryptBytes(bytes, password);
    } else if (isGzip(bytes)) {
      try {
        jsonBytes = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
      } catch (_) {
        throw const DecryptionException(DecryptionFailure.corrupted,
            'Backup file is corrupted and cannot be restored.');
      }
    } else {
      jsonBytes = bytes;
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.invalidFormat,
          'This file is not a valid MorphCook backup.');
    }

    final version = payload['schema_version'];
    if (version is! int || version > schemaVersion) {
      throw const DecryptionException(DecryptionFailure.invalidFormat,
          'This file is not a valid MorphCook backup.');
    }
    return payload;
  }

  // ---- AES-256-GCM + PBKDF2 ------------------------------------------------

  Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64))
      ..init(pc.Pbkdf2Parameters(
          salt, _pbkdf2Iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List encryptBytes(Uint8List plain, String password) {
    final rng = Random.secure();
    final salt =
        Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256)));
    final iv = Uint8List.fromList(List.generate(12, (_) => rng.nextInt(256)));
    final key = _deriveKey(password, salt);
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(true, pc.AEADParameters(pc.KeyParameter(key), 128, iv,
          Uint8List(0)));
    final ciphertext = cipher.process(plain);
    return Uint8List.fromList([...encMagic, ...salt, ...iv, ...ciphertext]);
  }

  Uint8List decryptBytes(Uint8List bytes, String password) {
    if (!isEncrypted(bytes) || bytes.length < 3 + 16 + 12 + 16) {
      throw const DecryptionException(DecryptionFailure.invalidFormat,
          'This file is not a valid MorphCook backup.');
    }
    final salt = Uint8List.fromList(bytes.sublist(3, 19));
    final iv = Uint8List.fromList(bytes.sublist(19, 31));
    final ciphertext = Uint8List.fromList(bytes.sublist(31));
    final key = _deriveKey(password, salt);
    final cipher = pc.GCMBlockCipher(pc.AESEngine())
      ..init(false, pc.AEADParameters(pc.KeyParameter(key), 128, iv,
          Uint8List(0)));
    try {
      return cipher.process(ciphertext);
    } catch (_) {
      // GCM authentication-tag mismatch: wrong password or tampered data.
      throw const DecryptionException(DecryptionFailure.wrongPassword,
          'Incorrect password. Please try again.');
    }
  }
}
