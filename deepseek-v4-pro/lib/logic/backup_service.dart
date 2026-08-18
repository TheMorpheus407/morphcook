import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import '../models/profile.dart';

/// Backup format detection + AES-256-GCM encryption.
///
/// Magic bytes:
///  - encrypted json: [0x45, 0x4E, 0x43] ("ENC") + salt(16) + iv(12) + tag(16) + ct
///  - gzip:           [0x1f, 0x8b]
///  - plain json:     starts with '{'
enum BackupFormat { json, gzip, encrypted, invalid }

class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final String reason; // needsPassword | wrongPassword | corrupted | invalid

  String message(String lang) {
    if (reason == 'needsPassword') {
      return lang == 'de'
          ? 'Dieses Backup ist verschlüsselt. Gib das Passwort ein.'
          : 'This backup is encrypted. Enter the password.';
    }
    if (reason == 'wrongPassword') {
      return lang == 'de'
          ? 'Falsches Passwort. Bitte versuche es erneut.'
          : 'Incorrect password. Please try again.';
    }
    if (reason == 'corrupted') {
      return lang == 'de'
          ? 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'
          : 'Backup file is corrupted and cannot be restored.';
    }
    return lang == 'de'
        ? 'Diese Datei ist kein gültiges MorphCook-Backup.'
        : 'This file is not a valid MorphCook backup.';
  }

  @override
  String toString() => 'DecryptionException($reason)';
}

class BackupService {
  BackupService._();

  static const magicBytes = [0x45, 0x4E, 0x43]; // "ENC"
  static const schemaVersion = 1;
  static const jsonFileName = 'morphcook-backup.json';
  static const gzFileName = 'morphcook-backup.json.gz';

  // ---------------------------------------------------------------- build

  static Map<String, dynamic> buildBackup({
    required Profile profile,
    required List<String> saved,
    required Map<String, Map<String, String>> mealPlan,
    required List<Map<String, dynamic>> history,
    List<String> contentRequests = const [],
    DateTime? exportedAt,
  }) => {
        'schema_version': schemaVersion,
        'exported_at':
            (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved,
        'meal_plan': mealPlan,
        'history': history,
        'content_requests': contentRequests,
      };

  static String encodeBackupJson(Map<String, dynamic> backup) =>
      const JsonEncoder.withIndent('  ').convert(backup);

  // ---------------------------------------------------------------- export

  /// GZip-compressed bytes (always unencrypted). Typically 70–90% smaller.
  static Uint8List encodeGz(String json) =>
      Uint8List.fromList(gzip.encode(utf8.encode(json)));

  /// JSON bytes; AES-256-GCM encrypted when [password] is provided.
  static Uint8List encodeJson(String json, {String? password}) {
    final plain = utf8.encode(json);
    if (password == null) return Uint8List.fromList(plain);

    final salt = _randomBytes(16);
    final iv = _randomBytes(12);
    final key = _deriveKey(password, salt);

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
      true,
      AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
    );
    // pointycastle ≥3.9: process() returns ciphertext || 16-byte tag.
    final sealed = cipher.process(plain);
    final ciphertext = Uint8List.sublistView(sealed, 0, sealed.length - 16);
    final tag = Uint8List.sublistView(sealed, sealed.length - 16);

    final out = BytesBuilder()
      ..add(magicBytes)
      ..add(salt)
      ..add(iv)
      ..add(tag)
      ..add(ciphertext);
    return out.toBytes();
  }

  // ---------------------------------------------------------------- detect

  static BackupFormat detect(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == magicBytes[0] &&
        bytes[1] == magicBytes[1] &&
        bytes[2] == magicBytes[2]) {
      return BackupFormat.encrypted;
    }
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      return BackupFormat.gzip;
    }
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      if (text.trimLeft().startsWith('{')) return BackupFormat.json;
    } catch (_) {}
    return BackupFormat.invalid;
  }

  // ---------------------------------------------------------------- import

  /// Decodes raw file bytes into the backup JSON string.
  /// Throws [DecryptionException]:
  ///  - 'needsPassword' when the file is encrypted and no password is given
  ///  - 'wrongPassword' on a failed decrypt
  ///  - 'corrupted'     on malformed data
  ///  - 'invalid'       when it's not a backup at all
  static String decode(Uint8List bytes, {String? password}) {
    final format = detect(bytes);
    switch (format) {
      case BackupFormat.json:
        return utf8.decode(bytes);
      case BackupFormat.gzip:
        try {
          return utf8.decode(gzip.decode(bytes));
        } catch (_) {
          throw const DecryptionException('corrupted');
        }
      case BackupFormat.encrypted:
        if (password == null) {
          throw const DecryptionException('needsPassword');
        }
        try {
          return _decrypt(bytes, password);
        } on DecryptionException {
          rethrow;
        } catch (_) {
          throw const DecryptionException('corrupted');
        }
      case BackupFormat.invalid:
        throw const DecryptionException('invalid');
    }
  }

  /// Parses + validates the decoded JSON. Throws DecryptionException('invalid')
  /// when the schema version or structure doesn't match.
  static Map<String, dynamic> parse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) {
        throw const DecryptionException('invalid');
      }
      final version = json['schema_version'];
      if (version != schemaVersion) {
        throw const DecryptionException('invalid');
      }
      if (json['profile'] is! Map<String, dynamic>) {
        throw const DecryptionException('invalid');
      }
      return json;
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw const DecryptionException('invalid');
    }
  }

  // ---------------------------------------------------------------- crypto

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    derivator.init(
      Pbkdf2Parameters(salt, 10000, 32),
    );
    return derivator.process(utf8.encode(password));
  }

  static String _decrypt(Uint8List bytes, String password) {
    if (bytes.length < 3 + 16 + 12 + 16) {
      throw const DecryptionException('corrupted');
    }
    var offset = 3;
    final salt = Uint8List.sublistView(bytes, offset, offset + 16);
    offset += 16;
    final iv = Uint8List.sublistView(bytes, offset, offset + 12);
    offset += 12;
    final tag = Uint8List.sublistView(bytes, offset, offset + 16);
    offset += 16;
    final ciphertext = Uint8List.sublistView(bytes, offset);

    final key = _deriveKey(password, salt);
    final sealed = Uint8List.fromList([...ciphertext, ...tag]);
    final cipher = GCMBlockCipher(AESEngine());
    try {
      cipher.init(
        false,
        AEADParameters(KeyParameter(key), 128, Uint8List.fromList(iv), Uint8List(0)),
      );
      final plain = cipher.process(sealed);
      return utf8.decode(plain);
    } catch (_) {
      // GCM tag mismatch → almost certainly the wrong password.
      throw const DecryptionException('wrongPassword');
    }
  }

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(List<int>.generate(n, (_) => _secure.nextInt(256)));

  static final _secure = Random.secure();
}
