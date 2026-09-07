// File-based backup/restore.
//
//   morphcook-backup.json     human-readable (encrypted when a password is set)
//   morphcook-backup.json.gz  GZip compressed (always unencrypted)
//
// Import auto-detects: "ENC" magic → encrypted; 0x1f 0x8b → gzip; else JSON.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../data/models/history_entry.dart';
import '../data/models/meal_plan.dart';
import '../data/models/profile.dart';
import '../data/models/shopping.dart';
import 'backup_crypto.dart';

export 'backup_crypto.dart' show DecryptionException, DecryptionReason;

const int kBackupSchemaVersion = 1;

enum BackupFormat { encrypted, gzip, json }

enum MergeMode { merge, replace }

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

class BackupData {
  BackupData({
    required this.exportedAt,
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    this.contentRequests = const [],
    this.savedAt = const {},
    this.shopping,
    this.schemaVersion = kBackupSchemaVersion,
  });

  final int schemaVersion;
  final DateTime exportedAt;
  final Profile profile;
  final List<String> saved;
  final MealPlan mealPlan;
  final List<HistoryEntry> history;

  /// Zero-result search queries, exported to inform corpus priorities.
  final List<String> contentRequests;

  /// Optional: when each saved recipe was saved (recipe id → ISO date).
  final Map<String, DateTime> savedAt;
  final ShoppingState? shopping;

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved,
        'meal_plan': mealPlan.toJson(),
        'history': history.map((h) => h.toJson()).toList(),
        'content_requests': contentRequests,
        'saved_at': {for (final e in savedAt.entries) e.key: e.value.toUtc().toIso8601String()},
        if (shopping != null) 'shopping': shopping!.toJson(),
      };

  factory BackupData.fromJson(Map<String, dynamic> j) {
    final version = j['schema_version'];
    if (version is! int) throw const BackupFormatException('missing schema_version');
    if (version > kBackupSchemaVersion) {
      throw BackupFormatException('backup schema $version is newer than this app supports ($kBackupSchemaVersion)');
    }
    final profileJson = j['profile'];
    if (profileJson is! Map) throw const BackupFormatException('missing profile');
    return BackupData(
      schemaVersion: version,
      exportedAt: DateTime.tryParse((j['exported_at'] as String?) ?? '') ?? DateTime.now(),
      profile: Profile.fromJson(profileJson.cast<String, dynamic>()),
      saved: ((j['saved'] as List?) ?? const []).cast<String>(),
      mealPlan: MealPlan.fromJson((j['meal_plan'] as Map?)?.cast<String, dynamic>()),
      history: ((j['history'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => HistoryEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      contentRequests: ((j['content_requests'] as List?) ?? const []).cast<String>(),
      savedAt: {
        for (final e in (((j['saved_at'] as Map?) ?? const {}).entries))
          if (DateTime.tryParse(e.value.toString()) != null) e.key.toString(): DateTime.parse(e.value.toString()),
      },
      shopping: j['shopping'] is Map ? ShoppingState.fromJson((j['shopping'] as Map).cast<String, dynamic>()) : null,
    );
  }
}

class BackupCodec {
  static const String jsonFileName = 'morphcook-backup.json';
  static const String gzipFileName = 'morphcook-backup.json.gz';

  static String encodeJsonString(BackupData data) => const JsonEncoder.withIndent('  ').convert(data.toJson());

  /// The `.json` file: plain, or encrypted when [password] is non-empty.
  static Uint8List encodeJson(BackupData data, {String? password}) {
    final bytes = Uint8List.fromList(utf8.encode(encodeJsonString(data)));
    if (password == null || password.isEmpty) return bytes;
    return BackupCrypto.encrypt(bytes, password);
  }

  /// The `.json.gz` file: always unencrypted for compatibility.
  static Uint8List encodeGzip(BackupData data) =>
      Uint8List.fromList(GZipCodec(level: 9).encode(utf8.encode(encodeJsonString(data))));

  static BackupFormat detectFormat(List<int> bytes) {
    if (BackupCrypto.isEncrypted(bytes)) return BackupFormat.encrypted;
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) return BackupFormat.gzip;
    return BackupFormat.json;
  }

  /// Decodes any of the three formats. Throws [DecryptionException] with
  /// `needsPassword` when the file is encrypted and no password was given.
  static BackupData decode(List<int> bytes, {String? password}) {
    final format = detectFormat(bytes);
    List<int> plain;
    switch (format) {
      case BackupFormat.encrypted:
        if (password == null || password.isEmpty) throw const DecryptionException(DecryptionReason.needsPassword);
        plain = BackupCrypto.decrypt(Uint8List.fromList(bytes), password);
      case BackupFormat.gzip:
        try {
          plain = GZipCodec().decode(bytes);
        } catch (_) {
          throw const BackupFormatException('This file is not a valid MorphCook backup.');
        }
      case BackupFormat.json:
        plain = bytes;
    }
    Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(plain));
    } catch (_) {
      throw const BackupFormatException('This file is not a valid MorphCook backup.');
    }
    if (parsed is! Map) throw const BackupFormatException('This file is not a valid MorphCook backup.');
    return BackupData.fromJson(parsed.cast<String, dynamic>());
  }

  /// Merge keeps everything local and adds what the backup brings; the
  /// backup's profile wins in both modes (a restore is an intentional act).
  static BackupData merge(BackupData current, BackupData incoming, MergeMode mode) {
    if (mode == MergeMode.replace) return incoming;
    final saved = <String>[...current.saved];
    for (final id in incoming.saved) {
      if (!saved.contains(id)) saved.add(id);
    }
    final plan = MealPlan.fromJson(current.mealPlan.toJson());
    for (final w in incoming.mealPlan.weeks.entries) {
      for (final s in w.value.entries) {
        plan.assign(w.key, s.key, s.value);
      }
    }
    final history = <HistoryEntry>[...current.history];
    final seen = {for (final h in history) '${h.recipeId}@${h.cookedAt.toUtc().toIso8601String()}'};
    for (final h in incoming.history) {
      if (seen.add('${h.recipeId}@${h.cookedAt.toUtc().toIso8601String()}')) history.add(h);
    }
    history.sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    final requests = <String>[...current.contentRequests];
    for (final q in incoming.contentRequests) {
      if (!requests.contains(q)) requests.add(q);
    }
    return BackupData(
      exportedAt: incoming.exportedAt,
      profile: incoming.profile,
      saved: saved,
      mealPlan: plan,
      history: history,
      contentRequests: requests,
      savedAt: {...current.savedAt, ...incoming.savedAt},
      shopping: incoming.shopping ?? current.shopping,
    );
  }
}
