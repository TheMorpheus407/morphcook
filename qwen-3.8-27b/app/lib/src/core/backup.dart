import 'dart:convert';
import 'dart:typed_data';

import 'backup_crypt.dart';
import 'store.dart';

enum BackupFormat { plainJson, encryptedJson, gzip }

class BackupEngine {
  BackupEngine._();

  /// Detect format by magic bytes: ENC -> encrypted JSON, 0x1f 0x8b -> gzip,
  /// otherwise plain JSON.
  static BackupFormat detect(List<int> bytes) {
    if (BackupCrypto.looksEncrypted(bytes)) return BackupFormat.encryptedJson;
    if (bytes.length > 1 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      return BackupFormat.gzip;
    }
    // plain json: should start with '{'
    return BackupFormat.plainJson;
  }

  static Map<String, dynamic> encode(AppData data, DateTime? at) {
    final now = at ?? DateTime.now().toUtc();
    return {
      'schema_version': 1,
      'exported_at': now.toIso8601String(),
      'profile': data.profile.toJson(),
      'saved': data.saved,
      'meal_plan': data.mealPlan,
      'history': data.history
          .map((h) => {'recipe_id': h.recipeId, 'at_ms': h.atMs})
          .toList(),
      'content_requests': data.contentRequests.keys.toList(growable: false),
    };
  }

  /// Plain, human-readable JSON bytes (indented).
  static Uint8List toJsonBytes(AppData data) =>
      Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ')
          .convert(encode(data))));

  /// GZip-compressed JSON (always unencrypted, per spec).
  static Uint8List toGzipBytes(AppData data) {
    final json = toJsonBytes(data);
    return gzipDecode(gzipEncode(List<int>.of(json)));
  }

  /// Encrypted JSON (AES-256-GCM, PBKDF2 10k/SHA-256). [password] required.
  static Uint8List toEncryptedBytes(AppData data, String password) {
    if (password.isEmpty) {
      throw ArgumentError('password must not be empty');
    }
    return BackupCrypto.encrypt(toJsonBytes(data), password);
  }

  /// Decode according to detected format. Encrypted needs [password].
  /// Throws [DecryptionException] with an actionable reason on failure.
  static Map<String, dynamic> decode(List<int> bytes, {String? password}) {
    final format = detect(bytes);
    switch (format) {
      case BackupFormat.encryptedJson:
        final pass = password;
        if (pass == null || pass.isEmpty) {
          throw const DecryptionException(
              'wrong-password', 'A password is required for this backup.');
        }
        Uint8List plain;
        try {
          plain = BackupCrypto.decrypt(Uint8List.fromList(bytes), pass);
        } on DecryptionException {
          rethrow;
        }
        final text = utf8.decode(plain);
        final obj = _parseJson(text, format);
        return _validated(obj);
      case BackupFormat.gzip:
        final plain = gzipDecode(bytes);
        final obj = _parseJson(utf8.decode(plain), format);
        return _validated(obj);
      case BackupFormat.plainJson:
        final obj = _parseJson(utf8.decode(bytes), format);
        return _validated(obj);
    }
  }

  static Map<String, dynamic> _parseJson(String text, BackupFormat format) {
    final obj = jsonDecode(text);
    if (obj is! Map) {
      throw const DecryptionException('invalid-format');
    }
    return obj.cast<String, dynamic>();
  }

  static Map<String, dynamic> _validated(Map<String, dynamic> j) {
    final v = j['schema_version'];
    if (v is! int || v < 1 || v > 1) {
      throw const DecryptionException('corrupted');
    }
    if (j['profile'] is! Map) {
      throw const DecryptionException('corrupted');
    }
    return j;
  }

  /// Apply a decoded backup to a store, merge or replace.
  static Future<void> apply(
    AppStore store,
    Map<String, dynamic> backup, {
    required bool replace,
  }) async {
    final p = Profile.fromJson(
        (backup['profile'] as Map).cast<String, dynamic>());
    final savedRaw = (backup['saved'] as Map? ?? const {}).map(
        (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toInt()));
    final historyRaw = ((backup['history'] as List? ?? const []) as List)
        .map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return HistoryEntry(
              recipeId: m['recipe_id'] as String,
              atMs: (m['at_ms'] as num? ?? 0).toInt());
        })
        .toList();
    final planRaw = (backup['meal_plan'] as Map? ?? const {}).map((k, v) =>
        MapEntry(k.toString(), (v as Map).map((a, b) => MapEntry(a.toString(), b.toString()))));
    final requests = (backup['content_requests'] as List? ?? const [])
        .map(String.from)
        .toSet();

    final now = DateTime.now().millisecondsSinceEpoch;
    final cur = store.data;

    Profile merged = p;
    if (!replace) {
      // Keep current profile if present; backup profile only fills gaps.
      merged = cur.profile;
    }

    Map<String, int> mergedSaved;
    if (replace) {
      mergedSaved = savedRaw;
    } else {
      mergedSaved = <String, int>{...cur.saved};
      savedRaw.forEach((k, v) => mergedSaved.putIfAbsent(k, () => v));
    }

    List<HistoryEntry> mergedHistory;
    if (replace) {
      mergedHistory = historyRaw;
    } else {
      mergedHistory = [...cur.history];
      final seen = cur.history
          .map((h) => '${h.recipeId}@${h.atMs}')
          .toSet();
      for (final h in historyRaw) {
        if (seen.add('${h.recipeId}@${h.atMs}')) mergedHistory.add(h);
      }
      mergedHistory.sort((a, b) => b.atMs.compareTo(a.atMs));
      mergedHistory = mergedHistory.take(200).toList();
    }

    Map<String, Map<String, String>> mergedPlan;
    if (replace) {
      mergedPlan = planRaw;
    } else {
      mergedPlan = Map<String, Map<String, String>>.from(
          cur.mealPlan, growable: true);
      planRaw.forEach((week, slots) {
        mergedPlan.update(
            week,
            (cur2) => {...cur2, ...slots},
            ifAbsent: () => Map<String, String>.from(slots));
      });
    }

    Map<String, int> mergedRequests = cur.contentRequests;
    // content_requests are unioned (never lost), never clobbered
    {
      mergedRequests = <String, int>{...cur.contentRequests};
      for (final q in requests) {
        mergedRequests.putIfAbsent(q, () => now);
      }
    }

    store.setProfile(merged);
    // rebuild state with merged collections
    // AppStore exposes only profile; we emulate the rest via a full replace:
    // encode merge into a synthetic backup and re-run (idempotent):
    final merged = {
      'schema_version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'profile': merged.toJson(),
      'saved': mergedSaved,
      'history': mergedHistory
          .map((h) => {'recipe_id': h.recipeId, 'at_ms': h.atMs})
          .toList(),
      'meal_plan': mergedPlan,
      'content_requests': mergedRequests.keys.toList(growable: false),
    };
    // Use a dedicated store method to set the whole dataset.
    await store.replaceState(merged, keepProfile: true);
  }
}
