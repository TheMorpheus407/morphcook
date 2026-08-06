import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/backup.dart';

BackupData _sample() => BackupData(
      profile: {
        'name': 'Ada',
        'lang': 'en',
        'avoid_flags': ['dairy'],
        'avoid_ingredients': ['cilantro'],
        'required_attributes': <String>[],
        'max_time_minutes': 45,
        'calorie_target': 600,
        'preferred_effort': 'easy',
        'show_variant_tags': true,
        'reduce_motion': null,
        'visual_alert_enabled': true,
        'quick_next_tap_enabled': false,
      },
      saved: ['doener-vegan', 'alfredo-classic'],
      mealPlan: {
        '2026-W16': {'mon.dinner': 'chili-classic'}
      },
      history: [
        {'r': 'doener-vegan', 'at': '2026-04-01T18:00:00.000'}
      ],
      contentRequests: ['pad thai', 'sushi'],
    );

void main() {
  group('backup format', () {
    test('schema_version 1 round-trips through plain JSON', () {
      final data = _sample();
      final bytes = BackupService.encodePlain(data);
      final parsed = BackupService.parse(bytes);
      expect(parsed.profile['name'], 'Ada');
      expect(parsed.saved, data.saved);
      expect(parsed.mealPlan['2026-W16'], {'mon.dinner': 'chili-classic'});
      expect(parsed.history.single['r'], 'doener-vegan');
      expect(parsed.contentRequests, ['pad thai', 'sushi']);
    });

    test('exported_at is written in UTC ISO-8601', () {
      final bytes = BackupService.encodePlain(_sample(),
          now: DateTime.utc(2026, 4, 18, 12));
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(json['schema_version'], 1);
      expect(json['exported_at'], '2026-04-18T12:00:00.000Z');
    });

    test('rejects unknown schema versions', () {
      final bytes = Uint8List.fromList(
          utf8.encode(jsonEncode({'schema_version': 99})));
      expect(
        () => BackupService.parse(bytes),
        throwsA(isA<DecryptionException>().having(
            (e) => e.reason, 'reason', DecryptionReason.invalidFormat)),
      );
    });
  });

  group('gzip', () {
    test('gz round-trips and is auto-detected', () {
      final gz = BackupService.encodeGzip(_sample());
      expect(isGzipBackup(gz), isTrue);
      expect(isEncryptedBackup(gz), isFalse);
      final parsed = BackupService.parse(gz);
      expect(parsed.saved, _sample().saved);
    });

    test('gzip actually compresses the JSON', () {
      final plain = BackupService.encodePlain(_sample());
      final gz = BackupService.encodeGzip(_sample());
      expect(gz.length, lessThan(plain.length));
    });
  });

  group('encryption (AES-256-GCM)', () {
    test('encrypted round-trip with the right password', () {
      final plain = BackupService.encodePlain(_sample());
      final sealed = BackupCrypto.encrypt(plain, 'correct horse');
      expect(isEncryptedBackup(sealed), isTrue);
      expect(sealed.sublist(0, 3), encryptionMagic);
      final opened = BackupCrypto.decrypt(sealed, 'correct horse');
      expect(opened, plain);
    });

    test('wrong password throws with actionable message', () {
      final sealed =
          BackupCrypto.encrypt(BackupService.encodePlain(_sample()), 'right');
      expect(
        () => BackupCrypto.decrypt(sealed, 'wrong'),
        throwsA(isA<DecryptionException>()
            .having((e) => e.reason, 'reason',
                DecryptionReason.wrongPassword)
            .having((e) => e.message, 'message',
                'Incorrect password. Please try again.')),
      );
    });

    test('each encryption uses a fresh salt and iv', () {
      final plain = BackupService.encodePlain(_sample());
      final a = BackupCrypto.encrypt(plain, 'pw');
      final b = BackupCrypto.encrypt(plain, 'pw');
      expect(a, isNot(equals(b)));
    });

    test('truncated payload reads as corrupted', () {
      final sealed =
          BackupCrypto.encrypt(BackupService.encodePlain(_sample()), 'pw');
      final truncated = Uint8List.fromList(sealed.sublist(0, 20));
      expect(
        () => BackupCrypto.decrypt(truncated, 'pw'),
        throwsA(isA<DecryptionException>().having(
            (e) => e.reason, 'reason', DecryptionReason.corrupted)),
      );
    });

    test('parse() demands a password for encrypted files', () {
      final sealed =
          BackupCrypto.encrypt(BackupService.encodePlain(_sample()), 'pw');
      expect(
        () => BackupService.parse(sealed),
        throwsA(isA<DecryptionException>().having(
            (e) => e.reason, 'reason', DecryptionReason.needsPassword)),
      );
      // and accepts it when provided
      expect(BackupService.parse(sealed, password: 'pw').saved,
          isNotEmpty);
    });
  });

  group('magic-byte detection', () {
    test('plain JSON is neither encrypted nor gzip', () {
      final plain = BackupService.encodePlain(_sample());
      expect(isEncryptedBackup(plain), isFalse);
      expect(isGzipBackup(plain), isFalse);
    });

    test('garbage bytes are reported as not a valid backup', () {
      final garbage = Uint8List.fromList(utf8.encode('not json at all'));
      expect(
        () => BackupService.parse(garbage),
        throwsA(isA<DecryptionException>().having(
            (e) => e.reason, 'reason', DecryptionReason.invalidFormat)),
      );
    });
  });

  group('exportToDirectory', () {
    test('writes both files side by side', () async {
      final dir = await Directory.systemTemp.createTemp('morphcook_test');
      addTearDown(() => dir.delete(recursive: true));
      final paths = await BackupService.exportToDirectory(
        _sample(),
        dir,
        password: 'secret',
      );
      expect(paths.length, 2);
      expect(paths[0], endsWith('morphcook-backup.json'));
      expect(paths[1], endsWith('morphcook-backup.json.gz'));
      final jsonBytes = await File(paths[0]).readAsBytes();
      final gzBytes = await File(paths[1]).readAsBytes();
      // json is encrypted, gz is not
      expect(isEncryptedBackup(jsonBytes), isTrue);
      expect(isGzipBackup(gzBytes), isTrue);
      // gz stays readable without the password
      expect(BackupService.parse(gzBytes).saved, isNotEmpty);
    });
  });
}
