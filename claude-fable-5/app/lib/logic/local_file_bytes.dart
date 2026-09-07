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

/// Serialize creation of native share copies with cache cleanup. A chooser
/// returning does not mean that its receiving app has read the file yet.
Future<void> _shareFileWork = Future<void>.value();

Future<T> withMorphCookShareFiles<T>(Future<T> Function() action) {
  final result = _shareFileWork.then((_) => action());
  _shareFileWork = result.then<void>(
    (_) {},
    onError: (Object _, StackTrace __) {},
  );
  return result;
}

/// Normal startup removes files older than a day and retains recent transfer
/// copies. Explicit reset can pass Duration.zero to remove all private copies.
Future<void> clearMorphCookTemporaryFilesIn(
  Directory temporaryDirectory, {
  Duration minimumAge = const Duration(days: 1),
  DateTime? now,
}) => withMorphCookShareFiles(() async {
  final cutoff = (now ?? DateTime.now()).subtract(minimumAge);
  Future<void> removeStale(FileSystemEntity entity) async {
    try {
      if (entity is Directory) {
        await for (final child in entity.list(followLinks: false)) {
          await removeStale(child);
        }
        // A fresh child protects the directory. Non-recursive removal also
        // handles another process creating a file during cleanup safely.
        await entity.delete();
      } else if (minimumAge == Duration.zero ||
          !(await entity.stat()).modified.isAfter(cutoff)) {
        await entity.delete();
      }
    } catch (_) {
      // Cleanup is best effort and must preserve files still in use.
    }
  }

  try {
    await for (final entity in temporaryDirectory.list(followLinks: false)) {
      final segments = entity.uri.pathSegments.where((s) => s.isNotEmpty);
      if (segments.isEmpty) continue;
      final name = segments.last;
      if (name == 'share_plus' ||
          name.startsWith('morphcook-export-') ||
          name == 'morphcook-backup.json' ||
          name == 'morphcook-backup.json.gz') {
        await removeStale(entity);
      }
    }
  } catch (_) {
    // The operating system may clean the cache concurrently.
  }
});
