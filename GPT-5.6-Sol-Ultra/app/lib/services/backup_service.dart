import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

enum BackupEncoding { json, gzip, encrypted }

enum RestoreMode { merge, replace }

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}

class DecryptionException implements Exception {
  const DecryptionException._(this.message);

  factory DecryptionException.passwordRequired() => const DecryptionException._(
    'This backup is encrypted. Please enter its password.',
  );

  factory DecryptionException.incorrectPassword() =>
      const DecryptionException._('Incorrect password. Please try again.');

  factory DecryptionException.corrupted() => const DecryptionException._(
    'Backup file is corrupted and cannot be restored.',
  );

  factory DecryptionException.invalidFormat() =>
      const DecryptionException._('This file is not a valid MorphCook backup.');

  final String message;

  @override
  String toString() => 'DecryptionException: $message';
}

/// Schema-1 representation of all mutable, user-owned MorphCook data.
class BackupData {
  BackupData({
    required Map<String, dynamic> profile,
    required Iterable<String> saved,
    required Map<String, Map<String, String>> mealPlan,
    required Iterable<Map<String, dynamic>> history,
    Iterable<String> contentRequests = const <String>[],
    Iterable<Map<String, dynamic>> shoppingEntries =
        const <Map<String, dynamic>>[],
    Iterable<Map<String, dynamic>> shoppingInsightEvents =
        const <Map<String, dynamic>>[],
    Map<String, Map<String, dynamic>> cookSessions =
        const <String, Map<String, dynamic>>{},
    DateTime? exportedAt,
  }) : profile = Map<String, dynamic>.unmodifiable(profile),
       saved = List<String>.unmodifiable(saved),
       mealPlan = _freezeNestedStringMap(mealPlan),
       history = List<Map<String, dynamic>>.unmodifiable(
         history.map((item) => Map<String, dynamic>.unmodifiable(item)),
       ),
       contentRequests = List<String>.unmodifiable(contentRequests),
       shoppingEntries = List<Map<String, dynamic>>.unmodifiable(
         shoppingEntries.map((item) => Map<String, dynamic>.unmodifiable(item)),
       ),
       shoppingInsightEvents = List<Map<String, dynamic>>.unmodifiable(
         shoppingInsightEvents.map(
           (item) => Map<String, dynamic>.unmodifiable(item),
         ),
       ),
       cookSessions = Map<String, Map<String, dynamic>>.unmodifiable(
         cookSessions.map(
           (key, value) =>
               MapEntry(key, Map<String, dynamic>.unmodifiable(value)),
         ),
       ),
       exportedAt = (exportedAt ?? DateTime.now()).toUtc();

  factory BackupData.empty({Map<String, dynamic>? profile}) => BackupData(
    profile: profile ?? const <String, dynamic>{},
    saved: const <String>[],
    mealPlan: const <String, Map<String, String>>{},
    history: const <Map<String, dynamic>>[],
  );

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schema_version'];
    if (schemaVersion is! int) {
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }
    if (schemaVersion != BackupService.schemaVersion) {
      throw BackupFormatException(
        'Unsupported backup schema version: $schemaVersion.',
      );
    }

    try {
      final exportedAtValue = json['exported_at'];
      final profileValue = json['profile'];
      final savedValue = json['saved'];
      final mealPlanValue = json['meal_plan'];
      final historyValue = json['history'];

      if (exportedAtValue is! String ||
          profileValue is! Map ||
          savedValue is! List ||
          mealPlanValue is! Map ||
          historyValue is! List) {
        throw const FormatException('Missing a required schema-1 field.');
      }

      final mealPlan = <String, Map<String, String>>{};
      for (final entry in mealPlanValue.entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException('Invalid meal plan.');
        }
        mealPlan[entry.key as String] = (entry.value as Map).map((key, value) {
          if (key is! String || value is! String) {
            throw const FormatException('Invalid meal plan slot.');
          }
          return MapEntry(key, value);
        });
      }

      return BackupData(
        profile: _dynamicMap(profileValue),
        saved: savedValue.cast<String>(),
        mealPlan: mealPlan,
        history: historyValue
            .map((item) => _dynamicMap(item as Map))
            .toList(growable: false),
        contentRequests:
            (json['content_requests'] as List<dynamic>? ?? const <dynamic>[])
                .cast<String>(),
        shoppingEntries:
            (json['shopping_entries'] as List<dynamic>? ?? const <dynamic>[])
                .map((item) => _dynamicMap(item as Map))
                .toList(growable: false),
        shoppingInsightEvents:
            (json['shopping_insight_events'] as List<dynamic>? ??
                    const <dynamic>[])
                .map((item) => _dynamicMap(item as Map))
                .toList(growable: false),
        cookSessions:
            (json['cook_sessions'] as Map<dynamic, dynamic>? ??
                    const <dynamic, dynamic>{})
                .map(
                  (key, value) =>
                      MapEntry(key as String, _dynamicMap(value as Map)),
                ),
        exportedAt: DateTime.parse(exportedAtValue),
      );
    } on BackupFormatException {
      rethrow;
    } on Object {
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }
  }

  final Map<String, dynamic> profile;
  final List<String> saved;
  final Map<String, Map<String, String>> mealPlan;
  final List<Map<String, dynamic>> history;
  final List<String> contentRequests;

  /// Optional schema-1 extensions. Older schema-1 backups remain valid.
  final List<Map<String, dynamic>> shoppingEntries;
  final List<Map<String, dynamic>> shoppingInsightEvents;
  final Map<String, Map<String, dynamic>> cookSessions;
  final DateTime exportedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema_version': BackupService.schemaVersion,
    'exported_at': exportedAt.toIso8601String(),
    'profile': profile,
    'saved': saved,
    'meal_plan': mealPlan,
    'history': history,
    if (contentRequests.isNotEmpty) 'content_requests': contentRequests,
    if (shoppingEntries.isNotEmpty) 'shopping_entries': shoppingEntries,
    if (shoppingInsightEvents.isNotEmpty)
      'shopping_insight_events': shoppingInsightEvents,
    if (cookSessions.isNotEmpty) 'cook_sessions': cookSessions,
  };
}

class BackupExportBundle {
  const BackupExportBundle({
    required this.jsonBytes,
    required this.gzipBytes,
    required this.jsonEncrypted,
  });

  static const jsonFileName = 'morphcook-backup.json';
  static const gzipFileName = 'morphcook-backup.json.gz';

  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
  final bool jsonEncrypted;
}

/// JSON/GZip/AES-256-GCM backup codec and schema merge implementation.
class BackupService {
  BackupService({Random? secureRandom})
    : _random = secureRandom ?? Random.secure();

  static const int schemaVersion = 1;
  static const int pbkdf2Iterations = 10000;
  static const int maxBackupBytes = 16 * 1024 * 1024;
  static const List<int> encryptionMagic = <int>[0x45, 0x4e, 0x43];
  static const List<int> gzipMagic = <int>[0x1f, 0x8b];
  static const int _encryptionFormatVersion = 1;
  static const int _saltLength = 16;
  static const int _nonceLength = 12;
  static const int _verifierLength = 8;
  static const int _headerChecksumLength = 4;
  static const int _macLength = 16;

  final Random _random;
  final AesGcm _cipher = AesGcm.with256bits(nonceLength: _nonceLength);
  final Pbkdf2 _kdf = Pbkdf2.hmacSha256(
    iterations: pbkdf2Iterations,
    bits: 256,
  );

  BackupEncoding detectEncoding(List<int> bytes) {
    if (_startsWith(bytes, encryptionMagic)) return BackupEncoding.encrypted;
    if (_startsWith(bytes, gzipMagic)) return BackupEncoding.gzip;
    return BackupEncoding.json;
  }

  Future<BackupExportBundle> export(BackupData data, {String? password}) async {
    final clearJson = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data.toJson())),
    );
    final shouldEncrypt = password != null && password.isNotEmpty;
    final jsonBytes = shouldEncrypt
        ? await encryptJson(clearJson, password)
        : clearJson;

    return BackupExportBundle(
      jsonBytes: jsonBytes,
      // Per specification, GZip remains unencrypted even when the JSON sibling
      // is password protected.
      gzipBytes: Uint8List.fromList(gzip.encode(clearJson)),
      jsonEncrypted: shouldEncrypt,
    );
  }

  Future<Uint8List> encryptJson(List<int> clearJson, String password) async {
    if (password.isEmpty) {
      throw ArgumentError.value(password, 'password', 'Must not be empty.');
    }
    final salt = _randomBytes(_saltLength);
    final nonce = _randomBytes(_nonceLength);
    final key = await _deriveKey(password, salt);
    final verifier = await _keyVerifier(key, salt);
    final headerChecksum = await _headerChecksum(salt, nonce, verifier);
    final secretBox = await _cipher.encrypt(
      clearJson,
      secretKey: key,
      nonce: nonce,
    );

    // Binary v1 layout:
    // ENC | version | salt(16) | nonce(12) | key verifier(8) |
    // header checksum(4) | ciphertext | GCM tag(16).
    return Uint8List.fromList(<int>[
      ...encryptionMagic,
      _encryptionFormatVersion,
      ...salt,
      ...nonce,
      ...verifier,
      ...headerChecksum,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
  }

  Future<BackupData> import(List<int> bytes, {String? password}) async {
    if (bytes.isEmpty) throw DecryptionException.invalidFormat();
    if (bytes.length > maxBackupBytes) {
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }
    switch (detectEncoding(bytes)) {
      case BackupEncoding.encrypted:
        if (password == null || password.isEmpty) {
          throw DecryptionException.passwordRequired();
        }
        final clear = await decryptJson(bytes, password);
        return _parseJson(clear, encryptedSource: true);
      case BackupEncoding.gzip:
        try {
          return _parseJson(_decodeGzipWithLimit(bytes));
        } on BackupFormatException {
          rethrow;
        } on Object {
          throw const BackupFormatException(
            'Backup file is corrupted and cannot be restored.',
          );
        }
      case BackupEncoding.json:
        return _parseJson(bytes);
    }
  }

  List<int> _decodeGzipWithLimit(List<int> bytes) {
    final output = <int>[];
    final conversion = gzip.decoder.startChunkedConversion(
      _LimitedByteSink(output, maxBackupBytes),
    );
    conversion
      ..add(bytes)
      ..close();
    return output;
  }

  Future<Uint8List> decryptJson(List<int> encrypted, String password) async {
    if (!_startsWith(encrypted, encryptionMagic)) {
      throw DecryptionException.invalidFormat();
    }
    final minimumLength =
        encryptionMagic.length +
        1 +
        _saltLength +
        _nonceLength +
        _verifierLength +
        _headerChecksumLength +
        _macLength;
    if (encrypted.length <= minimumLength) {
      throw DecryptionException.corrupted();
    }

    var offset = encryptionMagic.length;
    final formatVersion = encrypted[offset++];
    if (formatVersion != _encryptionFormatVersion) {
      throw DecryptionException.invalidFormat();
    }
    final salt = encrypted.sublist(offset, offset += _saltLength);
    final nonce = encrypted.sublist(offset, offset += _nonceLength);
    final storedVerifier = encrypted.sublist(offset, offset += _verifierLength);
    final storedHeaderChecksum = encrypted.sublist(
      offset,
      offset += _headerChecksumLength,
    );
    final cipherText = encrypted.sublist(offset, encrypted.length - _macLength);
    final mac = encrypted.sublist(encrypted.length - _macLength);

    final actualHeaderChecksum = await _headerChecksum(
      salt,
      nonce,
      storedVerifier,
    );
    if (!_constantTimeEquals(storedHeaderChecksum, actualHeaderChecksum)) {
      throw DecryptionException.corrupted();
    }

    final key = await _deriveKey(password, salt);
    final actualVerifier = await _keyVerifier(key, salt);
    if (!_constantTimeEquals(storedVerifier, actualVerifier)) {
      throw DecryptionException.incorrectPassword();
    }

    try {
      final clear = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw DecryptionException.corrupted();
    } on Object {
      throw DecryptionException.corrupted();
    }
  }

  BackupData merge(
    BackupData current,
    BackupData imported, {
    required RestoreMode mode,
  }) {
    if (mode == RestoreMode.replace) {
      return BackupData(
        profile: imported.profile,
        saved: imported.saved,
        mealPlan: imported.mealPlan,
        history: imported.history,
        contentRequests: imported.contentRequests,
        shoppingEntries: imported.shoppingEntries,
        shoppingInsightEvents: imported.shoppingInsightEvents,
        cookSessions: imported.cookSessions,
      );
    }

    final profile = <String, dynamic>{...current.profile, ...imported.profile};
    final saved = <String>{...current.saved, ...imported.saved}.toList()
      ..sort();
    final mealPlan = <String, Map<String, String>>{
      for (final entry in current.mealPlan.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    for (final entry in imported.mealPlan.entries) {
      mealPlan.update(
        entry.key,
        (existing) => <String, String>{...existing, ...entry.value},
        ifAbsent: () => Map<String, String>.from(entry.value),
      );
    }

    final history = _mergeMapLists(
      current.history,
      imported.history,
      _historyIdentity,
    );
    final shopping = _mergeMapLists(
      current.shoppingEntries,
      imported.shoppingEntries,
      (entry) => entry['id']?.toString() ?? jsonEncode(entry),
    );
    final shoppingInsights = _mergeMapLists(
      current.shoppingInsightEvents,
      imported.shoppingInsightEvents,
      (entry) => entry['id']?.toString() ?? jsonEncode(entry),
    );
    final requests = <String, String>{};
    for (final request in <String>[
      ...current.contentRequests,
      ...imported.contentRequests,
    ]) {
      final trimmed = request.trim();
      if (trimmed.isNotEmpty) requests[trimmed.toLowerCase()] = trimmed;
    }

    return BackupData(
      profile: profile,
      saved: saved,
      mealPlan: mealPlan,
      history: history,
      contentRequests: requests.values,
      shoppingEntries: shopping,
      shoppingInsightEvents: shoppingInsights,
      cookSessions: <String, Map<String, dynamic>>{
        ...current.cookSessions,
        ...imported.cookSessions,
      },
    );
  }

  BackupData _parseJson(List<int> bytes, {bool encryptedSource = false}) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Root is not an object.');
      }
      return BackupData.fromJson(_dynamicMap(decoded));
    } on BackupFormatException {
      rethrow;
    } on Object {
      if (encryptedSource) throw DecryptionException.invalidFormat();
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  Future<List<int>> _keyVerifier(SecretKey key, List<int> salt) async {
    final keyBytes = await key.extractBytes();
    final digest = await Sha256().hash(<int>[
      ...keyBytes,
      ...salt,
      ...utf8.encode('MorphCook backup verifier v1'),
    ]);
    return digest.bytes.take(_verifierLength).toList(growable: false);
  }

  Future<List<int>> _headerChecksum(
    List<int> salt,
    List<int> nonce,
    List<int> verifier,
  ) async {
    final digest = await Sha256().hash(<int>[
      _encryptionFormatVersion,
      ...salt,
      ...nonce,
      ...verifier,
      ...utf8.encode('MorphCook encrypted header v1'),
    ]);
    return digest.bytes.take(_headerChecksumLength).toList(growable: false);
  }

  Uint8List _randomBytes(int length) => Uint8List.fromList(
    List<int>.generate(length, (_) => _random.nextInt(256)),
  );
}

class _LimitedByteSink implements Sink<List<int>> {
  _LimitedByteSink(this.output, this.limit);

  final List<int> output;
  final int limit;

  @override
  void add(List<int> data) {
    if (output.length + data.length > limit) {
      throw const BackupFormatException(
        'This file is not a valid MorphCook backup.',
      );
    }
    output.addAll(data);
  }

  @override
  void close() {}
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (bytes[index] != prefix[index]) return false;
  }
  return true;
}

bool _constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var index = 0; index < a.length; index++) {
    difference |= a[index] ^ b[index];
  }
  return difference == 0;
}

Map<String, dynamic> _dynamicMap(Map<dynamic, dynamic> value) =>
    value.map((key, item) => MapEntry(key.toString(), item));

Map<String, Map<String, String>> _freezeNestedStringMap(
  Map<String, Map<String, String>> source,
) => Map<String, Map<String, String>>.unmodifiable(
  source.map(
    (key, value) => MapEntry(key, Map<String, String>.unmodifiable(value)),
  ),
);

List<Map<String, dynamic>> _mergeMapLists(
  List<Map<String, dynamic>> current,
  List<Map<String, dynamic>> imported,
  String Function(Map<String, dynamic>) identity,
) {
  final merged = <String, Map<String, dynamic>>{};
  for (final entry in current) {
    merged[identity(entry)] = entry;
  }
  for (final entry in imported) {
    merged[identity(entry)] = entry;
  }
  return merged.values.toList(growable: false);
}

String _historyIdentity(Map<String, dynamic> entry) {
  final id = entry['id']?.toString();
  if (id != null && id.isNotEmpty) return id;
  return '${entry['recipe_id'] ?? ''}|${entry['cooked_at'] ?? ''}';
}
