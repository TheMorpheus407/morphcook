import '../../data/models/history_entry.dart';
import '../shopping/insights.dart';

/// Why reading a backup failed.
enum DecryptionFailure {
  /// The file is encrypted and no password was supplied.
  passwordRequired,
  wrongPassword,
  corrupted,
  invalidFormat,
  unsupportedVersion,
}

/// Thrown when a backup cannot be read. [message] is user-facing and
/// actionable; [reason] lets callers react (for example by asking for a password).
class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final DecryptionFailure reason;

  static const String wrongPasswordMessage = 'Incorrect password. Please try again.';
  static const String corruptedMessage = 'Backup file is corrupted and cannot be restored.';
  static const String invalidFormatMessage = 'This file is not a valid MorphCook backup.';
  static const String passwordRequiredMessage = 'This backup is password-protected. Enter its password to restore it.';
  static const String unsupportedVersionMessage =
      'This backup was created by a newer version of MorphCook. Please update the app.';

  String get message {
    switch (reason) {
      case DecryptionFailure.passwordRequired:
        return passwordRequiredMessage;
      case DecryptionFailure.wrongPassword:
        return wrongPasswordMessage;
      case DecryptionFailure.corrupted:
        return corruptedMessage;
      case DecryptionFailure.invalidFormat:
        return invalidFormatMessage;
      case DecryptionFailure.unsupportedVersion:
        return unsupportedVersionMessage;
    }
  }

  @override
  String toString() => 'DecryptionException(${reason.name}): $message';
}

/// The content of `morphcook-backup.json`.
///
/// The bundled corpus is never part of a backup: only the person's own data.
class BackupData {
  const BackupData({
    required this.exportedAt,
    required this.profile,
    this.schemaVersion = currentSchemaVersion,
    this.saved = const <String>[],
    this.savedAt = const <String, DateTime>{},
    this.mealPlan = const <String, Map<String, String>>{},
    this.history = const <HistoryEntry>[],
    this.contentRequests = const <String>[],
    this.shopping,
    this.shoppingHistory = const <ShoppingEvent>[],
    this.settings,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final DateTime exportedAt;
  final Map<String, dynamic> profile;

  /// Saved recipe ids (variants), oldest first.
  final List<String> saved;
  final Map<String, DateTime> savedAt;

  /// `{"2026-W16": {"mon.dinner": "recipe-id"}}`
  final Map<String, Map<String, String>> mealPlan;
  final List<HistoryEntry> history;

  /// Search queries that found nothing: the corpus team's wish list.
  final List<String> contentRequests;

  /// Optional extras: shopping list state, its event log and device settings.
  final Map<String, dynamic>? shopping;
  final List<ShoppingEvent> shoppingHistory;
  final Map<String, dynamic>? settings;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema_version': schemaVersion,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'profile': profile,
    'saved': saved,
    'saved_at': {for (final e in savedAt.entries) e.key: e.value.toUtc().toIso8601String()},
    'meal_plan': mealPlan,
    'history': [for (final h in history) h.toJson()],
    'content_requests': contentRequests,
    if (shopping != null) 'shopping': shopping,
    'shopping_history': [for (final e in shoppingHistory) e.toJson()],
    if (settings != null) 'settings': settings,
  };

  /// Validates `schema_version` and reads every section leniently.
  factory BackupData.fromJson(Map<String, dynamic> json) {
    final version = json['schema_version'];
    if (version is! int) throw const DecryptionException(DecryptionFailure.invalidFormat);
    if (version > currentSchemaVersion) throw const DecryptionException(DecryptionFailure.unsupportedVersion);
    final profile = json['profile'];
    if (profile is! Map) throw const DecryptionException(DecryptionFailure.invalidFormat);
    try {
      return BackupData(
        schemaVersion: version,
        exportedAt: DateTime.tryParse((json['exported_at'] as String?) ?? '') ?? DateTime.now().toUtc(),
        profile: profile.cast<String, dynamic>(),
        saved: (json['saved'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
        savedAt: {
          for (final e in ((json['saved_at'] as Map?) ?? const <String, dynamic>{}).entries)
            if (DateTime.tryParse(e.value.toString()) != null)
              e.key.toString(): DateTime.parse(e.value.toString()).toLocal(),
        },
        mealPlan: {
          for (final week in ((json['meal_plan'] as Map?) ?? const <String, dynamic>{}).entries)
            week.key.toString(): {for (final s in (week.value as Map).entries) s.key.toString(): s.value.toString()},
        },
        history: [
          for (final h in (json['history'] as List? ?? const <Object?>[]))
            HistoryEntry.fromJson((h as Map).cast<String, dynamic>()),
        ],
        contentRequests: (json['content_requests'] as List? ?? const <Object?>[]).map((e) => e.toString()).toList(),
        shopping: (json['shopping'] as Map?)?.cast<String, dynamic>(),
        shoppingHistory: [
          for (final e in (json['shopping_history'] as List? ?? const <Object?>[]))
            ShoppingEvent.fromJson((e as Map).cast<String, dynamic>()),
        ],
        settings: (json['settings'] as Map?)?.cast<String, dynamic>(),
      );
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
  }
}

/// How an import treats data that is already on the device.
enum ImportMode {
  /// Adds what is missing and never overwrites local data.
  merge,

  /// Replaces the person's data with the backup.
  replace,
}
