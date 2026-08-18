import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../models/backup_data.dart';
import '../models/cooking_history_item.dart';
import '../models/shopping_item.dart';

class DecryptionException implements Exception {
  final String message;
  final String reason;

  DecryptionException(this.message, {this.reason = 'unknown'});

  @override
  String toString() => message;
}

class BackupFilesResult {
  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
  final String jsonFileName;
  final String gzipFileName;
  final bool isEncrypted;

  BackupFilesResult({
    required this.jsonBytes,
    required this.gzipBytes,
    this.jsonFileName = 'morphcook-backup.json',
    this.gzipFileName = 'morphcook-backup.json.gz',
    this.isEncrypted = false,
  });
}

class BackupService {
  static const List<int> encMagicBytes = [0x45, 0x4E, 0x43]; // "ENC"
  static const List<int> gzipMagicBytes = [0x1F, 0x8B];

  /// Derive 256-bit AES key from password and salt using PBKDF2-HMAC-SHA256 with 10,000 iterations
  static Uint8List deriveKey(String password, Uint8List salt) {
    final derivator = KeyDerivator('SHA-256/HMAC/PBKDF2');
    final params = Pbkdf2Parameters(salt, 10000, 32);
    derivator.init(params);
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Encrypts bytes using AES-256-GCM
  static Uint8List encryptAesGcm(Uint8List plaintext, String password) {
    final secureRandom = Random.secure();
    final salt = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      salt[i] = secureRandom.nextInt(256);
    }

    final iv = Uint8List(12); // Standard 96-bit nonce for GCM
    for (int i = 0; i < 12; i++) {
      iv[i] = secureRandom.nextInt(256);
    }

    final key = deriveKey(password, salt);

    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
    cipher.init(true, params);

    final ciphertext = cipher.process(plaintext);

    final builder = BytesBuilder();
    builder.add(encMagicBytes);
    builder.add(salt);
    builder.add(iv);
    builder.add(ciphertext);

    return builder.toBytes();
  }

  /// Decrypts bytes with AES-256-GCM and verifies authentication tag
  static Uint8List decryptAesGcm(Uint8List encryptedBytes, String password) {
    if (encryptedBytes.length < 3 + 16 + 12 + 16) {
      throw DecryptionException(
        'This file is not a valid MorphCook backup.',
        reason: 'invalid_format',
      );
    }

    // Check magic bytes
    if (encryptedBytes[0] != encMagicBytes[0] ||
        encryptedBytes[1] != encMagicBytes[1] ||
        encryptedBytes[2] != encMagicBytes[2]) {
      throw DecryptionException(
        'This file is not a valid MorphCook backup.',
        reason: 'invalid_format',
      );
    }

    final salt = encryptedBytes.sublist(3, 19);
    final iv = encryptedBytes.sublist(19, 31);
    final ciphertext = encryptedBytes.sublist(31);

    try {
      final key = deriveKey(password, salt);
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(KeyParameter(key), 128, iv, Uint8List(0));
      cipher.init(false, params);

      return cipher.process(ciphertext);
    } catch (e) {
      if (e is InvalidCipherTextException || e.toString().contains('mac') || e.toString().contains('tag')) {
        throw DecryptionException(
          'Incorrect password. Please try again.',
          reason: 'wrong_password',
        );
      }
      throw DecryptionException(
        'Backup file is corrupted and cannot be restored.',
        reason: 'corrupted',
      );
    }
  }

  /// Export backup data to both JSON (encrypted if password provided) and GZip formats
  static BackupFilesResult exportBackup({
    required BackupData data,
    String? password,
  }) {
    final rawJsonString = jsonEncode(data.toJson());
    final rawJsonBytes = Uint8List.fromList(utf8.encode(rawJsonString));

    // GZip file is always compressed and unencrypted for universal compatibility
    final gzipBytes = Uint8List.fromList(gzip.encode(rawJsonBytes));

    Uint8List jsonOutputBytes;
    bool isEncrypted = false;

    if (password != null && password.trim().isNotEmpty) {
      jsonOutputBytes = encryptAesGcm(rawJsonBytes, password.trim());
      isEncrypted = true;
    } else {
      jsonOutputBytes = rawJsonBytes;
    }

    return BackupFilesResult(
      jsonBytes: jsonOutputBytes,
      gzipBytes: gzipBytes,
      isEncrypted: isEncrypted,
    );
  }

  /// Check if file bytes are encrypted (ENC magic header)
  static bool isEncryptedBytes(Uint8List bytes) {
    if (bytes.length < 3) return false;
    return bytes[0] == encMagicBytes[0] &&
        bytes[1] == encMagicBytes[1] &&
        bytes[2] == encMagicBytes[2];
  }

  /// Check if file bytes are GZip compressed
  static bool isGzipBytes(Uint8List bytes) {
    if (bytes.length < 2) return false;
    return bytes[0] == gzipMagicBytes[0] && bytes[1] == gzipMagicBytes[1];
  }

  /// Restores BackupData from arbitrary bytes (auto-detects GZip, Encrypted, or plain JSON)
  static BackupData restoreFromBytes({
    required Uint8List bytes,
    String? password,
  }) {
    Uint8List plainBytes;

    if (isEncryptedBytes(bytes)) {
      if (password == null || password.trim().isEmpty) {
        throw DecryptionException(
          'This backup is password protected. Please enter the password.',
          reason: 'password_required',
        );
      }
      plainBytes = decryptAesGcm(bytes, password.trim());
    } else if (isGzipBytes(bytes)) {
      try {
        plainBytes = Uint8List.fromList(gzip.decode(bytes));
      } catch (e) {
        throw DecryptionException(
          'Backup file is corrupted and cannot be restored.',
          reason: 'corrupted',
        );
      }
    } else {
      plainBytes = bytes;
    }

    try {
      final jsonString = utf8.decode(plainBytes);
      final jsonMap = jsonDecode(jsonString);
      if (jsonMap is! Map<String, dynamic>) {
        throw DecryptionException(
          'This file is not a valid MorphCook backup.',
          reason: 'invalid_format',
        );
      }

      final schemaVersion = jsonMap['schema_version'] as int? ?? 1;
      if (schemaVersion != 1) {
        throw DecryptionException(
          'Unsupported backup schema version: $schemaVersion',
          reason: 'unsupported_version',
        );
      }

      return BackupData.fromJson(jsonMap);
    } catch (e) {
      if (e is DecryptionException) rethrow;
      throw DecryptionException(
        'Backup file is corrupted and cannot be restored.',
        reason: 'corrupted',
      );
    }
  }

  /// Merges restored backup data into existing state (Merge mode)
  static BackupData mergeData({
    required BackupData current,
    required BackupData incoming,
  }) {
    // 1. Merge profile avoid flags and attributes
    final mergedProfile = current.profile.copyWith(
      avoidFlags: {...current.profile.avoidFlags, ...incoming.profile.avoidFlags},
      avoidIngredients: {...current.profile.avoidIngredients, ...incoming.profile.avoidIngredients},
      requiredAttributes: {...current.profile.requiredAttributes, ...incoming.profile.requiredAttributes},
    );

    // 2. Union saved recipes
    final mergedSaved = {...current.saved, ...incoming.saved}.toList();

    // 3. Merge meal plans
    final mergedMealPlan = <String, Map<String, String>>{};
    mergedMealPlan.addAll(current.mealPlan);
    incoming.mealPlan.forEach((week, slots) {
      if (!mergedMealPlan.containsKey(week)) {
        mergedMealPlan[week] = Map.from(slots);
      } else {
        mergedMealPlan[week] = {...mergedMealPlan[week]!, ...slots};
      }
    });

    // 4. Merge cooking history (dedup by recipeId + cookedAt timestamp)
    final historyMap = <String, CookingHistoryItem>{};
    for (final h in current.history) {
      historyMap['${h.recipeId}_${h.cookedAt.millisecondsSinceEpoch}'] = h;
    }
    for (final h in incoming.history) {
      historyMap['${h.recipeId}_${h.cookedAt.millisecondsSinceEpoch}'] = h;
    }
    final mergedHistory = historyMap.values.toList();
    mergedHistory.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));

    // 5. Merge shopping list
    final mergedShopping = List<ShoppingItem>.from(current.shoppingList);
    for (final item in incoming.shoppingList) {
      ShoppingItem.aggregateInto(mergedShopping, item);
    }

    // 6. Union content requests
    final mergedRequests = {...current.contentRequests, ...incoming.contentRequests}.toList();

    return BackupData(
      schemaVersion: 1,
      exportedAt: DateTime.now().toIso8601String(),
      profile: mergedProfile,
      saved: mergedSaved,
      mealPlan: mergedMealPlan,
      history: mergedHistory,
      shoppingList: mergedShopping,
      contentRequests: mergedRequests,
    );
  }
}
