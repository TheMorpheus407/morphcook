/// File-based backup/restore.
///
/// Export writes BOTH:
///   morphcook-backup.json    — human-readable (encrypted when a password is
///                               given; magic bytes "ENC")
///   morphcook-backup.json.gz — GZip compressed, always unencrypted
///
/// Import auto-detects: ENC magic first, then GZip magic (0x1f 0x8b), then
/// plain JSON. Encryption: AES-256-GCM with PBKDF2 key derivation
/// (10,000 iterations, SHA-256), unique salt + IV per encryption.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class DecryptionException implements Exception {
  /// 'wrongPassword' | 'corrupted' | 'invalidFormat'
  final String reason;
  const DecryptionException(this.reason);

  @override
  String toString() => 'DecryptionException($reason)';
}

class BackupData {
  final Map<String, dynamic> profile;
  final List<String> saved;
  final Map<String, dynamic> mealPlan;
  final List<Map<String, dynamic>> history;
  final Map<String, dynamic> shoppingList;
  final List<String> contentRequests;
  final Map<String, dynamic> extra;

  const BackupData({
    required this.profile,
    required this.saved,
    required this.mealPlan,
    required this.history,
    required this.shoppingList,
    required this.contentRequests,
    this.extra = const {},
  });

  Map<String, dynamic> toJson() => {
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'profile': profile,
        'saved': saved,
        'meal_plan': mealPlan,
        'history': history,
        'shopping_list': shoppingList,
        'content_requests': contentRequests,
        ...extra,
      };

  static BackupData fromJson(Map<String, dynamic> json) => BackupData(
        profile: (json['profile'] as Map<String, dynamic>?) ?? {},
        saved: ((json['saved'] as List?) ?? const []).cast<String>().toList(),
        mealPlan: (json['meal_plan'] as Map<String, dynamic>?) ?? {},
        history: ((json['history'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        shoppingList:
            (json['shopping_list'] as Map<String, dynamic>?) ?? {},
        contentRequests:
            ((json['content_requests'] as List?) ?? const []).cast<String>().toList(),
      );
}

const List<int> encMagic = [0x45, 0x4E, 0x43]; // "ENC"
const List<int> gzipMagic = [0x1F, 0x8B];

class BackupCodec {
  // ---- gzip -------------------------------------------------------------
  static List<int> gzip(Uint8List bytes) => gzipEncode(bytes);
  static Uint8List gunzip(Uint8List bytes) => gzipDecode(bytes);

  // ---- encryption --------------------------------------------------------
  static Uint8List encrypt(Uint8List plaintext, String password) {
    final secure = Random.secure();
    final salt = Uint8List.fromList(
        List<int>.generate(16, (_) => secure.nextInt(256)));
    final iv = Uint8List.fromList(
        List<int>.generate(12, (_) => secure.nextInt(256)));

    final key = _deriveKey(password, salt);

    final cipher = _newCipher(true, key, iv);
    final encrypted = cipher.process(plaintext);

    // layout: "ENC" | salt(16) | iv(12) | ciphertext+tag
    final out = BytesBuilder();
    out.add(encMagic);
    out.add(salt);
    out.add(iv);
    out.add(encrypted);
    return out.toBytes();
  }

  static Uint8List decrypt(Uint8List data, String password) {
    const headerLen = 3 + 16 + 12;
    if (data.length < headerLen + 16) {
      throw const DecryptionException('corrupted');
    }
    final salt = Uint8List.sublistView(data, 3, 3 + 16);
    final iv = Uint8List.sublistView(data, 3 + 16, headerLen);
    final ciphertext = Uint8List.sublistView(data, headerLen);

    final key = _deriveKey(password, salt);
    final cipher = _newCipher(false, key, iv);
    try {
      return cipher.process(ciphertext);
    } on InvalidCipherTextException {
      throw const DecryptionException('wrongPassword');
    } catch (_) {
      throw const DecryptionException('corrupted');
    }
  }

  static GCMBlockCipher _newCipher(
      bool encrypt, Uint8List key, Uint8List iv) {
    final c = GCMBlockCipher(AESEngine())
      ..init(
        encrypt,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );
    return c;
  }

  static Uint8List _deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 10000, 32));
    return pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
  }

  // ---- format detection ---------------------------------------------------
  /// Detect the container format of raw backup bytes.
  static BackupFormat detectFormat(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == encMagic[0] &&
        bytes[1] == encMagic[1] &&
        bytes[2] == encMagic[2]) {
      return BackupFormat.encrypted;
    }
    if (bytes.length >= 2 &&
        bytes[0] == gzipMagic[0] &&
        bytes[1] == gzipMagic[1]) {
      return BackupFormat.gzip;
    }
    return BackupFormat.plainJson;
  }
}

enum BackupFormat { encrypted, gzip, plainJson }

// ---- pure-dart gzip (RFC 1952) --------------------------------------------
// Thin wrapper over dart:io's ZLibCodec in gzip mode; kept explicit so the
// format detection and tests exercise real magic bytes.

List<int> gzipEncode(Uint8List bytes) => GZipCodec(level: 9).encode(bytes);

Uint8List gzipDecode(Uint8List bytes) =>
    Uint8List.fromList(GZipCodec().decode(bytes));

/// Serialize → both backup files, returned as (name, bytes) pairs.
/// The JSON file is encrypted when [password] is given; the .gz never is.
List<(String, Uint8List)> buildExportFiles(BackupData data, {String? password}) {
  final jsonText = const JsonEncoder.withIndent('  ').convert(data.toJson());
  final jsonBytes = Uint8List.fromList(utf8.encode(jsonText));

  final jsonOut = password == null || password.isEmpty
      ? jsonBytes
      : BackupCodec.encrypt(jsonBytes, password);
  final gzOut = Uint8List.fromList(BackupCodec.gzip(jsonBytes));

  return [
    ('morphcook-backup.json', jsonOut),
    ('morphcook-backup.json.gz', gzOut),
  ];
}

/// Parse an import file of any supported format. Throws DecryptionException
/// with reason 'encrypted' when a password is required.
BackupData parseImport(Uint8List bytes, {String? password}) {
  var payload = bytes;
  switch (BackupCodec.detectFormat(bytes)) {
    case BackupFormat.encrypted:
      if (password == null || password.isEmpty) {
        throw const DecryptionException('needsPassword');
      }
      payload = BackupCodec.decrypt(bytes, password);
      break;
    case BackupFormat.gzip:
      payload = BackupCodec.gunzip(bytes);
      break;
    case BackupFormat.plainJson:
      break;
  }
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(utf8.decode(payload)) as Map<String, dynamic>;
  } on FormatException {
    throw const DecryptionException('invalidFormat');
  } on TypeError {
    throw const DecryptionException('invalidFormat');
  }
  final version = json['schema_version'];
  if (version != 1) {
    throw const DecryptionException('invalidFormat');
  }
  return BackupData.fromJson(json);
}
