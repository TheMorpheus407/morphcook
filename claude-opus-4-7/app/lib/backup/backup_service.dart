import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../data/profile_store.dart';
import '../data/cookbook_store.dart';
import '../data/meal_plan_store.dart';
import '../data/history_store.dart';
import '../data/content_requests_store.dart';
import '../models/profile.dart';
import '../models/meal_plan.dart';
import 'crypto.dart';

class BackupBundle {
  final File jsonFile;
  final File gzFile;
  final bool encrypted;
  const BackupBundle({
    required this.jsonFile,
    required this.gzFile,
    required this.encrypted,
  });
}

class ImportResult {
  final int savedAdded;
  final int historyAdded;
  final int weeksMerged;
  final int contentRequestsAdded;
  final bool replacedProfile;
  const ImportResult({
    required this.savedAdded,
    required this.historyAdded,
    required this.weeksMerged,
    required this.contentRequestsAdded,
    required this.replacedProfile,
  });
}

class BackupService {
  final ProfileStore profile;
  final CookbookStore cookbook;
  final MealPlanStore mealPlan;
  final HistoryStore history;
  final ContentRequestsStore contentRequests;

  BackupService({
    required this.profile,
    required this.cookbook,
    required this.mealPlan,
    required this.history,
    required this.contentRequests,
  });

  Map<String, dynamic> _payload() => {
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': profile.profile.toJson(),
        'saved': cookbook.savedRecipeIds,
        'meal_plan': mealPlan.all.map(
          (k, v) =>
              MapEntry(k, v.map((slot, e) => MapEntry(slot, e.toJson()))),
        ),
        'history': history.entries.map((e) => e.toJson()).toList(),
        'content_requests': contentRequests.queries,
      };

  /// Writes both human-readable and GZip files. JSON is encrypted iff
  /// [password] is provided; the GZip file is always plaintext gzip for
  /// compatibility.
  Future<BackupBundle> export({String? password}) async {
    final raw = json.encode(_payload());
    final dir = await getApplicationDocumentsDirectory();

    final encrypted = password != null && password.isNotEmpty;
    final jsonFile = File('${dir.path}/morphcook-backup.json');
    if (encrypted) {
      final cipher = await BackupCrypto.encryptJson(raw, password);
      await jsonFile.writeAsBytes(cipher, flush: true);
    } else {
      await jsonFile.writeAsString(raw, flush: true);
    }

    // GZip is always unencrypted plaintext per SPEC
    final gz = GZipEncoder().encode(utf8.encode(raw))!;
    final gzFile = File('${dir.path}/morphcook-backup.json.gz');
    await gzFile.writeAsBytes(gz, flush: true);

    return BackupBundle(
        jsonFile: jsonFile, gzFile: gzFile, encrypted: encrypted);
  }

  Future<void> shareBundle(BackupBundle b) async {
    await Share.shareXFiles([
      XFile(b.jsonFile.path),
      XFile(b.gzFile.path),
    ], text: 'MorphCook backup');
  }

  /// Auto-detect format: encrypted magic, then GZip magic.
  Future<ImportResult> importFromBytes(
    Uint8List bytes, {
    String? password,
    bool merge = true,
  }) async {
    String jsonStr;
    if (BackupCrypto.hasMagic(bytes)) {
      if (password == null || password.isEmpty) {
        throw DecryptionException(
            'wrong_password', 'This backup is encrypted. Provide a password.');
      }
      jsonStr = await BackupCrypto.decryptJson(bytes, password);
    } else if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      final decoded = GZipDecoder().decodeBytes(bytes);
      jsonStr = utf8.decode(decoded);
    } else {
      jsonStr = utf8.decode(bytes);
    }

    final Map<String, dynamic> data;
    try {
      data = json.decode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      throw DecryptionException('invalid_format',
          'This file is not a valid MorphCook backup.');
    }

    final schemaVersion = data['schema_version'];
    if (schemaVersion is! int || schemaVersion != 1) {
      throw DecryptionException('invalid_format',
          'Backup schema version is incompatible (got $schemaVersion).');
    }

    int savedAdded = 0, historyAdded = 0, weeksMerged = 0, contentReqAdded = 0;
    bool replacedProfile = false;

    // Profile: always replace (single-profile-per-install).
    if (data['profile'] is Map) {
      await profile.save(
        Profile.fromJson((data['profile'] as Map).cast<String, dynamic>()),
      );
      replacedProfile = true;
    }

    // Saved
    final saved = (data['saved'] as List?)?.cast<String>() ?? const [];
    if (merge) {
      for (final id in saved) {
        if (!cookbook.contains(id)) {
          await cookbook.add(id);
          savedAdded++;
        }
      }
    } else {
      await cookbook.replaceAll(saved);
      savedAdded = saved.length;
    }

    // Meal plan
    final mp = (data['meal_plan'] as Map?) ?? const {};
    if (merge) {
      for (final entry in mp.entries) {
        final week = (entry.value as Map);
        for (final slot in week.entries) {
          await mealPlan.setSlot(
            entry.key.toString(),
            slot.key.toString(),
            MealPlanEntry.fromJson(slot.value),
          );
        }
        weeksMerged++;
      }
    } else {
      final imported = <String, MealPlanWeek>{};
      for (final entry in mp.entries) {
        final week = <String, MealPlanEntry>{};
        for (final slot in (entry.value as Map).entries) {
          week[slot.key.toString()] = MealPlanEntry.fromJson(slot.value);
        }
        imported[entry.key.toString()] = week;
      }
      await mealPlan.replaceAll(imported);
      weeksMerged = imported.length;
    }

    // History
    final hist = (data['history'] as List?) ?? const [];
    final histEntries =
        hist.map((e) => HistoryEntry.fromJson((e as Map).cast<String, dynamic>())).toList();
    if (merge) {
      final existing =
          history.entries.map((e) => '${e.recipeId}|${e.cookedAt.toIso8601String()}').toSet();
      for (final h in histEntries) {
        final key = '${h.recipeId}|${h.cookedAt.toIso8601String()}';
        if (!existing.contains(key)) {
          await history.record(h.recipeId,
              servings: h.servings, at: h.cookedAt);
          historyAdded++;
        }
      }
    } else {
      await history.replaceAll(histEntries);
      historyAdded = histEntries.length;
    }

    // Content requests
    final cr = (data['content_requests'] as List?)?.cast<String>() ?? const [];
    if (merge) {
      final existing = contentRequests.queries.toSet();
      for (final q in cr) {
        if (!existing.contains(q.toLowerCase())) {
          await contentRequests.record(q);
          contentReqAdded++;
        }
      }
    } else {
      await contentRequests.replaceAll(cr);
      contentReqAdded = cr.length;
    }

    return ImportResult(
      savedAdded: savedAdded,
      historyAdded: historyAdded,
      weeksMerged: weeksMerged,
      contentRequestsAdded: contentReqAdded,
      replacedProfile: replacedProfile,
    );
  }
}
