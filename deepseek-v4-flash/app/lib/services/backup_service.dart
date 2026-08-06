import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/api.dart' show KeyParameter, AEADParameters;

import '../models/models.dart';

/// Backup format (documented, versioned):
///
///   plain:     "MCBK" magic (4 bytes) + version byte + gzip(json)
///   encrypted: "ENC1" magic (4 bytes) + version byte + saltLen + salt(16)
///              + ivLen + iv(12) + AES-256-GCM ciphertext (auth tag appended
///              by GCM). Key = PBKDF2-HMAC-SHA256(password, salt, 100_000, 32).
class BackupFormat {
  static const plainMagic = [0x4D, 0x43, 0x42, 0x4B]; // "MCBK"
  static const encMagic = [0x45, 0x4E, 0x43, 0x31]; // "ENC1"
  static const schemaVersion = 1;
  static const pbkdf2Iterations = 100000;
  static const saltLength = 16;
  static const ivLength = 12;
}

enum BackupErrorType { notMorphcook, corrupted, wrongPassword, unknown }

class BackupException implements Exception {
  final BackupErrorType type;
  final String? detail;

  BackupException(this.type, [this.detail]);

  @override
  String toString() => 'BackupException($type${detail == null ? '' : ': $detail'})';
}

class BackupDocument {
  final Map<String, dynamic> data;

  BackupDocument(this.data);

  static BackupDocument fromJsonString(String s) {
    final Object? decoded;
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      throw BackupException(BackupErrorType.corrupted, 'bad json');
    }
    if (decoded is! Map<String, dynamic>) {
      throw BackupException(BackupErrorType.corrupted, 'not an object');
    }
    if (decoded['kind'] != 'morphcook-backup') {
      throw BackupException(BackupErrorType.notMorphcook);
    }
    final version = decoded['schema_version'];
    if (version != BackupFormat.schemaVersion) {
      throw BackupException(
          BackupErrorType.corrupted, 'unsupported schema $version');
    }
    return BackupDocument(decoded);
  }
}

/// Everything the app persists, minus volatile state.
class BackupPayload {
  final UserProfile profile;
  final List<SavedEntry> saved;
  final List<HistoryEntry> history;
  final Map<String, Map<String, String>> mealPlan; // weekKey -> slot -> recipeId
  final List<String> contentRequests;
  final List<ShoppingLine> shoppingLines;

  BackupPayload({
    required this.profile,
    required this.saved,
    required this.history,
    required this.mealPlan,
    required this.contentRequests,
    this.shoppingLines = const [],
  });

  String toJsonString() => jsonEncode(toJson());

  Map<String, dynamic> toJson() => {
        'kind': 'morphcook-backup',
        'schema_version': BackupFormat.schemaVersion,
        'exported_at': DateTime.now().toIso8601String(),
        'profile': profile.toJson(),
        'saved': saved
            .map((e) => {
                  'recipe_id': e.recipeId,
                  'saved_at': e.savedAt.toIso8601String()
                })
            .toList(),
        'history': history
            .map((e) => {'recipe_id': e.recipeId, 'at': e.at.toIso8601String()})
            .toList(),
        'meal_plan': mealPlan,
        'content_requests': contentRequests,
        'shopping': shoppingLines
            .map((l) => {
                  'recipe_id': l.recipeId,
                  'added_at': l.addedAt.toIso8601String(),
                  'servings': l.servings,
                })
            .toList(),
      };

  factory BackupPayload.fromJson(Map<String, dynamic> j) => BackupPayload(
        profile: UserProfile.fromJson(
            (j['profile'] as Map? ?? const {}).cast<String, dynamic>()),
        saved: ((j['saved'] as List?) ?? const []).map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return SavedEntry(
              recipeId: m['recipe_id'] as String,
              savedAt: DateTime.parse(m['saved_at'] as String));
        }).toList(),
        history: ((j['history'] as List?) ?? const []).map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return HistoryEntry(
              recipeId: m['recipe_id'] as String,
              at: DateTime.parse(m['at'] as String));
        }).toList(),
        mealPlan: ((j['meal_plan'] as Map?) ?? const {})
            .map((k, v) => MapEntry(
                k as String,
                (v as Map)
                    .map((kk, vv) => MapEntry(kk as String, vv as String)))),
        contentRequests:
            ((j['content_requests'] as List?) ?? const []).cast<String>(),
        shoppingLines: ((j['shopping'] as List?) ?? const []).map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return ShoppingLine(
              recipeId: m['recipe_id'] as String,
              addedAt: DateTime.parse(m['added_at'] as String),
              servings: (m['servings'] as num?)?.toInt());
        }).toList(),
      );
}

bool _startsWith(List<int> bytes, List<int> magic) {
  if (bytes.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (bytes[i] != magic[i]) return false;
  }
  return true;
}

/// Compression + packaging (no password).
class BackupCoder {
  /// Encodes a payload into the plain container: magic + gzip(json).
  static Uint8List encodePlain(BackupPayload payload) {
    final json = utf8.encode(payload.toJsonString());
    final gz = GZipEncoder().encode(json);
    final out = BytesBuilder();
    out.add(BackupFormat.plainMagic);
    out.add([BackupFormat.schemaVersion]);
    out.add(gz);
    return out.toBytes();
  }

  /// Decodes a plain container back into a payload.
  static BackupPayload decodePlain(Uint8List bytes) {
    if (bytes.length < 5 ||
        !_startsWith(bytes, BackupFormat.plainMagic) ||
        bytes[4] != BackupFormat.schemaVersion) {
      throw BackupException(BackupErrorType.notMorphcook);
    }
    final Uint8List jsonBytes;
    try {
      jsonBytes =
          Uint8List.fromList(GZipDecoder().decodeBytes(bytes.sublist(5)));
    } catch (_) {
      throw BackupException(BackupErrorType.corrupted, 'bad gzip');
    }
    final doc = BackupDocument.fromJsonString(utf8.decode(jsonBytes));
    return BackupPayload.fromJson(doc.data);
  }
}

/// AES-256-GCM encryption layer. Salt/IV come from `Random.secure()`.
class BackupCrypto {
  static Uint8List _deriveKey(String password, List<int> salt) {
    final params = Pbkdf2Parameters(
      Uint8List.fromList(salt),
      BackupFormat.pbkdf2Iterations,
      32,
    );
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(params);
    return derivator.process(utf8.encode(password));
  }

  /// Encrypts raw plaintext bytes with the container header.
  static Uint8List encrypt(String password, Uint8List plaintext) {
    final rnd = Random.secure();
    final salt = List<int>.generate(
        BackupFormat.saltLength, (_) => rnd.nextInt(256));
    final iv = List<int>.generate(BackupFormat.ivLength, (_) => rnd.nextInt(256));
    final key = _deriveKey(password, salt);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          true,
          AEADParameters(KeyParameter(key), 128, Uint8List.fromList(iv),
              Uint8List(0)));
    final ciphertext = Uint8List(plaintext.length + 16);
    final o1 =
        cipher.processBytes(plaintext, 0, plaintext.length, ciphertext, 0);
    cipher.doFinal(ciphertext, o1);

    final out = BytesBuilder();
    out.add(BackupFormat.encMagic);
    out.add([BackupFormat.schemaVersion]);
    out.add([salt.length]);
    out.add(salt);
    out.add([iv.length]);
    out.add(iv);
    out.add(ciphertext);
    return out.toBytes();
  }

  /// Decrypts a container. Throws [BackupException]:
  ///  - notMorphcook when magic/version wrong
  ///  - wrongPassword when GCM auth fails
  ///  - corrupted for structural errors
  static Uint8List decrypt(String password, Uint8List bytes) {
    if (bytes.length < 5 ||
        !_startsWith(bytes, BackupFormat.encMagic) ||
        bytes[4] != BackupFormat.schemaVersion) {
      throw BackupException(BackupErrorType.notMorphcook);
    }
    var off = 5;
    int read() {
      if (off >= bytes.length) {
        throw BackupException(BackupErrorType.corrupted, 'truncated header');
      }
      return bytes[off++];
    }

    final saltLen = read();
    if (saltLen <= 0 || saltLen > 32) {
      throw BackupException(BackupErrorType.corrupted, 'bad salt len');
    }
    final salt = bytes.sublist(off, off + saltLen);
    off += saltLen;
    final ivLen = read();
    if (ivLen <= 0 || ivLen > 32) {
      throw BackupException(BackupErrorType.corrupted, 'bad iv len');
    }
    final iv = bytes.sublist(off, off + ivLen);
    off += ivLen;
    if (off >= bytes.length) {
      throw BackupException(BackupErrorType.corrupted, 'no ciphertext');
    }
    final body = bytes.sublist(off);
    final key = _deriveKey(password, salt);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
          false,
          AEADParameters(KeyParameter(key), 128, Uint8List.fromList(iv),
              Uint8List(0)));
    final plain = Uint8List(body.length - 16);
    try {
      final o1 = cipher.processBytes(body, 0, body.length, plain, 0);
      cipher.doFinal(plain, o1);
    } catch (_) {
      throw BackupException(BackupErrorType.wrongPassword);
    }
    return plain;
  }

  /// Encrypts a payload end-to-end.
  static Uint8List encodeEncrypted(BackupPayload payload, String password) =>
      encrypt(password, utf8.encode(payload.toJsonString()));

  /// Decrypts and parses a payload.
  static BackupPayload decodeEncrypted(Uint8List bytes, String password) {
    final plain = decrypt(password, bytes);
    final doc = BackupDocument.fromJsonString(utf8.decode(plain));
    return BackupPayload.fromJson(doc.data);
  }

  static bool isEncrypted(Uint8List bytes) =>
      _startsWith(bytes, BackupFormat.encMagic);

  static bool isPlain(Uint8List bytes) =>
      _startsWith(bytes, BackupFormat.plainMagic);
}

/// File-backed import/export for the platform layer.
class BackupService {
  /// Encodes, and optionally encrypts, a payload to bytes.
  static Uint8List encode(BackupPayload payload, {String? password}) {
    if (password != null && password.isNotEmpty) {
      return BackupCrypto.encodeEncrypted(payload, password);
    }
    return BackupCoder.encodePlain(payload);
  }

  /// Detects format and returns the payload. Errors as [BackupException]:
  /// wrong password / corrupted / not a morphcook backup.
  static BackupPayload decode(Uint8List bytes, {String? password}) {
    if (BackupCrypto.isEncrypted(bytes)) {
      if (password == null || password.isEmpty) {
        throw BackupException(
            BackupErrorType.wrongPassword, 'file is encrypted, password required');
      }
      return BackupCrypto.decodeEncrypted(bytes, password);
    }
    if (BackupCrypto.isPlain(bytes)) {
      return BackupCoder.decodePlain(bytes);
    }
    throw BackupException(
        BackupErrorType.notMorphcook, 'not a morphcook backup file');
  }

  /// Writes bytes to [path] (used by share/export flow).
  static Future<void> writeFile(String path, Uint8List bytes) async {
    await File(path).writeAsBytes(bytes);
  }
}
