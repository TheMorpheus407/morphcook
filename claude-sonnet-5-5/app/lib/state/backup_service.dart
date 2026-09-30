import 'dart:typed_data';

import '../data/models/profile.dart';
import '../domain/backup/backup_codec.dart';
import '../domain/backup/backup_models.dart';
import '../domain/plan/meal_plan.dart';
import 'catalog.dart';
import 'controllers/content_request_log.dart';
import 'controllers/cookbook_controller.dart';
import 'controllers/history_controller.dart';
import 'controllers/meal_plan_controller.dart';
import 'controllers/profile_controller.dart';
import 'controllers/shopping_controller.dart';

/// Both files of an export.
class BackupBundle {
  const BackupBundle({required this.json, required this.gzip, required this.encrypted});

  /// `morphcook-backup.json`: readable JSON, or the encrypted container when a password was set.
  final Uint8List json;

  /// `morphcook-backup.json.gz`: always unencrypted.
  final Uint8List gzip;
  final bool encrypted;

  String get jsonName => BackupCodec.jsonFileName;
  String get gzipName => BackupCodec.gzipFileName;
}

class ImportSummary {
  const ImportSummary({
    required this.saved,
    required this.planSlots,
    required this.history,
    required this.contentRequests,
    required this.profileApplied,
  });

  final int saved;
  final int planSlots;
  final int history;
  final int contentRequests;
  final bool profileApplied;
}

/// Turns the app's own data into a backup and back. The bundled corpus is never touched.
class BackupService {
  BackupService({
    required this.profile,
    required this.cookbook,
    required this.history,
    required this.mealPlan,
    required this.shopping,
    required this.contentRequests,
    BackupCodec? codec,
    Clock? clock,
  }) : codec = codec ?? BackupCodec(),
       _clock = clock ?? DateTime.now;

  final ProfileController profile;
  final CookbookController cookbook;
  final HistoryController history;
  final MealPlanController mealPlan;
  final ShoppingController shopping;
  final ContentRequestLog contentRequests;
  final BackupCodec codec;
  final Clock _clock;

  /// The current state as backup data.
  BackupData snapshot() {
    final saved = cookbook.saved.reversed.toList(); // oldest first
    return BackupData(
      exportedAt: _clock().toUtc(),
      profile: profile.profile.toJson(),
      saved: [for (final s in saved) s.recipeId],
      savedAt: {for (final s in saved) s.recipeId: s.savedAt},
      mealPlan: mealPlan.plan.toJson().map((k, v) => MapEntry(k, (v as Map).cast<String, String>())),
      history: history.entries.reversed.toList(),
      contentRequests: contentRequests.queries,
      shopping: shopping.exportState(),
      shoppingHistory: shopping.events,
      settings: profile.settings.toJson(),
    );
  }

  /// Writes both files. With a [password] the JSON file is AES-256-GCM
  /// encrypted; the GZip file stays unencrypted for compatibility.
  Future<BackupBundle> export({String? password}) async {
    final data = snapshot();
    final hasPassword = password != null && password.isNotEmpty;
    return BackupBundle(
      json: hasPassword ? await codec.encodeEncrypted(data, password) : codec.encodeJson(data),
      gzip: codec.encodeGzip(data),
      encrypted: hasPassword,
    );
  }

  /// Auto-detects encryption, GZip and plain JSON. Throws
  /// [DecryptionException] (`passwordRequired`) for an encrypted file; call
  /// [readEncrypted] with the password then.
  BackupData read(List<int> bytes) => codec.decode(bytes);

  Future<BackupData> readEncrypted(List<int> bytes, String password) => codec.decodeEncrypted(bytes, password);

  /// Applies a backup: [ImportMode.merge] adds what is missing and never
  /// overwrites local data, [ImportMode.replace] restores the backup as is.
  Future<ImportSummary> apply(BackupData data, ImportMode mode) async {
    final replace = mode == ImportMode.replace;

    var profileApplied = false;
    if (replace || !profile.onboarded) {
      final restored = Profile.fromJson(data.profile);
      await profile.setProfile(restored);
      if (data.settings != null) await profile.setSettings(AppSettings.fromJson(data.settings!));
      await profile.completeOnboarding(restored);
      profileApplied = true;
    }

    await cookbook.restore([
      for (var i = 0; i < data.saved.length; i++)
        SavedRecipe(
          recipeId: data.saved[i],
          // Without dates the list order (oldest first) is kept.
          savedAt:
              data.savedAt[data.saved[i]] ??
              data.exportedAt.toLocal().subtract(Duration(minutes: data.saved.length - i)),
        ),
    ], replace: replace);
    await history.restore(data.history, replace: replace);
    await mealPlan.restore(MealPlan(data.mealPlan), replace: replace);
    await contentRequests.restore(data.contentRequests, replace: replace);
    await shopping.restore(data.shopping, data.shoppingHistory, replace: replace);

    return ImportSummary(
      saved: data.saved.length,
      planSlots: data.mealPlan.values.fold<int>(0, (sum, week) => sum + week.length),
      history: data.history.length,
      contentRequests: data.contentRequests.length,
      profileApplied: profileApplied,
    );
  }
}
