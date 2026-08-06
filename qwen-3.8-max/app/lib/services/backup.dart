// File-based backup/restore.
//
// Export writes two files side by side:
//  - `morphcook-backup.json`  — human-readable (encrypted if a password is set)
//  - `morphcook-backup.json.gz` — GZip compressed, always unencrypted
//
// Import auto-detects the format: encryption magic bytes first
// (`0x45 0x4E 0x43`, ASCII "ENC"), then GZip magic (`0x1f 0x8b`),
// otherwise plain JSON.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

const backupFileName = 'morphcook-backup.json';
const backupFileNameGz = 'morphcook-backup.json.gz';
const backupSchemaVersion = 1;

const List<int> encryptionMagic = [0x45, 0x4E, 0x43]; // "ENC"
const List<int> gzipMagic = [0x1f, 0x8b];

const int pbkdf2Iterations = 10000;
const int saltLength = 16;
const int ivLength = 12;
const int keyLength = 32; // AES-256
const int macBits = 128;

enum DecryptionReason {
  needsPassword,
  wrongPassword,
  corrupted,
  invalidFormat,
}

class DecryptionException implements Exception {
  final DecryptionReason reason;
  const DecryptionException(this.reason);

  String get message {
    switch (reason) {
      case DecryptionReason.needsPassword:
        return 'This backup is encrypted. Enter the password to restore it.';
      case DecryptionReason.wrongPassword:
        return 'Incorrect password. Please try again.';
      case DecryptionReason.corrupted:
        return 'Backup file is corrupted and cannot be restored.';
      case DecryptionReason.invalidFormat:
        return 'This file is not a valid MorphCook backup.';
    }
  }

  @override
  String toString() => 'DecryptionException(${reason.name}): $message';
}

/// The parsed contents of a backup file.
class BackupData {
  final Map<String, dynamic> profile;
  final List<String> saved;
  final Map<String, dynamic> mealPlan;
  final List<Map<String, dynamic>> history;
  final List<String> contentRequests;

  const BackupData({
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.contentRequests,
  });

  Map<String, dynamic> toJson(DateTime exportedAt) => {
        'schema_version': backupSchemaVersion,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'profile': profile,
        'saved': saved,
        'meal_plan': mealPlan,
        'history': history,
        'content_requests': contentRequests,
      };

  static BackupData fromBackupJson(Map<String, dynamic> json) {
    final version = json['schema_version'];
    if (version is! int || version != backupSchemaVersion) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    return BackupData(
      profile: (json['profile'] as Map?)?.cast<String, dynamic>() ?? {},
      saved: ((json['saved'] as List?) ?? const []).cast<String>(),
      mealPlan:
          (json['meal_plan'] as Map?)?.cast<String, dynamic>() ?? {},
      history: [
        for (final h in (json['history'] as List?) ?? const [])
          if (h is Map) h.cast<String, dynamic>()
      ],
      contentRequests:
          ((json['content_requests'] as List?) ?? const []).cast<String>(),
    );
  }
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

bool isEncryptedBackup(List<int> bytes) =>
    _startsWith(bytes, encryptionMagic);

bool isGzipBackup(List<int> bytes) => _startsWith(bytes, gzipMagic);

/// AES-256-GCM with PBKDF2(HMAC-SHA256, 10 000 iterations) key derivation.
/// Layout: "ENC" | salt(16) | iv(12) | ciphertext+tag.
class BackupCrypto {
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, keyLength));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  static Uint8List encrypt(Uint8List plain, String password) {
    final random = Random.secure();
    final salt = Uint8List.fromList(
        List.generate(saltLength, (_) => random.nextInt(256)));
    final iv = Uint8List.fromList(
        List.generate(ivLength, (_) => random.nextInt(256)));
    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), macBits, iv, Uint8List(0)));
    final sealed = cipher.process(plain);
    return Uint8List.fromList(
        [...encryptionMagic, ...salt, ...iv, ...sealed]);
  }

  /// Throws [DecryptionException] on wrong password or corrupted data.
  static Uint8List decrypt(Uint8List payload, String password) {
    if (!isEncryptedBackup(payload)) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    final headerLen = encryptionMagic.length + saltLength + ivLength;
    if (payload.length < headerLen + macBits ~/ 8) {
      throw const DecryptionException(DecryptionReason.corrupted);
    }
    final salt = Uint8List.sublistView(
        payload, encryptionMagic.length, encryptionMagic.length + saltLength);
    final iv = Uint8List.sublistView(
        payload, encryptionMagic.length + saltLength, headerLen);
    final sealed = Uint8List.sublistView(payload, headerLen);
    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), macBits, iv, Uint8List(0)));
    try {
      return cipher.process(sealed);
    } on InvalidCipherTextException {
      throw const DecryptionException(DecryptionReason.wrongPassword);
    } catch (_) {
      throw const DecryptionException(DecryptionReason.corrupted);
    }
  }
}

class BackupService {
  /// Serialize the backup payload.
  static Uint8List encodePlain(BackupData data, {DateTime? now}) =>
      Uint8List.fromList(utf8.encode(
          const JsonEncoder.withIndent('  ').convert(data.toJson(now ?? DateTime.now()))));

  static Uint8List encodeGzip(BackupData data, {DateTime? now}) =>
      Uint8List.fromList(gzip.encode(encodePlain(data, now: now)));

  /// Write both backup files to [directory]; returns their paths.
  static Future<List<String>> exportToDirectory(
    BackupData data,
    Directory directory, {
    String? password,
    DateTime? now,
  }) async {
    final paths = <String>[];
    final plain = encodePlain(data, now: now);

    final jsonPath = '${directory.path}/$backupFileName';
    final jsonBytes = (password == null || password.isEmpty)
        ? plain
        : BackupCrypto.encrypt(plain, password);
    await File(jsonPath).writeAsBytes(jsonBytes);
    paths.add(jsonPath);

    final gzPath = '${directory.path}/$backupFileNameGz';
    await File(gzPath).writeAsBytes(encodeGzip(data, now: now));
    paths.add(gzPath);

    return paths;
  }

  /// Auto-detecting parse of a backup file's bytes.
  ///
  /// Encrypted files without a password throw [DecryptionException] with
  /// reason [DecryptionReason.needsPassword]; the caller prompts for the
  /// password and calls again via [parseEncrypted].
  static BackupData parse(Uint8List bytes, {String? password}) {
    if (isEncryptedBackup(bytes)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionReason.needsPassword);
      }
      return parseEncrypted(bytes, password);
    }
    if (isGzipBackup(bytes)) {
      try {
        return parsePlain(Uint8List.fromList(gzip.decode(bytes)));
      } catch (_) {
        throw const DecryptionException(DecryptionReason.corrupted);
      }
    }
    return parsePlain(bytes);
  }

  static BackupData parseEncrypted(Uint8List bytes, String password) {
    final plain = BackupCrypto.decrypt(bytes, password);
    return parsePlain(plain);
  }

  static BackupData parsePlain(Uint8List bytes) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    return BackupData.fromBackupJson(json);
  }
}
