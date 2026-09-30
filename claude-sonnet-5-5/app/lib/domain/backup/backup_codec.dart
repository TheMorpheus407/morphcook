import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'backup_models.dart';

/// Reads and writes the backup file formats.
///
/// * `morphcook-backup.json`: human-readable JSON, or an encrypted container
///   when a password is given.
/// * `morphcook-backup.json.gz`: the same JSON, GZip compressed, never encrypted.
///
/// Encrypted container: `ENC | version | salt(16) | iv(12) | check(4) | ciphertext | tag(16)`
/// with AES-256-GCM. The key comes from PBKDF2-HMAC-SHA256 (10,000 iterations)
/// over the password and a fresh random salt; every export uses a fresh IV.
/// The 4-byte check value lets a wrong password be told apart from corruption.
class BackupCodec {
  BackupCodec({Random? random}) : _random = random ?? Random.secure();

  /// ASCII "ENC".
  static const List<int> encryptedMagic = <int>[0x45, 0x4E, 0x43];
  static const List<int> gzipMagic = <int>[0x1f, 0x8b];
  static const int containerVersion = 1;
  static const int pbkdf2Iterations = 10000;
  static const int saltLength = 16;
  static const int ivLength = 12;
  static const int checkLength = 4;
  static const int tagLength = 16;
  static const int headerLength = 3 + 1 + saltLength + ivLength + checkLength;

  static const String jsonFileName = 'morphcook-backup.json';
  static const String gzipFileName = 'morphcook-backup.json.gz';

  final Random _random;

  static final AesGcm _aes = AesGcm.with256bits();

  static bool hasMagic(List<int> bytes, List<int> magic) {
    if (bytes.length < magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[i] != magic[i]) return false;
    }
    return true;
  }

  static bool isEncrypted(List<int> bytes) => hasMagic(bytes, encryptedMagic);
  static bool isGzip(List<int> bytes) => hasMagic(bytes, gzipMagic);

  // ---------------------------------------------------------------- encode

  /// Human-readable JSON (pretty printed).
  Uint8List encodeJson(BackupData data) {
    return Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data.toJson())));
  }

  /// GZip of the same JSON. Always unencrypted, for sharing.
  Uint8List encodeGzip(BackupData data) => Uint8List.fromList(gzip.encode(encodeJson(data)));

  /// The JSON encrypted with [password].
  Future<Uint8List> encodeEncrypted(BackupData data, String password) async {
    final salt = _randomBytes(saltLength);
    final iv = _randomBytes(ivLength);
    final key = await _deriveKey(password, salt);
    final box = await _aes.encrypt(encodeJson(data), secretKey: key, nonce: iv);
    final check = await _keyCheck(key);
    final out = BytesBuilder(copy: false)
      ..add(encryptedMagic)
      ..addByte(containerVersion)
      ..add(salt)
      ..add(iv)
      ..add(check)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  // ---------------------------------------------------------------- decode

  /// Auto-detects the format: encrypted first, then GZip, then plain JSON.
  ///
  /// Throws [DecryptionException] with [DecryptionFailure.passwordRequired] for
  /// an encrypted file; the caller then asks for the password and calls
  /// [decodeEncrypted].
  BackupData decode(List<int> bytes) {
    if (isEncrypted(bytes)) throw const DecryptionException(DecryptionFailure.passwordRequired);
    return _parse(_plainJson(bytes));
  }

  /// Reads an encrypted backup. A plain or GZip file is accepted too, so the
  /// password prompt never has to guess.
  Future<BackupData> decodeEncrypted(List<int> bytes, String password) async {
    if (!isEncrypted(bytes)) return decode(bytes);
    if (bytes.length < headerLength + tagLength) throw const DecryptionException(DecryptionFailure.corrupted);
    if (bytes[3] != containerVersion) throw const DecryptionException(DecryptionFailure.unsupportedVersion);

    var offset = 4;
    final salt = bytes.sublist(offset, offset + saltLength);
    offset += saltLength;
    final iv = bytes.sublist(offset, offset + ivLength);
    offset += ivLength;
    final check = bytes.sublist(offset, offset + checkLength);
    offset += checkLength;
    final cipherText = bytes.sublist(offset, bytes.length - tagLength);
    final tag = bytes.sublist(bytes.length - tagLength);

    final key = await _deriveKey(password, salt);
    final expectedCheck = await _keyCheck(key);
    if (!_constantTimeEquals(check, expectedCheck)) {
      throw const DecryptionException(DecryptionFailure.wrongPassword);
    }
    final List<int> clear;
    try {
      clear = await _aes.decrypt(
        SecretBox(cipherText, nonce: iv, mac: Mac(tag)),
        secretKey: key,
      );
    } on SecretBoxAuthenticationError {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
    return _parse(clear);
  }

  List<int> _plainJson(List<int> bytes) {
    if (!isGzip(bytes)) return bytes;
    try {
      return gzip.decode(bytes);
    } on Object {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
  }

  BackupData _parse(List<int> jsonBytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(jsonBytes));
    } on FormatException {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    if (decoded is! Map) throw const DecryptionException(DecryptionFailure.invalidFormat);
    return BackupData.fromJson(decoded.cast<String, dynamic>());
  }

  // ---------------------------------------------------------------- crypto

  Uint8List _randomBytes(int length) => Uint8List.fromList([for (var i = 0; i < length; i++) _random.nextInt(256)]);

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    final pbkdf2 = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: pbkdf2Iterations, bits: 256);
    return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Future<List<int>> _keyCheck(SecretKey key) async {
    final keyBytes = await key.extractBytes();
    final hash = await Sha256().hash([...keyBytes, ...utf8.encode('morphcook-key-check')]);
    return hash.bytes.sublist(0, checkLength);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
