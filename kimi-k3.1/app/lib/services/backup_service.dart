import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/profile.dart';
import '../models/user_data.dart';

enum DecryptionFailure {
  passwordRequired,
  wrongPassword,
  corrupted,
  invalidFormat,
}

class DecryptionException implements Exception {
  const DecryptionException(this.reason, this.message);
  final DecryptionFailure reason;
  final String message;

  static const wrongPasswordMessage = 'Incorrect password. Please try again.';
  static const corruptedMessage =
      'Backup file is corrupted and cannot be restored.';
  static const invalidMessage = 'This file is not a valid MorphCook backup.';

  @override
  String toString() => message;
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExportedBackup {
  const ExportedBackup({required this.jsonBytes, required this.gzipBytes});
  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
}

class BackupService {
  BackupService({Random? random}) : random = random ?? Random.secure();

  static const magic = <int>[0x45, 0x4e, 0x43];
  static const schemaVersion = 1;
  static const saltLength = 16;
  static const ivLength = 12;
  static const macLength = 16;
  final Random random;

  Map<String, dynamic> backupMap(
    Profile profile,
    UserSnapshot snapshot, {
    DateTime? exportedAt,
  }) => {
    'schema_version': schemaVersion,
    'exported_at': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'profile': profile.toJson(),
    ...snapshot.toJson(),
  };

  Future<ExportedBackup> create(
    Profile profile,
    UserSnapshot snapshot, {
    String password = '',
    DateTime? exportedAt,
  }) async {
    final plain = Uint8List.fromList(
      utf8.encode(
        JsonEncoder.withIndent(
          '  ',
        ).convert(backupMap(profile, snapshot, exportedAt: exportedAt)),
      ),
    );
    final compressed = Uint8List.fromList(gzip.encode(plain));
    if (password.isEmpty) {
      return ExportedBackup(jsonBytes: plain, gzipBytes: compressed);
    }
    final encrypted = await encrypt(plain, password);
    return ExportedBackup(jsonBytes: encrypted, gzipBytes: compressed);
  }

  Future<Uint8List> encrypt(List<int> plainText, String password) async {
    final salt = _randomBytes(saltLength);
    final iv = _randomBytes(ivLength);
    final key = await _key(password, salt);
    final box = await AesGcm.with256bits().encrypt(
      plainText,
      secretKey: key,
      nonce: iv,
    );
    return Uint8List.fromList([
      ...magic,
      ...salt,
      ...iv,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<Uint8List> decrypt(List<int> bytes, String password) async {
    if (!_startsWith(bytes, magic) ||
        bytes.length < magic.length + saltLength + ivLength + macLength) {
      throw const DecryptionException(
        DecryptionFailure.corrupted,
        DecryptionException.corruptedMessage,
      );
    }
    final saltStart = magic.length;
    final ivStart = saltStart + saltLength;
    final cipherStart = ivStart + ivLength;
    final cipherEnd = bytes.length - macLength;
    if (cipherEnd < cipherStart) {
      throw const DecryptionException(
        DecryptionFailure.corrupted,
        DecryptionException.corruptedMessage,
      );
    }
    final key = await _key(password, bytes.sublist(saltStart, ivStart));
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          bytes.sublist(cipherStart, cipherEnd),
          nonce: bytes.sublist(ivStart, cipherStart),
          mac: Mac(bytes.sublist(cipherEnd)),
        ),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on Exception {
      throw const DecryptionException(
        DecryptionFailure.wrongPassword,
        DecryptionException.wrongPasswordMessage,
      );
    }
  }

  Future<SecretKey> _key(String password, List<int> salt) {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );
    return kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Future<BackupData> import(List<int> bytes, {String? password}) async {
    List<int> plain;
    if (_startsWith(bytes, magic)) {
      if (bytes.length < magic.length + saltLength + ivLength + macLength) {
        throw const DecryptionException(
          DecryptionFailure.corrupted,
          DecryptionException.corruptedMessage,
        );
      }
      if (password == null || password.isEmpty) {
        throw const DecryptionException(
          DecryptionFailure.passwordRequired,
          'Password required to restore this backup.',
        );
      }
      plain = await decrypt(bytes, password);
    } else if (_startsWith(bytes, const [0x1f, 0x8b])) {
      try {
        plain = gzip.decode(bytes);
      } on Exception {
        throw const DecryptionException(
          DecryptionFailure.corrupted,
          DecryptionException.corruptedMessage,
        );
      }
    } else {
      plain = bytes;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plain));
    } on Exception {
      throw const DecryptionException(
        DecryptionFailure.invalidFormat,
        DecryptionException.invalidMessage,
      );
    }
    if (decoded is! Map) {
      throw const DecryptionException(
        DecryptionFailure.invalidFormat,
        DecryptionException.invalidMessage,
      );
    }
    if (decoded['schema_version'] != schemaVersion ||
        decoded['profile'] is! Map) {
      throw const BackupValidationException(
        'Unsupported or incomplete MorphCook backup schema.',
      );
    }
    return BackupData(
      profile: Profile.fromJson(decoded['profile']),
      snapshot: UserSnapshot.fromJson(decoded),
    );
  }

  Future<List<File>> writeFiles(ExportedBackup backup) async {
    final directory = await getTemporaryDirectory();
    final jsonFile = File('${directory.path}/morphcook-backup.json');
    final gzipFile = File('${directory.path}/morphcook-backup.json.gz');
    await jsonFile.writeAsBytes(backup.jsonBytes, flush: true);
    await gzipFile.writeAsBytes(backup.gzipBytes, flush: true);
    return [jsonFile, gzipFile];
  }

  Future<ShareResult> share(
    ExportedBackup backup, {
    Rect? sharePositionOrigin,
  }) async {
    final files = await writeFiles(backup);
    return SharePlus.instance.share(
      ShareParams(
        files: files.map((file) => XFile(file.path)).toList(),
        sharePositionOrigin: sharePositionOrigin,
        fileNameOverrides: const [
          'morphcook-backup.json',
          'morphcook-backup.json.gz',
        ],
      ),
    );
  }

  Future<List<int>?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'gz'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return File(file.path!).readAsBytes();
    throw const DecryptionException(
      DecryptionFailure.invalidFormat,
      DecryptionException.invalidMessage,
    );
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => random.nextInt(256), growable: false);

  bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }
}
