import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class LocalFileTooLargeException implements Exception {
  const LocalFileTooLargeException();
}

/// Reads a picker result while enforcing the limit before and during I/O.
/// `withReadStream` avoids eagerly materializing an arbitrarily large file.
Future<Uint8List> readPickedFileBytes(
  PlatformFile file, {
  required int maxBytes,
}) async {
  if (file.size > maxBytes) throw const LocalFileTooLargeException();

  final memoryBytes = file.bytes;
  if (memoryBytes != null) {
    if (memoryBytes.length > maxBytes) {
      throw const LocalFileTooLargeException();
    }
    return Uint8List.fromList(memoryBytes);
  }

  final stream = file.readStream;
  if (stream != null) {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in stream) {
      length += chunk.length;
      if (length > maxBytes) throw const LocalFileTooLargeException();
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  final path = file.path;
  if (path == null) {
    throw const FileSystemException('Picked file is unreadable');
  }
  final source = File(path);
  if (await source.length() > maxBytes) {
    throw const LocalFileTooLargeException();
  }
  final bytes = await source.readAsBytes();
  if (bytes.length > maxBytes) throw const LocalFileTooLargeException();
  return bytes;
}

/// The picker creates private cache copies on Android/iOS. Once bytes have
/// been copied into MorphCook storage, those transient files are unnecessary.
Future<void> clearPickerTemporaryFiles() async {
  try {
    await FilePicker.clearTemporaryFiles();
  } on UnimplementedError {
    // Desktop/web implementations do not expose a picker cache.
  } catch (_) {
    // Cleanup is best-effort and must not turn a successful import into an
    // error on a platform with a partially implemented picker plugin.
  }
}

/// Removes backup artifacts created by MorphCook and by share_plus from the
/// app-private cache directory. Android's share implementation copies every
/// shared XFile into a `share_plus` child directory, so deleting only the
/// source export would otherwise leave a complete backup behind.
Future<void> clearMorphCookTemporaryFilesIn(
  Directory temporaryDirectory,
) async {
  try {
    await for (final entity in temporaryDirectory.list()) {
      final segments = entity.uri.pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.isEmpty) continue;
      final name = segments.last;
      if (name != 'share_plus' &&
          !name.startsWith('morphcook-export-') &&
          name != 'morphcook-backup.json' &&
          name != 'morphcook-backup.json.gz') {
        continue;
      }
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // Cache cleanup is best-effort; another process may remove it first.
      }
    }
  } catch (_) {
    // A platform may clean or replace its cache directory concurrently.
  }
}
