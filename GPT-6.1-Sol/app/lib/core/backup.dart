import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'models.dart';

enum DecryptionReason {
  passwordRequired,
  incorrectPassword,
  corrupted,
  invalidFormat,
}

class DecryptionException implements Exception {
  final DecryptionReason reason;
  const DecryptionException(this.reason);
  String get message => switch (reason) {
    DecryptionReason.passwordRequired => 'Enter the password for this backup.',
    DecryptionReason.incorrectPassword =>
      'Incorrect password. Please try again.',
    DecryptionReason.corrupted =>
      'Backup file is corrupted and cannot be restored.',
    DecryptionReason.invalidFormat =>
      'This file is not a valid MorphCook backup.',
  };
  @override
  String toString() => message;
}

class BackupFiles {
  final Uint8List json;
  final Uint8List compressed;
  final bool encrypted;
  BackupFiles(this.json, this.compressed, this.encrypted);
}

class BackupService {
  static const maxBytes = 16 * 1024 * 1024;
  static const magic = [0x45, 0x4e, 0x43];
  final _cipher = AesGcm.with256bits();
  final _derivation = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 10000,
    bits: 256,
  );

  Future<BackupFiles> export(
    Map<String, dynamic> data, {
    String? password,
  }) async {
    validate(data);
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
    );
    if (bytes.length > maxBytes) {
      throw const DecryptionException(DecryptionReason.corrupted);
    }
    return BackupFiles(
      password != null && password.isNotEmpty
          ? await encrypt(bytes, password)
          : bytes,
      Uint8List.fromList(gzip.encode(bytes)),
      password != null && password.isNotEmpty,
    );
  }

  bool isEncrypted(List<int> bytes) =>
      bytes.length >= 3 &&
      bytes[0] == magic[0] &&
      bytes[1] == magic[1] &&
      bytes[2] == magic[2];

  Future<Uint8List> encrypt(Uint8List bytes, String password) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _derivation.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final box = await _cipher.encrypt(
      bytes,
      secretKey: key,
      aad: [...magic, 1],
    );
    return Uint8List.fromList([
      ...magic,
      1,
      ...salt,
      ...box.nonce,
      ...box.mac.bytes,
      ...box.cipherText,
    ]);
  }

  Future<Map<String, dynamic>> import(
    List<int> input, {
    String? password,
  }) async {
    if (input.isEmpty || input.length > maxBytes) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
    var bytes = Uint8List.fromList(input);
    if (isEncrypted(bytes)) {
      if (password == null || password.isEmpty) {
        throw const DecryptionException(DecryptionReason.passwordRequired);
      }
      if (bytes.length < 49) {
        throw const DecryptionException(DecryptionReason.corrupted);
      }
      if (bytes[3] != 1) {
        throw const DecryptionException(DecryptionReason.invalidFormat);
      }
      final salt = bytes.sublist(4, 20);
      final nonce = bytes.sublist(20, 32);
      final mac = Mac(bytes.sublist(32, 48));
      final key = await _derivation.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );
      try {
        bytes = Uint8List.fromList(
          await _cipher.decrypt(
            SecretBox(bytes.sublist(48), nonce: nonce, mac: mac),
            secretKey: key,
            aad: [...magic, 1],
          ),
        );
      } on SecretBoxAuthenticationError {
        throw const DecryptionException(DecryptionReason.incorrectPassword);
      } catch (_) {
        throw const DecryptionException(DecryptionReason.corrupted);
      }
    } else if (bytes.length > 1 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      try {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in Stream<List<int>>.value(
          bytes,
        ).transform(gzip.decoder)) {
          if (builder.length + chunk.length > maxBytes) {
            throw const DecryptionException(DecryptionReason.corrupted);
          }
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
      } catch (_) {
        throw const DecryptionException(DecryptionReason.corrupted);
      }
    }
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, dynamic>) throw const FormatException();
      validate(value);
      return value;
    } on DecryptionException {
      rethrow;
    } catch (_) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
  }

  /// Validate the entire file before the caller replaces any local state.
  void validate(Map<String, dynamic> data) {
    try {
      if (data['schema_version'] != 1 ||
          data['exported_at'] is! String ||
          data['profile'] is! Map ||
          data['saved'] is! List ||
          data['meal_plan'] is! Map ||
          data['history'] is! List) {
        throw const FormatException();
      }
      DateTime.parse(data['exported_at'] as String);
      final rawProfile = Map<String, dynamic>.from(data['profile'] as Map);
      final profile = Profile.fromJson(rawProfile);
      if (!['en', 'de'].contains(profile.lang) ||
          profile.name.length > 100 ||
          profile.maxTimeMinutes < 1 ||
          profile.maxTimeMinutes > 1440 ||
          profile.calorieTarget < 1 ||
          profile.calorieTarget > 10000 ||
          profile.calorieTolerance < 0 ||
          profile.calorieTolerance > 10000 ||
          !['easy', 'medium', 'hard'].contains(profile.preferredEffort)) {
        throw const FormatException();
      }
      for (final field in [
        'avoid_flags',
        'avoid_ingredients',
        'required_attributes',
      ]) {
        if (rawProfile[field] != null &&
            (rawProfile[field] is! List ||
                (rawProfile[field] as List).any((v) => v is! String))) {
          throw const FormatException();
        }
      }
      if ((data['saved'] as List).any((v) => v is! String)) {
        throw const FormatException();
      }
      if (data['saved_dates'] != null) {
        final dates = data['saved_dates'] as Map;
        if (dates.length != (data['saved'] as List).toSet().length ||
            dates.keys.any((id) => !(data['saved'] as List).contains(id))) {
          throw const FormatException();
        }
        for (final date in dates.values) {
          DateTime.parse(date as String);
        }
      }
      final weeks = data['meal_plan'] as Map;
      for (final entry in weeks.entries) {
        if (!RegExp(
              r'^\d{4}-W(0[1-9]|[1-4]\d|5[0-3])$',
            ).hasMatch(entry.key.toString()) ||
            entry.value is! Map) {
          throw const FormatException();
        }
        for (final slot in (entry.value as Map).entries) {
          if (!RegExp(
                r'^(mon|tue|wed|thu|fri|sat|sun)\.(breakfast|lunch|dinner)$',
              ).hasMatch(slot.key.toString()) ||
              slot.value is! String) {
            throw const FormatException();
          }
        }
      }
      for (final value in data['history'] as List) {
        final record = CookingRecord.fromJson(
          Map<String, dynamic>.from(value as Map),
        );
        if (record.servings < 1 || record.servings > 100) {
          throw const FormatException();
        }
      }
      for (final entry in (data['plan_servings'] as Map? ?? {}).entries) {
        final parts = (entry.key as String).split(':');
        if (parts.length != 2 ||
            (weeks[parts[0]] as Map?)?[parts[1]] == null ||
            entry.value is! int ||
            entry.value < 1 ||
            entry.value > 100) {
          throw const FormatException();
        }
      }
      if (data['cook_progress'] != null) {
        final progress = data['cook_progress'] as Map;
        if (progress['recipe_id'] is! String ||
            progress['step'] is! int ||
            progress['step'] < 0 ||
            progress['servings'] is! int ||
            progress['servings'] < 1 ||
            progress['servings'] > 20 ||
            progress['remaining_seconds'] is! int ||
            progress['remaining_seconds'] < 0 ||
            progress['remaining_seconds'] > 86400 ||
            progress['running'] is! bool ||
            (progress['timer_completed'] != null &&
                progress['timer_completed'] is! bool)) {
          throw const FormatException();
        }
        if (progress['deadline'] != null) {
          DateTime.parse(progress['deadline'] as String);
        } else if (progress['running'] == true) {
          throw const FormatException();
        }
      }
      if (data['content_requests'] != null &&
          (data['content_requests'] is! List ||
              (data['content_requests'] as List).any((v) => v is! String))) {
        throw const FormatException();
      }
      for (final value in data['shopping'] as List? ?? []) {
        final item = value as Map;
        if (item['ingredient_id'] is! String ||
            item['unit'] is! String ||
            item['aisle'] is! String ||
            item['quantity'] is! num ||
            (item['quantity'] as num) <= 0 ||
            !(item['quantity'] as num).isFinite ||
            item['checked'] is! bool ||
            (item['recipe_ids'] as List).any((v) => v is! String)) {
          throw const FormatException();
        }
      }
      for (final value in data['shopping_events'] as List? ?? []) {
        ShoppingEvent.fromJson(Map<String, dynamic>.from(value as Map));
      }
    } catch (_) {
      throw const DecryptionException(DecryptionReason.invalidFormat);
    }
  }
}
