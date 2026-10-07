import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// File-based backup/restore.
///
/// Export writes two files side by side:
/// - `morphcook-backup.json` — human-readable (AES-256-GCM encrypted when a
///   password is provided),
/// - `morphcook-backup.json.gz` — GZip compressed, always unencrypted.
///
/// Import auto-detects the format: encryption magic bytes (`0x45 0x4E 0x43`,
/// ASCII "ENC") first, then GZip magic bytes (`0x1f 0x8b`), then plain JSON.
class BackupService {
  static const int schemaVersion = 1;

  /// Magic bytes marking an encrypted backup: ASCII "ENC".
  static const List<int> encryptionMagic = [0x45, 0x4E, 0x43];

  /// Magic bytes marking a GZip stream.
  static const List<int> gzipMagic = [0x1f, 0x8b];

  static const int _pbkdf2Iterations = 10000;
  static const int _saltLength = 16;
  static const int _ivLength = 12;

  // ── payload ───────────────────────────────────────────────────────────

  Map<String, dynamic> buildPayload({
    required Map<String, dynamic> profile,
    required List<String> saved,
    required Map<String, dynamic> mealPlan,
    required List<Map<String, dynamic>> history,
    List<String> contentRequests = const [],
    Map<String, dynamic> shopping = const {},
    Map<String, dynamic> shoppingLog = const {},
  }) =>
      {
        'schema_version': schemaVersion,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': profile,
        'saved': saved,
        'meal_plan': mealPlan,
        'history': history,
        'content_requests': contentRequests,
        if (shopping.isNotEmpty) 'shopping': shopping,
        if (shoppingLog.isNotEmpty) 'shopping_log': shoppingLog,
      };

  // ── export ────────────────────────────────────────────────────────────

  /// Returns the bytes of both export files.
  Future<({Uint8List json, Uint8List gzip})> exportBytes(
    Map<String, dynamic> payload, {
    String? password,
  }) async {
    final jsonBytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(payload));
    final Uint8List encrypted;
    if (password != null && password.isNotEmpty) {
      encrypted = await encryptJson(Uint8List.fromList(jsonBytes), password);
    } else {
      encrypted = Uint8List.fromList(jsonBytes);
    }
    final gzipped = Uint8List.fromList(gzip.encode(jsonBytes));
    return (json: encrypted, gzip: gzipped);
  }

  // ── import ────────────────────────────────────────────────────────────

  /// Auto-detect the format and parse. Throws [DecryptionException] when an
  /// encrypted backup is detected (the caller must prompt for the password
  /// and call [parseEncrypted]). Throws [FormatException] for anything that
  /// is not a valid MorphCook backup.
  Future<Map<String, dynamic>> parseBackup(Uint8List bytes, {String? password}) async {
    if (_hasPrefix(bytes, encryptionMagic)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException('password-required');
      }
      final plain = await decryptJson(bytes, password);
      return _decodeJson(plain);
    }
    if (_hasPrefix(bytes, gzipMagic)) {
      final plain = gzip.decode(bytes);
      return _decodeJson(Uint8List.fromList(plain));
    }
    return _decodeJson(bytes);
  }

  Map<String, dynamic> _decodeJson(List<int> bytes) {
    final String text;
    try {
      text = utf8.decode(bytes);
    } catch (_) {
      throw const FormatException('not utf-8');
    }
    final dynamic decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('not an object');
    }
    final version = decoded['schema_version'];
    if (version is! int || version > schemaVersion) {
      throw const FormatException('unsupported schema_version');
    }
    return decoded;
  }

  // ── encryption ────────────────────────────────────────────────────────

  /// AES-256-GCM with PBKDF2 key derivation (10,000 iterations, SHA-256).
  /// Each encryption generates a unique salt and IV.
  ///
  /// Layout: "ENC" | format version (1) | salt (16) | iv (12) | ciphertext+tag.
  Future<Uint8List> encryptJson(List<int> plain, String password) async {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final key = await _deriveKey(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      plain,
      secretKey: key,
      nonce: iv,
    );
    final out = BytesBuilder(copy: false);
    out.add(encryptionMagic);
    out.add([1]);
    out.add(salt);
    out.add(iv);
    out.add(box.cipherText);
    out.add(box.mac.bytes);
    return out.toBytes();
  }

  /// Decrypt an encrypted backup. Throws [DecryptionException] with an
  /// actionable reason on failure.
  Future<Uint8List> decryptJson(Uint8List bytes, String password) async {
    if (!_hasPrefix(bytes, encryptionMagic)) {
      throw const DecryptionException('not-encrypted');
    }
    try {
      final salt = Uint8List.sublistView(bytes, 4, 4 + _saltLength);
      final iv = Uint8List.sublistView(bytes, 4 + _saltLength, 4 + _saltLength + _ivLength);
      final ciphertext = Uint8List.sublistView(bytes, 4 + _saltLength + _ivLength);
      final aesGcm = AesGcm.with256bits();
      final macLength = aesGcm.macAlgorithm.macLength;
      if (ciphertext.length < macLength) {
        throw const DecryptionException('corrupted');
      }
      // The stored tail is cipherText + tag; split it back into the two.
      final mac = Mac(ciphertext.sublist(ciphertext.length - macLength));
      final cipherOnly = ciphertext.sublist(0, ciphertext.length - macLength);
      final key = await _deriveKey(password, salt);
      final box = await aesGcm.decrypt(
        SecretBox(cipherOnly, nonce: iv, mac: mac),
        secretKey: key,
      );
      return Uint8List.fromList(box);
    } on SecretBoxAuthenticationError {
      throw const DecryptionException('wrong-password');
    } catch (e) {
      if (e is DecryptionException) rethrow;
      throw const DecryptionException('corrupted');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static bool _hasPrefix(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }
}

/// Thrown when an encrypted backup needs a password or decryption fails.
/// [reason] is one of: password-required | wrong-password | corrupted |
/// not-encrypted.
class DecryptionException implements Exception {
  final String reason;

  const DecryptionException(this.reason);

  @override
  String toString() => 'DecryptionException($reason)';
}
