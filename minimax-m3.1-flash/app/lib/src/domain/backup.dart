import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/history.dart';
import '../models/meal_plan.dart';
import '../models/profile.dart';
import 'encryption.dart';

/// The backup document, exactly as it is written to disk.
///
/// ```json
/// {
///   "schema_version": 1,
///   "exported_at": "2026-04-18T12:00:00Z",
///   "profile": { … },
///   "saved": ["recipe-id-1"],
///   "meal_plan": { "2026-W16": { "mon.dinner": "recipe-id-3" } },
///   "history": [ … ],
///   "content_requests": ["pad thai"]
/// }
/// ```
class BackupDocument {
  const BackupDocument({
    required this.schemaVersion,
    required this.exportedAt,
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.contentRequests,
  });

  static const int currentSchemaVersion = 1;

  factory BackupDocument.fromJson(Map<String, dynamic> json) {
    final version = (json['schema_version'] as num?)?.toInt() ?? 0;
    if (version < 1 || version > currentSchemaVersion) {
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }

    return BackupDocument(
      schemaVersion: version,
      exportedAt:
          DateTime.tryParse('${json['exported_at']}') ?? DateTime.now(),
      profile: Profile.fromJson(
        (json['profile'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      saved: (json['saved'] as List<dynamic>? ?? <dynamic>[])
          .map((value) => '$value')
          .toList(growable: false),
      mealPlan: MealPlan.fromJson(
        (json['meal_plan'] as Map<String, dynamic>? ?? <String, dynamic>{}),
      ),
      history: (json['history'] as List<dynamic>? ?? <dynamic>[])
          .map((entry) => CookingEntry.fromJson(entry as Map<String, dynamic>))
          .toList(growable: false),
      contentRequests:
          (json['content_requests'] as List<dynamic>? ?? <dynamic>[])
              .map((value) => '$value')
              .toList(growable: false),
    );
  }

  final int schemaVersion;
  final DateTime exportedAt;
  final Profile profile;
  final List<String> saved;
  final MealPlan mealPlan;
  final List<CookingEntry> history;

  /// Search queries that returned no results — a signal about content gaps.
  final List<String> contentRequests;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schema_version': schemaVersion,
        'exported_at': exportedAt.toUtc().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved,
        'meal_plan': mealPlan.toJson(),
        'history': history.map((entry) => entry.toJson()).toList(),
        'content_requests': contentRequests,
      };

  String encode({bool pretty = true}) {
    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(toJson());
    }
    return jsonEncode(toJson());
  }
}

/// Thrown when a backup cannot be understood.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The result of inspecting raw backup bytes.
enum BackupFormat { plainJson, gzipped, encrypted, unknown }

/// Encodes, decodes and detects backup payloads.
abstract final class BackupCodec {
  const BackupCodec._();

  /// Detects the format of [bytes].
  ///
  /// Encryption is checked first, then GZip, then plain JSON.
  static BackupFormat detect(Uint8List bytes) {
    if (BackupEncryption.isEncrypted(bytes)) return BackupFormat.encrypted;
    if (BackupEncryption.isGZip(bytes)) return BackupFormat.gzipped;
    if (_looksLikeJson(bytes)) return BackupFormat.plainJson;
    return BackupFormat.unknown;
  }

  static bool _looksLikeJson(Uint8List bytes) {
    for (final byte in bytes) {
      if (byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D) {
        continue;
      }
      return byte == 0x7B || byte == 0x5B; // '{' or '['
    }
    return false;
  }

  /// Decodes a plain (unencrypted) backup payload.
  static BackupDocument decodePlain(Uint8List bytes) {
    try {
      final text = utf8.decode(bytes);
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const BackupFormatException(
          'This file is not a valid MorphCook backup.',
        );
      }
      return BackupDocument.fromJson(decoded);
    } on BackupFormatException {
      rethrow;
    } catch (_) {
      throw const BackupFormatException(
        'Backup file is corrupted and cannot be restored.',
      );
    }
  }

  /// Decodes a GZip-compressed backup payload.
  static BackupDocument decodeGZip(Uint8List bytes) {
    try {
      final compressed = gzip.decode(bytes);
      return decodePlain(Uint8List.fromList(compressed));
    } catch (_) {
      throw const BackupFormatException(
        'Backup file is corrupted and cannot be restored.',
      );
    }
  }

  /// Decodes an encrypted backup payload.
  ///
  /// Throws [DecryptionException] when the password is wrong or the file is
  /// damaged.
  static Future<BackupDocument> decodeEncrypted(
    Uint8List bytes,
    String password,
  ) async {
    final text = await BackupEncryption.decryptToString(bytes, password);
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }
    return BackupDocument.fromJson(decoded);
  }

  /// Decodes any payload, detecting the format automatically.
  ///
  /// Encrypted payloads raise a [DecryptionException] so the caller can
  /// prompt for the password and retry with [decodeEncrypted].
  static Future<BackupDocument> decodeAuto(Uint8List bytes) async {
    switch (detect(bytes)) {
      case BackupFormat.gzipped:
        return decodeGZip(bytes);
      case BackupFormat.plainJson:
        return decodePlain(bytes);
      case BackupFormat.encrypted:
        throw const DecryptionException(
          DecryptionFailure.invalidFormat,
          'This backup is password protected.',
        );
      case BackupFormat.unknown:
        throw const BackupFormatException(
          'This file is not a valid MorphCook backup.',
        );
    }
  }
}

/// The two files an export produces.
class BackupFiles {
  const BackupFiles({required this.jsonPath, required this.gzipPath});

  final String jsonPath;
  final String gzipPath;

  List<String> get paths => <String>[jsonPath, gzipPath];
}

/// Writes backup files to disk and hands them to the OS share sheet.
class BackupService {
  const BackupService();

  static const String jsonFileName = 'morphcook-backup.json';
  static const String gzipFileName = 'morphcook-backup.json.gz';

  /// Serialises the document into both file formats.
  ///
  /// The `.json` file is encrypted when a password is given; the `.gz` file
  /// always stays readable so it can be shared anywhere.
  ///
  /// [directory] overrides the destination — the app leaves it unset and
  /// gets the OS temp directory, the tests point it at a scratch folder.
  Future<BackupFiles> writeFiles(
    BackupDocument document, {
    String? password,
    Directory? directory,
  }) async {
    final target = directory ?? await getTemporaryDirectory();
    final stamp = document.exportedAt
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');

    final jsonPath = '${target.path}/$jsonFileName';
    final gzipPath = '${target.path}/$gzipFileName';

    final plain = document.encode();
    final jsonBytes = password == null || password.isEmpty
        ? Uint8List.fromList(utf8.encode(plain))
        : await BackupEncryption.encryptString(plain, password);

    await File(jsonPath).writeAsBytes(jsonBytes, flush: true);

    final compressed = gzip.encode(Uint8List.fromList(utf8.encode(plain)));
    await File(gzipPath).writeAsBytes(compressed, flush: true);

    // A timestamped copy makes repeated exports distinguishable.
    final archive = '${target.path}/morphcook-backup-$stamp.json.gz';
    await File(archive).writeAsBytes(compressed, flush: true);

    return BackupFiles(jsonPath: jsonPath, gzipPath: gzipPath);
  }

  /// Reads a backup file from disk.
  Future<Uint8List> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const BackupFormatException('The selected file could not be read.');
    }
    return file.readAsBytes();
  }
}
