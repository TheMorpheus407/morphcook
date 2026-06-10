import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/backup_codec.dart';
import 'stores.dart';

enum ImportMode { merge, replace }

/// Builds, shares and restores the file-based backup. No cloud, no OAuth.
class BackupService {
  BackupService(this.services);
  final Services services;

  /// The full backup document (matches the SPEC backup format).
  Map<String, dynamic> buildBackup({DateTime? at}) {
    return {
      'schema_version': 1,
      'exported_at': (at ?? DateTime.now()).toUtc().toIso8601String(),
      'profile': services.profile.profile.toJson(),
      'saved': services.cookbook.exportSaved(),
      'meal_plan': services.mealPlan.exportPlan(),
      'history': services.history.exportHistory(),
      'content_requests': services.contentRequests.queries(),
    };
  }

  /// Write both artifacts to a temp dir and hand them to the OS share sheet.
  /// JSON is encrypted when [password] is set; the .gz stays unencrypted.
  Future<List<String>> exportToShareSheet({String? password}) async {
    final artifacts = BackupCodec.encode(buildBackup(), password: password);
    final dir = await getTemporaryDirectory();
    final jsonPath = '${dir.path}/morphcook-backup.json';
    final gzPath = '${dir.path}/morphcook-backup.json.gz';
    await File(jsonPath).writeAsBytes(artifacts.json);
    await File(gzPath).writeAsBytes(artifacts.gzip);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(jsonPath), XFile(gzPath)],
        text: 'MorphCook backup',
      ),
    );
    return [jsonPath, gzPath];
  }

  /// Decode a backup file's bytes (auto-detects gzip / encryption). Throws
  /// [DecryptionException] when encrypted-without-password or on failure.
  Map<String, dynamic> decode(List<int> bytes, {String? password}) =>
      BackupCodec.decode(Uint8List.fromList(bytes), password: password);

  /// Apply a decoded backup to all services.
  Future<void> apply(Map<String, dynamic> backup, ImportMode mode) async {
    final replace = mode == ImportMode.replace;
    if (backup['profile'] is Map) {
      await services.profile
          .replaceFromJson(Map<String, dynamic>.from(backup['profile'] as Map));
    }
    if (backup['saved'] is List) {
      await services.cookbook
          .importSaved((backup['saved'] as List).cast<String>(), replace: replace);
    }
    if (backup['meal_plan'] is Map) {
      await services.mealPlan.importPlan(
          Map<String, dynamic>.from(backup['meal_plan'] as Map),
          replace: replace);
    }
    if (backup['history'] is List) {
      await services.history
          .importHistory(backup['history'] as List, replace: replace);
    }
    if (backup['content_requests'] is List) {
      await services.contentRequests
          .import(backup['content_requests'] as List, replace: replace);
    }
  }
}
