import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';

enum DecryptionFailure { wrongPassword, corrupted, invalidFormat }

class DecryptionException implements Exception {
  const DecryptionException(this.reason);

  final DecryptionFailure reason;

  String message(String language) {
    final de = language == 'de';
    return switch (reason) {
      DecryptionFailure.wrongPassword =>
        de
            ? 'Falsches Passwort. Bitte versuche es erneut.'
            : 'Incorrect password. Please try again.',
      DecryptionFailure.corrupted =>
        de
            ? 'Die Sicherungsdatei ist beschädigt und kann nicht wiederhergestellt werden.'
            : 'Backup file is corrupted and cannot be restored.',
      DecryptionFailure.invalidFormat =>
        de
            ? 'Diese Datei ist keine gültige MorphCook-Sicherung.'
            : 'This file is not a valid MorphCook backup.',
    };
  }

  @override
  String toString() => message('en');
}

class BackupBundle {
  const BackupBundle({required this.jsonBytes, required this.gzipBytes});
  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
}

class BackupService {
  BackupService({Cryptography? cryptography})
    : _cryptography = cryptography ?? Cryptography.instance;

  static const List<int> encryptionMagic = [0x45, 0x4e, 0x43];
  static const List<int> gzipMagic = [0x1f, 0x8b];
  final Cryptography _cryptography;

  Future<BackupBundle> create(
    Map<String, Object?> data, {
    String? password,
  }) async {
    final normalized = <String, Object?>{
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      ...data,
    };
    final plain = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(normalized)),
    );
    final gzip = Uint8List.fromList(GZipEncoder().encode(plain));
    final json = password == null || password.isEmpty
        ? plain
        : await _encrypt(plain, password);
    return BackupBundle(jsonBytes: json, gzipBytes: gzip);
  }

  Future<Map<String, dynamic>> read(List<int> bytes, {String? password}) async {
    if (bytes.length < 2) {
      throw const DecryptionException(DecryptionFailure.invalidFormat);
    }
    Uint8List plain;
    var protectedFormat = false;
    if (_startsWith(bytes, encryptionMagic)) {
      protectedFormat = true;
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionFailure.wrongPassword);
      }
      plain = await _decrypt(Uint8List.fromList(bytes), password);
    } else if (_startsWith(bytes, gzipMagic)) {
      protectedFormat = true;
      try {
        plain = Uint8List.fromList(GZipDecoder().decodeBytes(bytes));
      } catch (_) {
        throw const DecryptionException(DecryptionFailure.corrupted);
      }
    } else {
      plain = Uint8List.fromList(bytes);
    }
    try {
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map || decoded['schema_version'] != 1) {
        throw const DecryptionException(DecryptionFailure.invalidFormat);
      }
      return Map<String, dynamic>.from(decoded);
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw DecryptionException(
        protectedFormat
            ? DecryptionFailure.corrupted
            : DecryptionFailure.invalidFormat,
      );
    }
  }

  Future<Uint8List> _encrypt(Uint8List plain, String password) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(password, salt);
    final box = await _cryptography.aesGcm().encrypt(
      plain,
      secretKey: key,
      nonce: nonce,
    );
    final payload = <int>[
      ...salt,
      ...nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ];
    final checksum = await _cryptography.sha256().hash(payload);
    return Uint8List.fromList([
      ...encryptionMagic,
      ...payload,
      ...checksum.bytes,
    ]);
  }

  Future<Uint8List> _decrypt(Uint8List bytes, String password) async {
    if (bytes.length < 3 + 16 + 12 + 16 + 32) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
    final checksumStart = bytes.length - 32;
    final payload = bytes.sublist(3, checksumStart);
    final expectedChecksum = bytes.sublist(checksumStart);
    final actualChecksum = (await _cryptography.sha256().hash(payload)).bytes;
    if (!_sameBytes(expectedChecksum, actualChecksum)) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
    final salt = payload.sublist(0, 16);
    final nonce = payload.sublist(16, 28);
    final cipherAndMac = payload.sublist(28);
    final cipher = cipherAndMac.sublist(0, cipherAndMac.length - 16);
    final mac = Mac(cipherAndMac.sublist(cipherAndMac.length - 16));
    try {
      final clear = await _cryptography.aesGcm().decrypt(
        SecretBox(cipher, nonce: nonce, mac: mac),
        secretKey: await _deriveKey(password, salt),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const DecryptionException(DecryptionFailure.wrongPassword);
    } catch (_) {
      throw const DecryptionException(DecryptionFailure.corrupted);
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) => _cryptography
      .pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 10000, bits: 256)
      .deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _startsWith(List<int> value, List<int> prefix) {
    if (value.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (value[i] != prefix[i]) return false;
    }
    return true;
  }

  bool _sameBytes(List<int> first, List<int> second) {
    if (first.length != second.length) return false;
    var difference = 0;
    for (var index = 0; index < first.length; index++) {
      difference |= first[index] ^ second[index];
    }
    return difference == 0;
  }
}
