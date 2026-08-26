/// File-based backup/restore:
/// - export: writes `morphcook-backup.json` (encrypted if a password is
///   set) and `morphcook-backup.json.gz` (always plain, GZip-compressed)
///   to a temp dir and hands both to the OS share sheet.
/// - import: auto-detects encrypted (ENC magic) vs GZip vs plain JSON.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams, XFile;

import '../state/store.dart';
import 'backup_crypt.dart';

class NoFileException implements Exception {
  const NoFileException();
}

class BackupService {
  BackupService(this.store);
  final AppStore store;

  // ---- export --------------------------------------------------------------

  /// Returns the two exported file paths.
  Future<(String, String)> export({String? password}) async {
    final payload = store.backupSnapshot();
    final jsonText = const JsonEncoder.withIndent('  ').convert(payload);
    final jsonBytes = utf8.encode(jsonText);

    final base = DateTime.now().toIso8601String().replaceAll(RegExp(r':'), '-');
    final dir = await Directory.systemTemp.createTemp('morphcook-backup-$base');

    File jsonFile;
    if (password != null && password.isNotEmpty) {
      final blob = encryptBackup(jsonBytes, password);
      jsonFile = File('${dir.path}/morphcook-backup.json')
        ..writeAsBytesSync(blob);
    } else {
      jsonFile = File('${dir.path}/morphcook-backup.json')
        ..writeAsStringSync(jsonText);
    }

    // gz is always plain JSON, compressed (spec).
    final gzFile = File('${dir.path}/morphcook-backup.json.gz')
      ..writeAsBytesSync(const GZipEncoder().encodeBytes(jsonBytes));

    try {
      await SharePlus.instance.share(ShareParams(
        files: [XFile(jsonFile.path), XFile(gzFile.path)],
        title: 'MorphCook backup',
        text: 'morphcook-backup.json'
            '${password == null || password.isEmpty ? '' : ' (encrypted)'}'
            ' + morphcook-backup.json.gz',
      ));
    } catch (_) {
      // share sheet unavailable (e.g. test bed): files remain on disk
    }
    return (jsonFile.path, gzFile.path);
  }

  // ---- import ----------------------------------------------------------------

  /// Reads + decodes a backup file; returns the payload map.
  /// [password] is required iff the file is an encrypted blob.
  Map<String, dynamic> decodeFileBytes(
    List<int> bytes, {
    String? password,
  }) {
    if (isEncryptedBlob(bytes)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException('wrong-password');
      }
      final plain =
          decryptBackup(Uint8List.fromList(bytes), password);
      return _parseJson(plain);
    }
    if (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8B) {
      final plain = Uint8List.fromList(
        const GZipDecoder().decodeBytes(bytes),
      );
      return _parseJson(plain);
    }
    // plain JSON
    return _parseJson(bytes);
  }

  Map<String, dynamic> _parseJson(List<int> bytes) {
    final text = utf8.decode(bytes);
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const DecryptionException('corrupted');
    }
    if (decoded is! Map) {
      throw const DecryptionException('invalid-format');
    }
    if ((decoded['schema_version'] as num?)?.toInt() != 1) {
      throw const DecryptionException('invalid-format');
    }
    if (decoded['profile'] is! Map) {
      throw const DecryptionException('invalid-format');
    }
    return decoded.map((k, v) => MapEntry(k.toString(), v));
  }
}

/// Pick + decode via the OS file picker; returns the payload map.
Future<Map<String, dynamic>> pickAndDecode(
  AppStore store, {
  String? password,
}) async {
  final svc = BackupService(store);
  final f = await FilePicker.pickFile(type: FileType.any);
  if (f == null) {
    throw const NoFileException();
  }
  final path = f.path;
  final bytes = path == null ? await f.readAsBytes() : await File(path).readAsBytes();
  return svc.decodeFileBytes(bytes, password: password);
}
