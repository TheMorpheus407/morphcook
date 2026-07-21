import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_repository.dart';
import 'backup_service.dart';

class PickedBackupFile {
  const PickedBackupFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class BackupFileGateway {
  Future<PickedBackupFile?> pickBackup();
  Future<void> shareBackup(
    BackupExportBundle bundle, {
    Rect? sharePositionOrigin,
    String title = 'MorphCook backup',
    String? text,
  });
}

/// Platform implementation using only the OS file picker and share sheet.
class PlatformBackupFileGateway implements BackupFileGateway {
  const PlatformBackupFileGateway();

  @override
  Future<PickedBackupFile?> pickBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['json', 'gz'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.single;
    final bytes =
        picked.bytes ??
        (picked.path == null ? null : await File(picked.path!).readAsBytes());
    if (bytes == null) {
      throw const BackupFormatException(
        'The selected backup file could not be read.',
      );
    }
    return PickedBackupFile(name: picked.name, bytes: bytes);
  }

  @override
  Future<void> shareBackup(
    BackupExportBundle bundle, {
    Rect? sharePositionOrigin,
    String title = 'MorphCook backup',
    String? text,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final exportDirectory = await Directory(
      '${temporaryDirectory.path}/morphcook-backup-'
      '${DateTime.now().microsecondsSinceEpoch}',
    ).create(recursive: true);
    final jsonFile = File(
      '${exportDirectory.path}/${BackupExportBundle.jsonFileName}',
    );
    final gzipFile = File(
      '${exportDirectory.path}/${BackupExportBundle.gzipFileName}',
    );
    await Future.wait<File>(<Future<File>>[
      jsonFile.writeAsBytes(bundle.jsonBytes, flush: true),
      gzipFile.writeAsBytes(bundle.gzipBytes, flush: true),
    ]);

    try {
      await SharePlus.instance.share(
        ShareParams(
          title: title,
          subject: title,
          text: text,
          sharePositionOrigin: sharePositionOrigin,
          files: <XFile>[
            XFile(jsonFile.path, mimeType: 'application/json'),
            XFile(gzipFile.path, mimeType: 'application/gzip'),
          ],
        ),
      );
    } finally {
      if (await exportDirectory.exists()) {
        await exportDirectory.delete(recursive: true);
      }
    }
  }
}

class BackupFileFacade {
  const BackupFileFacade({required this.repository, required this.gateway});

  final BackupRepository repository;
  final BackupFileGateway gateway;

  Future<void> exportAndShare({
    String? password,
    Rect? sharePositionOrigin,
    String title = 'MorphCook backup',
    String? text,
  }) async {
    final bundle = await repository.export(password: password);
    await gateway.shareBackup(
      bundle,
      sharePositionOrigin: sharePositionOrigin,
      title: title,
      text: text,
    );
  }

  /// Returns null when the OS picker is cancelled.
  Future<BackupRestoreResult?> pickAndRestore({
    String? password,
    required RestoreMode mode,
  }) async {
    final file = await gateway.pickBackup();
    if (file == null) return null;
    return repository.restoreBytes(file.bytes, password: password, mode: mode);
  }
}
