import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/backup_codec.dart';
import '../models/profile.dart';
import 'library_store.dart';
import 'profile_controller.dart';

/// Builds, shares and restores backup files. The OS share sheet and file
/// picker are the only platform touch points — no cloud, no OAuth.
class BackupService {
  BackupService({required this.profile, required this.library, BackupCodec? codec}) : codec = codec ?? BackupCodec();

  final ProfileController profile;
  final LibraryStore library;
  final BackupCodec codec;

  Map<String, dynamic> buildDocument({DateTime? now}) => {
    'schema_version': backupSchemaVersion,
    'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'profile': profile.profile.toJson(),
    ...library.exportSnapshot(),
  };

  /// Writes both files to a temp folder and opens the share sheet.
  Future<BackupFiles> exportAndShare({String? password, Rect? origin}) async {
    final files = codec.encode(buildDocument(), password: password);
    final dir = Directory('${(await getTemporaryDirectory()).path}/backup');
    await dir.create(recursive: true);
    final jsonFile = File('${dir.path}/$backupJsonName');
    final gzFile = File('${dir.path}/$backupGzName');
    await jsonFile.writeAsBytes(files.json, flush: true);
    await gzFile.writeAsBytes(files.gzip, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(jsonFile.path, mimeType: files.encrypted ? 'application/octet-stream' : 'application/json'),
          XFile(gzFile.path, mimeType: 'application/gzip'),
        ],
        subject: 'MorphCook backup',
        sharePositionOrigin: origin,
      ),
    );
    return files;
  }

  /// Lets the user pick a file; returns its bytes or null if cancelled.
  Future<Uint8List?> pickFile() async {
    final file = await FilePicker.pickFile();
    return file?.readAsBytes();
  }

  /// Applies a decoded document (validated by [BackupCodec]).
  Future<void> apply(Map<String, dynamic> doc, ImportMode mode) async {
    final p = doc['profile'];
    if (p is Map) {
      final restored = Profile.fromJson(p.cast<String, dynamic>());
      if (mode == ImportMode.replace || !profile.profile.onboarded) {
        await profile.replace(restored.copyWith(onboarded: true));
      } else {
        // merge: keep the current profile, union the avoidances so a merge
        // never makes something visible that either profile excluded
        await profile.update(
          (cur) => cur.copyWith(
            avoidFlags: {...cur.avoidFlags, ...restored.avoidFlags},
            avoidIngredients: {...cur.avoidIngredients, ...restored.avoidIngredients},
          ),
        );
      }
    }
    await library.importSnapshot(doc, mode);
  }
}
