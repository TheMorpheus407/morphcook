import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';

class DecryptionException implements Exception {
  final String message;
  DecryptionException(this.message);
  @override
  String toString() => message;
}

class BackupService {
  // Magic bytes
  static final Uint8List magicEnc = Uint8List.fromList([0x45, 0x4E, 0x43]); // "ENC"
  static final Uint8List magicGzip = Uint8List.fromList([0x1F, 0x8B]); // Gzip header

  /// Creates a backup map from the current state of the AppProvider
  static Map<String, dynamic> createBackupData(AppProvider provider) {
    return {
      "schema_version": 1,
      "exported_at": DateTime.now().toIso8601String(),
      "profile": provider.profile.toJson(),
      "saved": provider.savedRecipeIds.toList(),
      "meal_plan": provider.mealPlan,
      "history": provider.cookingHistory,
      "content_requests": provider.contentRequests,
    };
  }

  /// Restores the backup data into the AppProvider
  static void restoreBackupData(AppProvider provider, Map<String, dynamic> data, {bool merge = false}) {
    if (data['schema_version'] != 1) {
      throw DecryptionException("This file is not a valid MorphCook backup.");
    }

    try {
      final profileData = data['profile'];
      final savedData = data['saved'] as List?;
      final mealPlanData = data['meal_plan'] as Map?;
      final historyData = data['history'] as List?;
      final contentReqs = data['content_requests'] as List?;

      if (profileData != null) {
        final importedProfile = UserProfile.fromJson(Map<String, dynamic>.from(profileData));
        if (merge) {
          // Merge avoid flags, avoidance list
          provider.profile.avoidFlags.addAll(importedProfile.avoidFlags);
          provider.profile.avoidIngredients.addAll(importedProfile.avoidIngredients);
          provider.profile.requiredAttributes.addAll(importedProfile.requiredAttributes);
        } else {
          provider.profile = importedProfile;
        }
      }

      if (savedData != null) {
        final List<String> importedSaved = List<String>.from(savedData);
        if (merge) {
          provider.savedRecipeIds.addAll(importedSaved);
        } else {
          provider.savedRecipeIds = importedSaved.toSet();
        }
      }

      if (mealPlanData != null) {
        final Map<String, Map<String, String>> importedMealPlan = {};
        mealPlanData.forEach((week, slots) {
          final Map<String, dynamic> slotsMap = slots;
          importedMealPlan[week.toString()] = slotsMap.map((slot, recipeId) => MapEntry(slot.toString(), recipeId.toString()));
        });

        if (merge) {
          importedMealPlan.forEach((week, slots) {
            if (!provider.mealPlan.containsKey(week)) {
              provider.mealPlan[week] = {};
            }
            provider.mealPlan[week]!.addAll(slots);
          });
        } else {
          provider.mealPlan = importedMealPlan;
        }
      }

      if (historyData != null) {
        final List<Map<String, dynamic>> importedHistory = historyData.map((x) => Map<String, dynamic>.from(x)).toList();
        if (merge) {
          provider.cookingHistory.addAll(importedHistory);
        } else {
          provider.cookingHistory = importedHistory;
        }
      }

      if (contentReqs != null) {
        final List<String> importedReqs = List<String>.from(contentReqs);
        if (merge) {
          for (var r in importedReqs) {
            if (!provider.contentRequests.contains(r)) {
              provider.contentRequests.add(r);
            }
          }
        } else {
          provider.contentRequests = importedReqs;
        }
      }

      // Persist the changes
      provider.saveProfile();
      provider.saveSavedRecipes();
      provider.saveMealPlan();
      provider.saveCookingHistory();
      provider.saveContentRequests();
    } catch (e) {
      throw DecryptionException("Backup file is corrupted and cannot be restored.");
    }
  }

  /// Encrypts raw JSON string to AES-256-GCM format
  static Uint8List encryptGCM(String plainText, String password) {
    // 1. Generate salt and IV
    final rand = Random.secure();
    final salt = Uint8List(16);
    final iv = Uint8List(12);
    for (int i = 0; i < 16; i++) salt[i] = rand.nextInt(256);
    for (int i = 0; i < 12; i++) iv[i] = rand.nextInt(256);

    // 2. Derive key using PBKDF2
    final key = _deriveKey(password, salt);

    // 3. Encrypt
    final plainBytes = Uint8List.fromList(utf8.encode(plainText));
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    
    final encryptedBytes = cipher.process(plainBytes);

    // 4. Concatenate: MAGIC (3) + SALT (16) + IV (12) + CIPHERTEXT
    final result = BytesBuilder();
    result.add(magicEnc);
    result.add(salt);
    result.add(iv);
    result.add(encryptedBytes);
    return result.toBytes();
  }

  /// Decrypts AES-256-GCM bytes back to raw JSON string
  static String decryptGCM(Uint8List encryptedData, String password) {
    if (encryptedData.length < 3 + 16 + 12 + 16) {
      throw DecryptionException("This file is not a valid MorphCook backup.");
    }

    // 1. Verify magic bytes
    if (encryptedData[0] != magicEnc[0] || encryptedData[1] != magicEnc[1] || encryptedData[2] != magicEnc[2]) {
      throw DecryptionException("This file is not a valid MorphCook backup.");
    }

    // 2. Extract salt and IV
    final salt = encryptedData.sublist(3, 19);
    final iv = encryptedData.sublist(19, 31);
    final cipherText = encryptedData.sublist(31);

    // 3. Derive key using PBKDF2
    final key = _deriveKey(password, salt);

    // 4. Decrypt
    try {
      final cipher = GCMBlockCipher(AESEngine());
      cipher.init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
      final plainBytes = cipher.process(cipherText);
      return utf8.decode(plainBytes);
    } on InvalidCipherTextException {
      throw DecryptionException("Incorrect password. Please try again.");
    } on ArgumentError {
      throw DecryptionException("Incorrect password. Please try again.");
    } catch (e) {
      throw DecryptionException("Backup file is corrupted and cannot be restored.");
    }
  }

  /// Compresses a JSON string using GZip
  static Uint8List compressGZip(String plainText) {
    final plainBytes = utf8.encode(plainText);
    return Uint8List.fromList(gzip.encode(plainBytes));
  }

  /// Decompresses a GZip byte array to a JSON string
  static String decompressGZip(Uint8List compressedData) {
    try {
      final decompressedBytes = gzip.decode(compressedData);
      return utf8.decode(decompressedBytes);
    } catch (e) {
      throw DecryptionException("Backup file is corrupted and cannot be restored.");
    }
  }

  /// Helper for PBKDF2 key derivation (10,000 iterations, SHA-256, 32-byte key)
  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(Pbkdf2Parameters(salt, 10000, 32));
    return derivator.process(Uint8List.fromList(utf8.encode(password)));
  }

  /// Auto-detects the format (Encrypted or GZzipped) and returns the JSON string
  static String parseBackupBytes(Uint8List data, {String? password}) {
    // Check if Encrypted first
    if (data.length >= 3 && data[0] == magicEnc[0] && data[1] == magicEnc[1] && data[2] == magicEnc[2]) {
      if (password == null || password.isEmpty) {
        throw DecryptionException("PASSWORD_REQUIRED");
      }
      return decryptGCM(data, password);
    }

    // Check if GZzipped
    if (data.length >= 2 && data[0] == magicGzip[0] && data[1] == magicGzip[1]) {
      return decompressGZip(data);
    }

    // Otherwise assume raw JSON string
    try {
      return utf8.decode(data);
    } catch (_) {
      throw DecryptionException("This file is not a valid MorphCook backup.");
    }
  }
}
