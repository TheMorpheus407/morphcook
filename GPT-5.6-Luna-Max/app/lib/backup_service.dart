import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'store.dart';

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupBundle {
  const BackupBundle({
    required this.jsonBytes,
    required this.gzipBytes,
    required this.jsonFile,
    required this.gzipFile,
  });

  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
  final File jsonFile;
  final File gzipFile;
}

class BackupService {
  static const List<int> encryptionMagic = <int>[0x45, 0x4E, 0x43];
  static const int schemaVersion = 1;

  static Future<BackupBundle> create(AppStore store, {String? password}) async {
    final plainJson = Uint8List.fromList(utf8.encode(store.backupJson()));
    final jsonBytes = password == null || password.isEmpty
        ? plainJson
        : await _encrypt(plainJson, password);
    final compressed = Uint8List.fromList(gzip.encode(plainJson));
    final directory = await getTemporaryDirectory();
    final jsonFile = File('${directory.path}/morphcook-backup.json');
    final gzipFile = File('${directory.path}/morphcook-backup.json.gz');
    await jsonFile.writeAsBytes(jsonBytes, flush: true);
    await gzipFile.writeAsBytes(compressed, flush: true);
    return BackupBundle(
      jsonBytes: jsonBytes,
      gzipBytes: compressed,
      jsonFile: jsonFile,
      gzipFile: gzipFile,
    );
  }

  static Future<ShareResult> share(BackupBundle bundle) {
    return SharePlus.instance.share(
      ShareParams(
        title: 'MorphCook backup',
        files: <XFile>[
          XFile(bundle.jsonFile.path),
          XFile(bundle.gzipFile.path),
        ],
        fileNameOverrides: const <String>[
          'morphcook-backup.json',
          'morphcook-backup.json.gz',
        ],
      ),
    );
  }

  static Future<Map<String, dynamic>> decode(
    List<int> bytes, {
    String? password,
  }) async {
    final raw = Uint8List.fromList(bytes);
    if (_startsWith(raw, encryptionMagic)) {
      if (password == null || password.isEmpty) {
        throw const BackupException(
          'This backup is encrypted. Enter its password to restore it.',
        );
      }
      return _decodeJson(await _decrypt(raw, password));
    }
    if (_startsWith(raw, const <int>[0x1f, 0x8b])) {
      return _decodeJson(gzip.decode(raw));
    }
    return _decodeJson(raw);
  }

  static Future<Uint8List> _encrypt(Uint8List plain, String password) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await Pbkdf2.hmacSha256(
      iterations: 10000,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
    final box = await AesGcm.with256bits().encrypt(plain, secretKey: key);
    return Uint8List.fromList(<int>[
      ...encryptionMagic,
      schemaVersion,
      salt.length,
      ...salt,
      ...box.concatenation(),
    ]);
  }

  static Future<Uint8List> _decrypt(Uint8List payload, String password) async {
    try {
      if (payload.length < 5) {
        throw const BackupException(
          'Backup file is corrupted and cannot be restored.',
        );
      }
      final version = payload[3];
      final saltLength = payload[4];
      if (version != schemaVersion || payload.length <= 5 + saltLength) {
        throw const BackupException(
          'This file is not a valid MorphCook backup.',
        );
      }
      final salt = payload.sublist(5, 5 + saltLength);
      final encrypted = payload.sublist(5 + saltLength);
      final key = await Pbkdf2.hmacSha256(
        iterations: 10000,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);
      final box = SecretBox.fromConcatenation(
        encrypted,
        nonceLength: AesGcm.defaultNonceLength,
        macLength: 16,
      );
      final clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const BackupException('Incorrect password. Please try again.');
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'Backup file is corrupted and cannot be restored.',
      );
    }
  }

  static Map<String, dynamic> _decodeJson(List<int> bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic> ||
          decoded['schema_version'] != schemaVersion) {
        throw const BackupException(
          'This file is not a valid MorphCook backup.',
        );
      }
      return decoded;
    } on BackupException {
      rethrow;
    } catch (_) {
      throw const BackupException(
        'Backup file is corrupted and cannot be restored.',
      );
    }
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }
}
