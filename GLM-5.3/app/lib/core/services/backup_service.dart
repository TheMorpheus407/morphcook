import 'dart:convert';
import 'dart:io';

import '../models/profile.dart';
import '../models/user_data.dart';
import 'backup_crypto.dart';

/// The data a backup carries (SPEC schema): `schema_version`, `exported_at`,
/// `profile`, `saved`, `meal_plan`, `history`, `content_requests`.
class BackupPayload {
  BackupPayload({
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.contentRequests,
  });

  final Profile profile;
  final List<String> saved;
  final Map<String, dynamic> mealPlan;
  final List<HistoryEntry> history;
  final List<ContentRequest> contentRequests;

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved,
        'meal_plan': mealPlan,
        'history': history.map((e) => e.toJson()).toList(),
        'content_requests': contentRequests.map((e) => e.toJson()).toList(),
      };
}

/// What the import should do with existing data (SPEC: merge or replace,
/// user choice; the bundled corpus is never touched).
enum ImportMode { merge, replace }

/// File-based backup/restore (SPEC): writes `morphcook-backup.json`
/// (human-readable; encrypted when a password is given) and
/// `morphcook-backup.json.gz` (GZip, always unencrypted) for the OS share
/// sheet; import auto-detects encrypted / gzipped / plain formats.
class BackupService {
  static const int schemaVersion = 1;
  static const jsonFileName = 'morphcook-backup.json';
  static const gzipFileName = 'morphcook-backup.json.gz';

  /// GZip magic bytes `0x1f 0x8b`.
  static bool isGzip(List<int> bytes) =>
      bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

  /// Builds the human-readable JSON document.
  static String buildJson(BackupPayload payload) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(payload.toJson());
  }

  /// Builds the export pair: `[jsonBytes, gzipBytes]`. When [password] is
  /// given the JSON bytes are AES-256-GCM encrypted (magic `ENC`); the GZip
  /// copy always stays unencrypted for compatibility (SPEC).
  static BackupExport buildExport(BackupPayload payload, {String? password}) {
    final json = buildJson(payload);
    final gzip = GZipCodec().encode(utf8.encode(json));
    final List<int> jsonBytes = password == null || password.isEmpty
        ? utf8.encode(json)
        : BackupCrypto.encrypt(json, password);
    return BackupExport(jsonBytes: jsonBytes, gzipBytes: gzip);
  }
  /// Auto-detecting import. Order: encrypted magic → gzip magic → plain
  /// JSON. Encrypted payloads throw [DecryptionException] with
  /// [DecryptionReason.needsPassword] — the caller prompts and retries with
  /// [importEncrypted].
  static BackupDocument importBytes(List<int> bytes) {
    if (BackupCrypto.isEncrypted(bytes)) {
      throw const DecryptionException(DecryptionReason.needsPassword);
    }
    String json;
    if (isGzip(bytes)) {
      try {
        json = utf8.decode(GZipCodec().decode(bytes));
      } catch (_) {
        throw const DecryptionException(DecryptionReason.corrupted);
      }
    } else {
      json = utf8.decode(bytes);
    }
    return parseDocument(json);
  }

  /// Encrypted import path after the password prompt.
  static BackupDocument importEncrypted(List<int> bytes, String password) {
    if (!BackupCrypto.isEncrypted(bytes)) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    final json = BackupCrypto.decrypt(bytes, password);
    return parseDocument(json);
  }

  /// Validates `schema_version` and parses the document fields.
  static BackupDocument parseDocument(String json) {
    Map<String, dynamic> map;
    try {
      map = jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    final version = map['schema_version'];
    if (version is! num || version.toInt() != schemaVersion) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    return BackupDocument(
      exportedAt: DateTime.tryParse(map['exported_at']?.toString() ?? '') ?? DateTime.now(),
      profile: Profile.fromJson((map['profile'] as Map?)?.cast<String, dynamic>() ?? {}),
      saved: ((map['saved'] as List?) ?? const []).map((e) => e.toString()).toList(),
      mealPlan: (map['meal_plan'] as Map?)?.cast<String, dynamic>() ?? {},
      history: ((map['history'] as List?) ?? const [])
          .map((e) => HistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      contentRequests: ((map['content_requests'] as List?) ?? const [])
          .map((e) => ContentRequest.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// The two files handed to the OS share sheet.
class BackupExport {
  BackupExport({required this.jsonBytes, required this.gzipBytes});

  final List<int> jsonBytes;
  final List<int> gzipBytes;

  double get compressionRatio => jsonBytes.isEmpty ? 0 : gzipBytes.length / jsonBytes.length;
}

/// A parsed, schema-validated backup document.
class BackupDocument {
  BackupDocument({
    required this.exportedAt,
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.contentRequests,
  });

  final DateTime exportedAt;
  final Profile profile;
  final List<String> saved;
  final Map<String, dynamic> mealPlan;
  final List<HistoryEntry> history;
  final List<ContentRequest> contentRequests;
}

/// Writes both export files into [dir] and returns their paths (the caller
/// hands them to the OS share sheet).
Future<List<String>> writeExportFiles(Directory dir, BackupExport export) async {
  final jsonFile = File('${dir.path}/${BackupService.jsonFileName}');
  final gzipFile = File('${dir.path}/${BackupService.gzipFileName}');
  await jsonFile.writeAsBytes(export.jsonBytes);
  await gzipFile.writeAsBytes(export.gzipBytes);
  return [jsonFile.path, gzipFile.path];
}
