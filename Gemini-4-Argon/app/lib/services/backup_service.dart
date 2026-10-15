import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/history_entry.dart';
import '../models/profile.dart';

enum DecryptionFailureReason {
  passwordRequired,
  wrongPassword,
  corruptedData,
  invalidFormat,
}

class DecryptionException implements Exception {
  final DecryptionFailureReason reason;
  final String message;

  const DecryptionException(this.reason, this.message);

  @override
  String toString() => 'DecryptionException(${reason.name}): $message';
}

enum RestoreMode {
  replace,
  merge,
}

class BackupPayload {
  final int schemaVersion;
  final DateTime exportedAt;
  final UserProfile profile;
  final List<String> saved;
  final Map<String, Map<String, String>> mealPlan;
  final List<CookHistoryEntry> history;
  final List<String> contentRequests;

  const BackupPayload({
    this.schemaVersion = 1,
    required this.exportedAt,
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    this.contentRequests = const [],
  });

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('schema_version') || !json.containsKey('profile')) {
      throw const DecryptionException(
        DecryptionFailureReason.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    }
    final version = (json['schema_version'] as num?)?.toInt();
    if (version != 1) {
      throw const DecryptionException(
        DecryptionFailureReason.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    }

    final rawMealPlan = json['meal_plan'] as Map<String, dynamic>? ?? {};
    final parsedMealPlan = <String, Map<String, String>>{};
    for (final entry in rawMealPlan.entries) {
      final weekMap = entry.value as Map<String, dynamic>? ?? {};
      parsedMealPlan[entry.key] = weekMap.map(
        (k, v) => MapEntry(k, v.toString()),
      );
    }

    final rawHistory = json['history'] as List<dynamic>? ?? const [];
    final rawSaved = json['saved'] as List<dynamic>? ?? const [];
    final rawRequests = json['content_requests'] as List<dynamic>? ?? const [];

    return BackupPayload(
      schemaVersion: version!,
      exportedAt: DateTime.tryParse(json['exported_at']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      profile: UserProfile.fromJson(
        json['profile'] as Map<String, dynamic>? ?? const {},
      ),
      saved: rawSaved.map((e) => e.toString()).toList(),
      mealPlan: parsedMealPlan,
      history: rawHistory
          .map((e) => CookHistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      contentRequests: rawRequests.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved,
        'meal_plan': mealPlan,
        'history': history.map((h) => h.toJson()).toList(),
        'content_requests': contentRequests,
      };
}

class BackupExportResult {
  final Uint8List jsonFileBytes;
  final Uint8List gzipFileBytes;
  final bool isEncrypted;
  final int uncompressedByteLength;
  final String? jsonFilePath;
  final String? gzipFilePath;

  const BackupExportResult({
    required this.jsonFileBytes,
    required this.gzipFileBytes,
    required this.isEncrypted,
    required this.uncompressedByteLength,
    this.jsonFilePath,
    this.gzipFilePath,
  });

  double get compressionRatio => uncompressedByteLength == 0
      ? 0
      : 1.0 - (gzipFileBytes.length / uncompressedByteLength);
}

class BackupService {
  const BackupService._();

  /// Magic bytes `[0x45, 0x4E, 0x43]` (ASCII "ENC") for encrypted backup detection.
  static const List<int> encryptedMagicBytes = [0x45, 0x4E, 0x43];

  /// Magic bytes `[0x1F, 0x8B]` for GZip compressed backup detection.
  static const List<int> gzipMagicBytes = [0x1F, 0x8B];

  static const int pbkdf2Iterations = 10000;
  static const int _saltLength = 16;
  static const int _ivLength = 12;
  static const int _macBitLength = 128;

  /// Checks whether [bytes] starts with the `ENC` (`[0x45, 0x4E, 0x43]`) magic header.
  static bool isEncryptedBytes(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == encryptedMagicBytes[0] &&
        bytes[1] == encryptedMagicBytes[1] &&
        bytes[2] == encryptedMagicBytes[2];
  }

  /// Checks whether [bytes] starts with the GZip (`[0x1F, 0x8B]`) magic header.
  static bool isGzipBytes(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == gzipMagicBytes[0] && bytes[1] == gzipMagicBytes[1];
  }

  /// Creates both `morphcook-backup.json` (plain or AES-256-GCM encrypted when
  /// [password] is non-empty) and `morphcook-backup.json.gz` (always GZip
  /// compressed, unencrypted for compatibility).
  static Future<BackupExportResult> exportBackup(
    BackupPayload payload, {
    String? password,
    Directory? targetDirectory,
  }) async {
    final jsonString =
        const JsonEncoder.withIndent('  ').convert(payload.toJson());
    final plainUtf8Bytes = Uint8List.fromList(utf8.encode(jsonString));
    final gzipBytes = Uint8List.fromList(gzip.encode(plainUtf8Bytes));

    final hasPassword = password != null && password.isNotEmpty;
    final jsonFileBytes =
        hasPassword ? encryptBytes(plainUtf8Bytes, password) : plainUtf8Bytes;

    String? jsonPath;
    String? gzPath;
    if (targetDirectory != null) {
      if (!targetDirectory.existsSync()) {
        targetDirectory.createSync(recursive: true);
      }
      final jsonFile = File('${targetDirectory.path}/morphcook-backup.json');
      final gzFile = File('${targetDirectory.path}/morphcook-backup.json.gz');
      await jsonFile.writeAsBytes(jsonFileBytes, flush: true);
      await gzFile.writeAsBytes(gzipBytes, flush: true);
      jsonPath = jsonFile.path;
      gzPath = gzFile.path;
    }

    return BackupExportResult(
      jsonFileBytes: jsonFileBytes,
      gzipFileBytes: gzipBytes,
      isEncrypted: hasPassword,
      uncompressedByteLength: plainUtf8Bytes.length,
      jsonFilePath: jsonPath,
      gzipFilePath: gzPath,
    );
  }

  /// Encrypts [plainBytes] with AES-256-GCM using PBKDF2-HMAC-SHA256 (10,000 iterations),
  /// prepending the `[0x45, 0x4E, 0x43]` ("ENC") magic bytes + salt + IV.
  static Uint8List encryptBytes(Uint8List plainBytes, String password) {
    final rng = Random.secure();
    final salt =
        Uint8List.fromList(List<int>.generate(_saltLength, (_) => rng.nextInt(256)));
    final iv =
        Uint8List.fromList(List<int>.generate(_ivLength, (_) => rng.nextInt(256)));

    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(
          KeyParameter(key),
          _macBitLength,
          iv,
          Uint8List(0),
        ),
      );

    final cipherText = cipher.process(plainBytes);

    final builder = BytesBuilder(copy: false)
      ..add(encryptedMagicBytes)
      ..add(salt)
      ..add(iv)
      ..add(cipherText);
    return builder.toBytes();
  }

  /// Decrypts an encrypted backup buffer starting with `[0x45, 0x4E, 0x43]`.
  static Uint8List decryptBytes(Uint8List encryptedBytes, String password) {
    if (!isEncryptedBytes(encryptedBytes)) {
      throw const DecryptionException(
        DecryptionFailureReason.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    }
    const headerLen = 3 + _saltLength + _ivLength;
    // Minimum length: header + 16-byte GCM auth tag + at least 2 bytes of JSON
    if (encryptedBytes.length < headerLen + 18) {
      throw const DecryptionException(
        DecryptionFailureReason.corruptedData,
        'Backup file is corrupted and cannot be restored.',
      );
    }

    final salt = Uint8List.sublistView(encryptedBytes, 3, 3 + _saltLength);
    final iv = Uint8List.sublistView(
      encryptedBytes,
      3 + _saltLength,
      headerLen,
    );
    final cipherText = Uint8List.sublistView(encryptedBytes, headerLen);

    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(
          KeyParameter(key),
          _macBitLength,
          iv,
          Uint8List(0),
        ),
      );

    try {
      return cipher.process(cipherText);
    } on InvalidCipherTextException {
      throw const DecryptionException(
        DecryptionFailureReason.wrongPassword,
        'Incorrect password. Please try again.',
      );
    } catch (_) {
      throw const DecryptionException(
        DecryptionFailureReason.corruptedData,
        'Backup file is corrupted and cannot be restored.',
      );
    }
  }

  /// Auto-detects format by checking encryption magic bytes (`0x45 0x4E 0x43`)
  /// first, then GZip magic bytes (`0x1f 0x8b`), then plain UTF-8 JSON.
  /// If encrypted format is detected, throws [DecryptionException] with
  /// [DecryptionFailureReason.passwordRequired] so caller can prompt for password
  /// and invoke [importEncryptedBackup].
  static BackupPayload importBackup(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const DecryptionException(
        DecryptionFailureReason.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    }
    if (isEncryptedBytes(bytes)) {
      throw const DecryptionException(
        DecryptionFailureReason.passwordRequired,
        'Encrypted backup detected. Please enter your password.',
      );
    }

    Uint8List jsonBytes = bytes;
    if (isGzipBytes(bytes)) {
      try {
        jsonBytes = Uint8List.fromList(gzip.decode(bytes));
      } catch (_) {
        throw const DecryptionException(
          DecryptionFailureReason.corruptedData,
          'Backup file is corrupted and cannot be restored.',
        );
      }
    }

    return _parseJsonPayload(jsonBytes);
  }

  /// Decrypts and parses an encrypted backup using [password].
  static BackupPayload importEncryptedBackup(
    Uint8List bytes,
    String password,
  ) {
    final decryptedBytes = decryptBytes(bytes, password);
    return _parseJsonPayload(decryptedBytes);
  }

  static BackupPayload _parseJsonPayload(Uint8List utf8Bytes) {
    final String text;
    try {
      text = utf8.decode(utf8Bytes);
    } catch (_) {
      throw const DecryptionException(
        DecryptionFailureReason.corruptedData,
        'Backup file is corrupted and cannot be restored.',
      );
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('{')) {
      throw const DecryptionException(
        DecryptionFailureReason.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const DecryptionException(
        DecryptionFailureReason.corruptedData,
        'Backup file is corrupted and cannot be restored.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const DecryptionException(
        DecryptionFailureReason.invalidFormat,
        'This file is not a valid MorphCook backup.',
      );
    }

    return BackupPayload.fromJson(decoded);
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }
}
