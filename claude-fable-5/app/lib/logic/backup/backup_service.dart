import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../models/collections.dart';
import '../../models/profile.dart';
import 'crypto.dart';

const backupSchemaVersion = 1;

/// The full exportable state (SPEC "Backup format").
class BackupData {
  final Profile profile;
  final List<SavedRecipe> saved;
  final MealPlanData mealPlan;
  final List<HistoryEntry> history;
  final List<ShoppingItem> shoppingHistory;
  final List<String> contentRequests;

  const BackupData({
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    this.shoppingHistory = const [],
    this.contentRequests = const [],
  });

  Map<String, dynamic> toJson(DateTime exportedAt) => {
        'schema_version': backupSchemaVersion,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved.map((s) => s.recipeId).toList(),
        'saved_meta': saved.map((s) => s.toJson()).toList(),
        'meal_plan': mealPlan,
        'history': history.map((h) => h.toJson()).toList(),
        'shopping_history':
            shoppingHistory.map((s) => s.toJson()).toList(),
        if (contentRequests.isNotEmpty) 'content_requests': contentRequests,
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final version = json['schema_version'];
    if (version is! int || version > backupSchemaVersion || version < 1) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final profileJson = json['profile'];
    if (profileJson is! Map<String, dynamic>) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final savedMeta = json['saved_meta'] as List?;
    final saved = savedMeta != null
        ? savedMeta
            .map((e) => SavedRecipe.fromJson(e as Map<String, dynamic>))
            .toList()
        : (json['saved'] as List? ?? const [])
            .map((id) => SavedRecipe(
                recipeId: id as String,
                savedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)))
            .toList();
    return BackupData(
      profile: Profile.fromJson(profileJson),
      saved: saved,
      mealPlan: (json['meal_plan'] as Map<String, dynamic>? ?? const {}).map(
          (week, slots) => MapEntry(
              week,
              (slots as Map<String, dynamic>)
                  .map((slot, id) => MapEntry(slot, id as String)))),
      history: (json['history'] as List? ?? const [])
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      shoppingHistory: (json['shopping_history'] as List? ?? const [])
          .map((e) => ShoppingItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      contentRequests:
          List<String>.from(json['content_requests'] as List? ?? const []),
    );
  }
}

class ExportedBackup {
  /// `morphcook-backup.json` — encrypted bytes if a password was given,
  /// otherwise human-readable JSON.
  final Uint8List jsonFile;

  /// `morphcook-backup.json.gz` — always plain GZip (never encrypted),
  /// for compatibility.
  final Uint8List gzipFile;

  const ExportedBackup({required this.jsonFile, required this.gzipFile});
}

class BackupService {
  /// Builds both export files side by side.
  static ExportedBackup export(
    BackupData data, {
    String? password,
    DateTime? exportedAt,
  }) {
    final jsonText = const JsonEncoder.withIndent('  ')
        .convert(data.toJson(exportedAt ?? DateTime.now()));
    final plainBytes = utf8.encode(jsonText);

    final jsonFile = (password != null && password.isNotEmpty)
        ? encryptBackup(jsonText, password)
        : Uint8List.fromList(plainBytes);
    final gzipFile = Uint8List.fromList(gzip.encode(plainBytes));

    return ExportedBackup(jsonFile: jsonFile, gzipFile: gzipFile);
  }

  /// True when [bytes] need a password to import.
  static bool isEncrypted(List<int> bytes) => hasEncryptionMagic(bytes);

  /// Auto-detecting import: encryption magic first, then GZip magic, then
  /// plain JSON. Throws [DecryptionException] with a specific reason —
  /// `needsPassword` when an encrypted file is given without a password.
  static BackupData import(List<int> bytes, {String? password}) {
    String jsonText;
    if (hasEncryptionMagic(bytes)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionFailure.needsPassword);
      }
      jsonText = decryptBackup(bytes, password);
    } else if (hasGzipMagic(bytes)) {
      try {
        jsonText = utf8.decode(gzip.decode(bytes));
      } catch (_) {
        throw const DecryptionException(DecryptionFailure.corrupted);
      }
    } else {
      try {
        jsonText = utf8.decode(bytes);
      } catch (_) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
    }

    final dynamic decoded;
    try {
      decoded = json.decode(jsonText);
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    return BackupData.fromJson(decoded);
  }

  /// Merge strategy: union of saved/history/content requests, incoming
  /// meal-plan slots win per slot, incoming profile wins.
  static BackupData merge(BackupData current, BackupData incoming) {
    final savedIds = current.saved.map((s) => s.recipeId).toSet();
    final saved = [
      ...current.saved,
      ...incoming.saved.where((s) => !savedIds.contains(s.recipeId)),
    ];

    final mealPlan = <String, Map<String, String>>{
      for (final e in current.mealPlan.entries) e.key: {...e.value},
    };
    for (final week in incoming.mealPlan.entries) {
      mealPlan.putIfAbsent(week.key, () => {}).addAll(week.value);
    }

    final historyKeys = current.history
        .map((h) => '${h.recipeId}|${h.cookedAt.toIso8601String()}')
        .toSet();
    final history = [
      ...current.history,
      ...incoming.history.where((h) =>
          !historyKeys.contains('${h.recipeId}|${h.cookedAt.toIso8601String()}')),
    ];

    return BackupData(
      profile: incoming.profile,
      saved: saved,
      mealPlan: mealPlan,
      history: history,
      shoppingHistory: [
        ...current.shoppingHistory,
        ...incoming.shoppingHistory,
      ],
      contentRequests: {
        ...current.contentRequests,
        ...incoming.contentRequests,
      }.toList(),
    );
  }
}
