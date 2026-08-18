import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/core/models/profile.dart';
import 'package:morphcook/core/models/user_data.dart';
import 'package:morphcook/core/services/backup_crypto.dart';
import 'package:morphcook/core/services/backup_service.dart';

BackupPayload _payload() => BackupPayload(
      profile: Profile(name: 'ada', lang: 'de')
        ..avoidFlags.add('vegan')
        ..calorieTarget = 600,
      saved: ['doener-vegan', 'ramen-halal'],
      mealPlan: {
        '2026-W33': {'mon.dinner': 'doener-vegan'}
      },
      history: [HistoryEntry(recipeId: 'doener-vegan', at: DateTime(2026, 8, 10), servings: 2)],
      contentRequests: [ContentRequest(query: 'pad see ew', at: DateTime(2026, 8, 11))],
    );

void main() {
  test('backup json follows the SPEC schema', () {
    final json = BackupService.buildJson(_payload());
    final map = jsonDecode(json) as Map<String, dynamic>;
    expect(map['schema_version'], 1);
    expect(map['exported_at'], isNotNull);
    expect(map['profile'], isA<Map>());
    expect(map['saved'], ['doener-vegan', 'ramen-halal']);
    expect((map['meal_plan'] as Map)['2026-W33']['mon.dinner'], 'doener-vegan');
    expect(map['history'], isA<List>());
    expect(map['content_requests'], isA<List>());
    // Human-readable: indented.
    expect(json.contains('\n  '), isTrue);
  });

  test('plain json round-trip', () {
    final export = BackupService.buildExport(_payload());
    final document = BackupService.importBytes(export.jsonBytes);
    expect(document.profile.name, 'ada');
    expect(document.profile.avoidFlags, {'vegan'});
    expect(document.saved.length, 2);
    expect(document.mealPlan['2026-W33'], isNotNull);
    expect(document.history.single.recipeId, 'doener-vegan');
    expect(document.contentRequests.single.query, 'pad see ew');
  });

  test('gzip round-trip and detection', () {
    final export = BackupService.buildExport(_payload());
    expect(BackupService.isGzip(export.gzipBytes), isTrue);
    // Compression should meaningfully shrink the pretty-printed json
    // (SPEC: 70–90% for JSON data; assert at least 40% here for stability).
    expect(export.compressionRatio, lessThan(0.6));
    final document = BackupService.importBytes(export.gzipBytes);
    expect(document.profile.name, 'ada');
  });

  test('encrypted export: json encrypted with ENC magic, gzip stays plain', () {
    final export = BackupService.buildExport(_payload(), password: 'kitchen-secret');
    expect(BackupCrypto.isEncrypted(export.jsonBytes), isTrue);
    expect(BackupService.isGzip(export.gzipBytes), isTrue);
    expect(BackupCrypto.isEncrypted(export.gzipBytes), isFalse);
  });

  test('import detects encrypted payload and demands the password (SPEC)', () {
    final export = BackupService.buildExport(_payload(), password: 'pw');
    expect(
      () => BackupService.importBytes(export.jsonBytes),
      throwsA(isA<DecryptionException>()
          .having((e) => e.reason, 'reason', DecryptionReason.needsPassword)),
    );
  });

  test('encrypted round-trip with correct password (AES-256-GCM + PBKDF2)', () {
    final export = BackupService.buildExport(_payload(), password: 'pw');
    final document = BackupService.importEncrypted(export.jsonBytes, 'pw');
    expect(document.profile.name, 'ada');
    expect(document.saved, ['doener-vegan', 'ramen-halal']);
  });

  test('wrong password fails with the SPEC message, never corrupted data', () {
    final export = BackupService.buildExport(_payload(), password: 'pw');
    expect(
      () => BackupService.importEncrypted(export.jsonBytes, 'wrong'),
      throwsA(isA<DecryptionException>()
          .having((e) => e.reason, 'reason', DecryptionReason.wrongPassword)
          .having((e) => e.message('en'), 'message',
              'Incorrect password. Please try again.')
          .having((e) => e.message('de'), 'message',
              'Falsches Passwort. Bitte erneut versuchen.')),
    );
  });

  test('structurally broken encrypted payload reports corruption', () {
    final export = BackupService.buildExport(_payload(), password: 'pw');
    // Too short to even hold magic + salt + iv + tag → corrupted.
    final stub = export.jsonBytes.sublist(0, 30);
    expect(
      () => BackupService.importEncrypted(stub, 'pw'),
      throwsA(isA<DecryptionException>()
          .having((e) => e.reason, 'reason', DecryptionReason.corrupted)),
    );
  });

  test('tampered ciphertext fails authentication (wrong password message)', () {
    final export = BackupService.buildExport(_payload(), password: 'pw');
    // Flip a byte in the middle — GCM authentication must reject it; the
    // actionable message is the password one (AEAD cannot distinguish
    // tampering from a wrong key).
    final tampered = [...export.jsonBytes];
    tampered[tampered.length - 10] ^= 0x01;
    expect(
      () => BackupService.importEncrypted(tampered, 'pw'),
      throwsA(isA<DecryptionException>()
          .having((e) => e.reason, 'reason', DecryptionReason.wrongPassword)),
    );
  });

  test('non-backup files report invalid format', () {
    expect(
      () => BackupService.importBytes(utf8.encode('just some text')),
      throwsA(isA<DecryptionException>()
          .having((e) => e.reason, 'reason', DecryptionReason.invalidFormat)),
    );
    // Wrong schema version is rejected too.
    final futureJson = jsonEncode({'schema_version': 2});
    expect(
      () => BackupService.importBytes(utf8.encode(futureJson)),
      throwsA(isA<DecryptionException>()),
    );
  });

  test('encryption uses unique salt + iv per run', () {
    final a = BackupService.buildExport(_payload(), password: 'pw');
    final b = BackupService.buildExport(_payload(), password: 'pw');
    // Same plaintext, different bytes (unique salt/iv per SPEC).
    expect(a.jsonBytes.length, b.jsonBytes.length);
    expect(a.jsonBytes, isNot(b.jsonBytes));
  });
}
