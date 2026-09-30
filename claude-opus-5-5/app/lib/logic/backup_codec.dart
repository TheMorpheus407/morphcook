import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Magic bytes `ENC` that start every encrypted backup.
const encMagic = [0x45, 0x4E, 0x43];

/// GZip magic bytes.
const gzipMagic = [0x1f, 0x8b];

const backupSchemaVersion = 1;
const backupJsonName = 'morphcook-backup.json';
const backupGzName = 'morphcook-backup.json.gz';

/// Encrypted layout: `ENC` | version(1) | salt(16) | iv(12) | ciphertext+tag.
const _encVersion = 1;
const _saltLength = 16;
const _ivLength = 12;
const _keyLength = 32; // AES-256
const _tagBits = 128;
const pbkdf2Iterations = 10000;

enum BackupFormat { json, gzip, encrypted }

enum DecryptionFailure { passwordRequired, wrongPassword, corrupted, invalidFormat }

class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final DecryptionFailure reason;

  /// Actionable English message (the UI localises by [reason]).
  String get message => switch (reason) {
    DecryptionFailure.passwordRequired => 'This backup is password-protected. Enter the password to restore it.',
    DecryptionFailure.wrongPassword => 'Incorrect password. Please try again.',
    DecryptionFailure.corrupted => 'Backup file is corrupted and cannot be restored.',
    DecryptionFailure.invalidFormat => 'This file is not a valid MorphCook backup.',
  };

  @override
  String toString() => 'DecryptionException($reason): $message';
}

class BackupFiles {
  const BackupFiles({required this.json, required this.gzip, required this.encrypted});

  /// `morphcook-backup.json` bytes — encrypted when a password was given.
  final Uint8List json;

  /// `morphcook-backup.json.gz` bytes — always unencrypted.
  final Uint8List gzip;
  final bool encrypted;
}

/// Pure encoding/decoding of backup files. No platform APIs.
class BackupCodec {
  BackupCodec({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  static const _pretty = JsonEncoder.withIndent('  ');

  BackupFiles encode(Map<String, dynamic> payload, {String? password}) {
    final text = _pretty.convert(payload);
    final plain = Uint8List.fromList(utf8.encode(text));
    final gz = Uint8List.fromList(gzip.encode(plain));
    final usePassword = password != null && password.isNotEmpty;
    return BackupFiles(json: usePassword ? encrypt(plain, password) : plain, gzip: gz, encrypted: usePassword);
  }

  static BackupFormat detect(Uint8List bytes) {
    if (_startsWith(bytes, encMagic)) return BackupFormat.encrypted;
    if (_startsWith(bytes, gzipMagic)) return BackupFormat.gzip;
    return BackupFormat.json;
  }

  /// Decodes a plain or gzipped backup. Throws [DecryptionException] with
  /// [DecryptionFailure.passwordRequired] for encrypted files — the caller
  /// prompts for the password and calls [decodeEncrypted].
  Map<String, dynamic> decode(Uint8List bytes) {
    switch (detect(bytes)) {
      case BackupFormat.encrypted:
        throw const DecryptionException(DecryptionFailure.passwordRequired);
      case BackupFormat.gzip:
        final List<int> raw;
        try {
          raw = gzip.decode(bytes);
        } catch (_) {
          throw const DecryptionException(DecryptionFailure.corrupted);
        }
        return _parse(Uint8List.fromList(raw));
      case BackupFormat.json:
        return _parse(bytes);
    }
  }

  Map<String, dynamic> decodeEncrypted(Uint8List bytes, String password) {
    if (detect(bytes) != BackupFormat.encrypted) return decode(bytes);
    return _parse(decrypt(bytes, password));
  }

  Uint8List encrypt(Uint8List plain, String password) {
    final salt = _randomBytes(_saltLength);
    final iv = _randomBytes(_ivLength);
    final key = deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)));
    final sealed = cipher.process(plain);
    return Uint8List.fromList([...encMagic, _encVersion, ...salt, ...iv, ...sealed]);
  }

  Uint8List decrypt(Uint8List bytes, String password) {
    const header = 3 + 1 + _saltLength + _ivLength;
    if (!_startsWith(bytes, encMagic)) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (bytes.length < header + _tagBits ~/ 8 || bytes[3] != _encVersion) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
    final salt = Uint8List.sublistView(bytes, 4, 4 + _saltLength);
    final iv = Uint8List.sublistView(bytes, 4 + _saltLength, header);
    final sealed = Uint8List.sublistView(bytes, header);
    final key = deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), _tagBits, iv, Uint8List(0)));
    try {
      return cipher.process(sealed);
    } on InvalidCipherTextException {
      // GCM cannot tell a wrong key from tampered bytes; a wrong password is
      // by far the likelier cause, and the message says how to proceed.
      throw const DecryptionException(DecryptionFailure.wrongPassword);
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
  }

  /// PBKDF2-HMAC-SHA256, 10,000 iterations, 256-bit key.
  static Uint8List deriveKey(String password, Uint8List salt) {
    final kdf = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, pbkdf2Iterations, _keyLength));
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  Map<String, dynamic> _parse(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      // Looks like JSON that got cut off → corrupted; anything else → wrong file.
      final head = bytes.take(64).where((b) => b > 0x20).take(1).toList();
      if (head.isNotEmpty && head.first == 0x7B /* { */ ) {
        throw const DecryptionException(DecryptionFailure.corrupted);
      }
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (decoded is! Map<String, dynamic> || decoded['schema_version'] is! int) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    final version = decoded['schema_version'] as int;
    if (version < 1 || version > backupSchemaVersion) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    return decoded;
  }

  Uint8List _randomBytes(int n) => Uint8List.fromList(List<int>.generate(n, (_) => _random.nextInt(256)));

  static bool _startsWith(Uint8List bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }
}
