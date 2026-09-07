import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Rect;
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum DecryptionReason {
  passwordRequired,
  incorrectPassword,
  corrupted,
  invalidFormat,
}

class DecryptionException implements Exception {
  final DecryptionReason reason;
  final String message;
  const DecryptionException(this.reason, this.message);
  @override
  String toString() => message;
}

class BackupFiles {
  final Uint8List jsonBytes;
  final Uint8List gzipBytes;
  final bool encrypted;
  const BackupFiles({
    required this.jsonBytes,
    required this.gzipBytes,
    required this.encrypted,
  });
  Uint8List get json => jsonBytes;
  Uint8List get gzip => gzipBytes;
}

class BackupService {
  static const _magic = [0x45, 0x4e, 0x43];
  static const _headerSize = 3 + 1 + 16 + 12 + 16;
  static const _maximumBytes = 50 * 1024 * 1024;
  static final _cipher = AesGcm.with256bits();
  static final _derivation = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256,
  );

  static DecryptionException _invalid() => const DecryptionException(
    DecryptionReason.invalidFormat,
    'This file is not a valid MorphCook backup.',
  );
  static DecryptionException _corrupt() => const DecryptionException(
    DecryptionReason.corrupted,
    'Backup file is corrupted and cannot be restored.',
  );

  static bool isEncrypted(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == _magic[0] &&
      bytes[1] == _magic[1] &&
      bytes[2] == _magic[2];

  static Future<BackupFiles> encode(
    Map<String, dynamic> data, {
    String? password,
  }) async {
    validate(data);
    final plain = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    final compressed = Uint8List.fromList(gzip.encode(plain));
    final encrypted = password != null && password.isNotEmpty;
    if (!encrypted) {
      return BackupFiles(
        jsonBytes: plain,
        gzipBytes: compressed,
        encrypted: false,
      );
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final key = await _derivation.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await _cipher.encrypt(plain, secretKey: key, nonce: nonce);
    final bytes = Uint8List.fromList([
      ..._magic,
      1,
      ...salt,
      ...nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
    // The companion GZip intentionally contains the original unencrypted JSON.
    return BackupFiles(
      jsonBytes: bytes,
      gzipBytes: compressed,
      encrypted: true,
    );
  }

  static Future<Map<String, dynamic>> decode(
    List<int> bytes, {
    String? password,
  }) async {
    if (bytes.isEmpty || bytes.length > _maximumBytes) throw _invalid();
    List<int> plain = bytes;
    if (isEncrypted(bytes)) {
      if (bytes.length <= _headerSize) throw _corrupt();
      if (bytes[3] != 1) throw _invalid();
      if (password == null || password.isEmpty) {
        throw const DecryptionException(
          DecryptionReason.passwordRequired,
          'This backup is encrypted. Enter its password to restore it.',
        );
      }
      final salt = bytes.sublist(4, 20);
      final nonce = bytes.sublist(20, 32);
      final mac = bytes.sublist(32, 48);
      final key = await _derivation.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      try {
        plain = await _cipher.decrypt(
          SecretBox(bytes.sublist(48), nonce: nonce, mac: Mac(mac)),
          secretKey: key,
        );
      } on SecretBoxAuthenticationError {
        // AEAD cannot distinguish a wrong key from tampering of intact ciphertext.
        throw const DecryptionException(
          DecryptionReason.incorrectPassword,
          'Incorrect password. Please try again.',
        );
      } catch (_) {
        throw _corrupt();
      }
    } else if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        final output = <int>[];
        await for (final chunk in Stream<List<int>>.value(
          bytes,
        ).transform(gzip.decoder)) {
          if (output.length + chunk.length > _maximumBytes) throw _corrupt();
          output.addAll(chunk);
        }
        plain = output;
      } on DecryptionException {
        rethrow;
      } catch (_) {
        throw _corrupt();
      }
    }
    try {
      final decoded = jsonDecode(utf8.decode(plain));
      if (decoded is! Map<String, dynamic>) throw _invalid();
      validate(decoded);
      return decoded;
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw _invalid();
    }
  }

  /// Validate the complete mutable payload before any restore changes local data.
  static void validate(Map<String, dynamic> data) {
    bool stringList(dynamic value) =>
        value is List && value.every((e) => e is String);
    bool date(dynamic value) =>
        value is String && DateTime.tryParse(value) != null;
    if (data['schema_version'] != 1 ||
        !date(data['exported_at']) ||
        data['profile'] is! Map ||
        !stringList(data['saved']) ||
        data['meal_plan'] is! Map ||
        data['history'] is! List) {
      throw _invalid();
    }
    final profile = data['profile'] as Map;
    for (final key in ['name', 'lang', 'preferred_effort']) {
      if (profile.containsKey(key) && profile[key] is! String) throw _invalid();
    }
    for (final key in [
      'avoid_flags',
      'avoid_ingredients',
      'required_attributes',
    ]) {
      if (profile.containsKey(key) && !stringList(profile[key])) {
        throw _invalid();
      }
    }
    for (final key in [
      'max_time_minutes',
      'calorie_target',
      'calorie_tolerance',
    ]) {
      if (profile.containsKey(key) &&
          (profile[key] is! num ||
              !(profile[key] as num).isFinite ||
              profile[key] < 0 ||
              profile[key] > 10000)) {
        throw _invalid();
      }
    }
    if (profile['max_time_minutes'] != null &&
        (profile['max_time_minutes'] < 1 ||
            profile['max_time_minutes'] > 1440)) {
      throw _invalid();
    }
    if (profile['preferred_effort'] != null &&
        !{'easy', 'medium', 'hard'}.contains(profile['preferred_effort'])) {
      throw _invalid();
    }
    for (final key in [
      'show_variant_tags',
      'onboarded',
      'visualAlertEnabled',
      'visual_alert_enabled',
      'quickNextTapEnabled',
      'quick_next_tap_enabled',
    ]) {
      if (profile.containsKey(key) && profile[key] is! bool) throw _invalid();
    }
    for (final key in ['reduceMotion', 'reduce_motion']) {
      if (profile[key] != null && profile[key] is! bool) throw _invalid();
    }
    if (data.containsKey('content_requests') &&
        !stringList(data['content_requests'])) {
      throw _invalid();
    }
    for (final entry in (data['meal_plan'] as Map).entries) {
      if (entry.key is! String || entry.value is! Map) throw _invalid();
      for (final slot in (entry.value as Map).entries) {
        if (slot.key is! String || slot.value is! String) throw _invalid();
      }
    }
    for (final event in data['history'] as List) {
      if (event is! Map ||
          event['recipe_id'] is! String ||
          !date(event['cooked_at'])) {
        throw _invalid();
      }
    }
    if (data.containsKey('shopping')) {
      if (data['shopping'] is! List) throw _invalid();
      for (final item in data['shopping'] as List) {
        if (item is! Map ||
            item['id'] is! String ||
            item['ingredient_id'] is! String ||
            item['quantity'] is! num ||
            !(item['quantity'] as num).isFinite ||
            item['quantity'] <= 0 ||
            item['unit'] is! String ||
            (item.containsKey('checked') && item['checked'] is! bool) ||
            (item['custom_name'] != null && item['custom_name'] is! String)) {
          throw _invalid();
        }
      }
    }
    if (data.containsKey('shopping_history')) {
      if (data['shopping_history'] is! List) throw _invalid();
      for (final event in data['shopping_history'] as List) {
        if (event is! Map ||
            event['ingredient_id'] is! String ||
            !date(event['added_at']) ||
            event['count'] is! num ||
            !(event['count'] as num).isFinite ||
            event['count'] < 0) {
          throw _invalid();
        }
      }
    }
    if (data.containsKey('cook_progress') && data['cook_progress'] is! Map) {
      throw _invalid();
    }
    final progress = data['cook_progress'] as Map? ?? {};
    if (progress['recipe_id'] != null && progress['recipe_id'] is! String) {
      throw _invalid();
    }
    for (final key in ['step', 'servings', 'remaining_seconds']) {
      if (progress.containsKey(key) &&
          (progress[key] is! num ||
              !(progress[key] as num).isFinite ||
              progress[key] < 0)) {
        throw _invalid();
      }
    }
    if (progress['servings'] != null &&
        (progress['servings'] < 1 || progress['servings'] > 24)) {
      throw _invalid();
    }
    for (final key in ['timer_started', 'paused', 'resume_timer_on_resume']) {
      if (progress.containsKey(key) && progress[key] is! bool) throw _invalid();
    }
    for (final key in ['deadline', 'updated_at']) {
      if (progress[key] != null && !date(progress[key])) throw _invalid();
    }
  }

  static Future<ShareResult> export(
    Map<String, dynamic> data, {
    String? password,
  }) async {
    final files = await encode(data, password: password);
    final directory = await getTemporaryDirectory();
    final exportDirectory = await Directory(
      '${directory.path}/morphcook-${DateTime.now().microsecondsSinceEpoch}',
    ).create();
    final jsonFile = File('${exportDirectory.path}/morphcook-backup.json');
    final gzipFile = File('${exportDirectory.path}/morphcook-backup.json.gz');
    await Future.wait([
      jsonFile.writeAsBytes(files.jsonBytes, flush: true),
      gzipFile.writeAsBytes(files.gzipBytes, flush: true),
    ]);
    return SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            jsonFile.path,
            mimeType: files.encrypted
                ? 'application/octet-stream'
                : 'application/json',
          ),
          XFile(gzipFile.path, mimeType: 'application/gzip'),
        ],
        subject: 'MorphCook backup',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
      ),
    );
  }
}
