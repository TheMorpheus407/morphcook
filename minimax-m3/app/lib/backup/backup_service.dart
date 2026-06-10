import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/content_request_repository.dart';
import '../data/cookbook_repository.dart';
import '../data/history_repository.dart';
import '../data/meal_plan_repository.dart';
import '../data/profile_repository.dart';
import '../models/profile.dart';
import 'backup_encryption.dart';

/// Serializes the user state to the v1 backup payload, exports it to two
/// files (JSON + GZip) in the OS share sheet, and supports merge/replace
/// imports with auto-format detection (encrypted / gzipped / plain).
class BackupService {
  BackupService({
    required this.profileRepo,
    required this.cookbookRepo,
    required this.historyRepo,
    required this.mealPlanRepo,
    required this.contentRequestRepo,
  });

  static const schemaVersion = 1;

  final ProfileRepository profileRepo;
  final CookbookRepository cookbookRepo;
  final HistoryRepository historyRepo;
  final MealPlanRepository mealPlanRepo;
  final ContentRequestRepository contentRequestRepo;

  Map<String, dynamic> buildPayload() {
    return {
      'schema_version': schemaVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'profile': profileRepo.profile.toJson(),
      'saved': cookbookRepo.toBackup(),
      'meal_plan': mealPlanRepo.toBackup(),
      'history': historyRepo.toBackup(),
      'content_requests': contentRequestRepo.toBackup(),
    };
  }

  /// Export: writes two files into a temp directory and opens the OS share
  /// sheet. The JSON file is optionally encrypted if [password] is supplied;
  /// the GZip file is always unencrypted (per SPEC).
  Future<List<String>> exportToShare({String? password}) async {
    final payload = buildPayload();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    final dir = await getTemporaryDirectory();
    final jsonPath = '${dir.path}/morphcook-backup.json';
    final gzPath = '${dir.path}/morphcook-backup.json.gz';

    final jsonFile = File(jsonPath);
    if (password != null && password.isNotEmpty) {
      final encrypted = await BackupEncryption.encrypt(
        plaintext: jsonStr,
        password: password,
      );
      await jsonFile.writeAsBytes(encrypted, flush: true);
    } else {
      await jsonFile.writeAsString(jsonStr, flush: true);
    }

    // GZip is always plaintext for compatibility.
    final gz = GZipEncoder().encode(utf8.encode(jsonStr));
    await File(gzPath).writeAsBytes(gz, flush: true);

    final params = ShareParams(
      files: [XFile(jsonPath), XFile(gzPath)],
      subject: 'MorphCook backup',
    );
    await SharePlus.instance.share(params);
    return [jsonPath, gzPath];
  }

  /// Import: auto-detects ENC magic → GZip magic → plain JSON.
  /// Throws [DecryptionException] subclasses for typed UI handling.
  Future<Map<String, dynamic>> readBackupFile(
    File file, {
    String? password,
  }) async {
    final bytes = await file.readAsBytes();
    return readBackupBytes(bytes, password: password);
  }

  Future<Map<String, dynamic>> readBackupBytes(
    List<int> bytes, {
    String? password,
  }) async {
    if (BackupEncryption.isEncrypted(bytes)) {
      if (password == null || password.isEmpty) {
        throw const WrongPasswordException();
      }
      final plain = await BackupEncryption.decrypt(
        bytes: bytes,
        password: password,
      );
      return _parseJsonOrThrow(plain);
    }
    // GZip magic 0x1f 0x8b
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        final decoded = GZipDecoder().decodeBytes(bytes);
        return _parseJsonOrThrow(utf8.decode(decoded));
      } catch (_) {
        throw const CorruptedBackupException();
      }
    }
    // Plain JSON
    try {
      final str = utf8.decode(bytes);
      return _parseJsonOrThrow(str);
    } catch (_) {
      throw const InvalidBackupFormatException();
    }
  }

  Future<void> applyBackup(
    Map<String, dynamic> payload, {
    required bool replace,
  }) async {
    final ver = (payload['schema_version'] as num?)?.toInt() ?? 1;
    if (ver != schemaVersion) {
      // Future versions could migrate here; for v1 we accept ver 1 only.
    }

    final profileRaw = payload['profile'];
    if (profileRaw is Map<String, dynamic>) {
      final next = Profile.fromJson(profileRaw);
      await profileRepo.save(next.copyWith(onboarded: true));
    }

    final saved = payload['saved'];
    if (saved is List) {
      if (replace) {
        await cookbookRepo.replaceFromBackup(saved);
      } else {
        // Merge: keep existing, add new
        final existing = cookbookRepo.savedRecipeIds.toSet();
        for (final s in saved) {
          if (s is Map<String, dynamic>) {
            final id = s['recipe_id'] as String?;
            if (id != null && !existing.contains(id)) {
              await cookbookRepo.toggle(id);
            }
          }
        }
      }
    }

    final mp = payload['meal_plan'];
    if (mp is Map<String, dynamic>) {
      if (replace) {
        await mealPlanRepo.replaceFromBackup(mp);
      } else {
        // Merge weeks one by one
        final cur = mealPlanRepo.toBackup();
        final merged = Map<String, Map<String, String>>.from(
          cur.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map))),
        );
        mp.forEach((week, slots) {
          if (slots is! Map) return;
          merged.putIfAbsent(week, () => {});
          slots.forEach((slotKey, recipeId) {
            if (recipeId is String) {
              merged[week]![slotKey.toString()] = recipeId;
            }
          });
        });
        await mealPlanRepo.replaceFromBackup(merged);
      }
    }

    final hist = payload['history'];
    if (hist is List) {
      if (replace) {
        await historyRepo.replaceFromBackup(hist);
      } else {
        // Merge by recipeId+cookedAt timestamp
        final existing = historyRepo
            .all()
            .map((e) => '${e.recipeId}|${e.cookedAt.toIso8601String()}')
            .toSet();
        final merged = [
          ...historyRepo.all().map((e) => e.toJson()),
          ...hist.whereType<Map<String, dynamic>>().where((m) {
            final key = '${m['recipe_id']}|${m['cooked_at']}';
            return !existing.contains(key);
          }),
        ];
        await historyRepo.replaceFromBackup(merged);
      }
    }

    final reqs = payload['content_requests'];
    if (reqs is List) {
      if (replace) {
        await contentRequestRepo.replaceFromBackup(reqs);
      } else {
        final existing = contentRequestRepo.queries().toSet();
        for (final r in reqs) {
          final q = r is String
              ? r
              : (r is Map<String, dynamic> ? r['query'] as String? : null);
          if (q != null && !existing.contains(q.toLowerCase())) {
            await contentRequestRepo.add(q);
          }
        }
      }
    }
  }

  Map<String, dynamic> _parseJsonOrThrow(String s) {
    try {
      final decoded = jsonDecode(s);
      if (decoded is! Map<String, dynamic>) {
        throw const InvalidBackupFormatException();
      }
      if (decoded['schema_version'] == null) {
        throw const InvalidBackupFormatException();
      }
      return decoded;
    } on FormatException {
      throw const CorruptedBackupException();
    }
  }
}

/// Convenience: compress/decompress for analytics or testing.
Uint8List gzipString(String src) =>
    Uint8List.fromList(GZipEncoder().encode(utf8.encode(src)));

String gunzipString(List<int> bytes) =>
    utf8.decode(GZipDecoder().decodeBytes(bytes));
