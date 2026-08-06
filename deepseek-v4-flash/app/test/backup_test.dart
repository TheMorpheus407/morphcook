import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/models.dart';
import 'package:morphcook/services/backup_service.dart';

BackupPayload _payload() => BackupPayload(
      profile: UserProfile(
        name: 'ada',
        lang: 'en',
        avoidFlags: {'vegan'},
        avoidIngredients: {'garlic'},
        calorieTarget: 600,
        maxTimeMinutes: 45,
      ),
      saved: [
        SavedEntry(recipeId: 'r1', savedAt: DateTime(2026, 1, 2)),
        SavedEntry(recipeId: 'r2', savedAt: DateTime(2026, 1, 5)),
      ],
      history: [
        HistoryEntry(recipeId: 'r1', at: DateTime(2026, 2, 1)),
      ],
      mealPlan: {
        '2026-W32': {
          'mon.dinner': 'r1',
          'tue.lunch': 'r2',
        },
      },
      contentRequests: ['a vegan döner with more spice'],
      shoppingLines: [
        ShoppingLine(recipeId: 'r1', addedAt: DateTime(2026, 3, 1), servings: 4),
      ],
    );

void main() {
  group('plain backups (gzip + magic)', () {
    test('roundtrip', () {
      final bytes = BackupCoder.encodePlain(_payload());
      // magic + version + gzip payload
      expect(bytes.sublist(0, 4), BackupFormat.plainMagic);
      expect(bytes[4], BackupFormat.schemaVersion);
      expect(bytes.length, greaterThan(100)); // gzip has content

      final out = BackupCoder.decodePlain(bytes);
      expect(out.profile.name, 'ada');
      expect(out.profile.avoidIngredients, {'garlic'});
      expect(out.saved.map((e) => e.recipeId), ['r1', 'r2']);
      expect(out.mealPlan['2026-W32']!['mon.dinner'], 'r1');
      expect(out.contentRequests, ['a vegan döner with more spice']);
      expect(out.shoppingLines.single.servings, 4);
    });

    test('rejects non-backup bytes', () {
      expect(
        () => BackupCoder.decodePlain(Uint8List.fromList([1, 2, 3, 4, 5, 6])),
        throwsA(isA<BackupException>()
            .having((e) => e.type, 'type', BackupErrorType.notMorphcook)),
      );
    });

    test('rejects corrupted gzip', () {
      final bytes = BackupCoder.encodePlain(_payload());
      final corrupted = Uint8List.fromList([
        ...bytes.sublist(0, 8),
        0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01, 0x02, 0x03,
      ]);
      expect(
        () => BackupCoder.decodePlain(corrupted),
        throwsA(isA<BackupException>()
            .having((e) => e.type, 'type', BackupErrorType.corrupted)),
      );
    });
  });

  group('encrypted backups (AES-256-GCM)', () {
    test('roundtrip with password', () {
      final bytes = BackupCrypto.encodeEncrypted(_payload(), 's3cret');
      expect(bytes.sublist(0, 4), BackupFormat.encMagic);
      final out = BackupCrypto.decodeEncrypted(bytes, 's3cret');
      expect(out.profile.lang, 'en');
      expect(out.history.single.recipeId, 'r1');
    });

    test('wrong password fails with wrongPassword', () {
      final bytes = BackupCrypto.encodeEncrypted(_payload(), 'right');
      expect(
        () => BackupCrypto.decodeEncrypted(bytes, 'wrong'),
        throwsA(isA<BackupException>()
            .having((e) => e.type, 'type', BackupErrorType.wrongPassword)),
      );
    });

    test('tampered ciphertext fails authentication', () {
      final bytes = BackupCrypto.encodeEncrypted(_payload(), 's3cret');
      final tampered = Uint8List.fromList(bytes);
      tampered[tampered.length - 1] ^= 0x01;
      expect(
        () => BackupCrypto.decodeEncrypted(tampered, 's3cret'),
        throwsA(isA<BackupException>()
            .having((e) => e.type, 'type', BackupErrorType.wrongPassword)),
      );
    });

    test('encryption is non-deterministic (fresh salt/iv each time)', () {
      final a = BackupCrypto.encodeEncrypted(_payload(), 'pw');
      final b = BackupCrypto.encodeEncrypted(_payload(), 'pw');
      expect(a, isNot(equals(b)));
    });

    test('different passwords do not produce the same file', () {
      final a = BackupCrypto.encodeEncrypted(_payload(), 'one');
      final b = BackupCrypto.encodeEncrypted(_payload(), 'two');
      expect(a, isNot(equals(b)));
    });

    test('format detection', () {
      expect(
          BackupCrypto.isEncrypted(
              BackupCrypto.encodeEncrypted(_payload(), 'pw')),
          isTrue);
      expect(
          BackupCrypto.isPlain(BackupCoder.encodePlain(_payload())),
          isTrue);
      expect(
          BackupCrypto.isEncrypted(BackupCoder.encodePlain(_payload())),
          isFalse);
    });
  });

  group('BackupService (end-to-end)', () {
    test('plain path via service', () {
      final bytes = BackupService.encode(_payload());
      final out = BackupService.decode(bytes);
      expect(out.saved, hasLength(2));
    });

    test('encrypted path via service', () {
      final bytes = BackupService.encode(_payload(), password: 'pw');
      final out = BackupService.decode(bytes, password: 'pw');
      expect(out.shoppingLines.single.recipeId, 'r1');
    });

    test('encrypted file without password gives wrongPassword', () {
      final bytes = BackupService.encode(_payload(), password: 'pw');
      expect(
        () => BackupService.decode(bytes),
        throwsA(isA<BackupException>()
            .having((e) => e.type, 'type', BackupErrorType.wrongPassword)),
      );
    });

    test('foreign bytes give notMorphcook', () {
      final bytes = Uint8List.fromList(utf8.encode('{"hello": "world"}'));
      expect(
        () => BackupService.decode(bytes),
        throwsA(isA<BackupException>()
            .having((e) => e.type, 'type', BackupErrorType.notMorphcook)),
      );
    });

    test('valid gzip but wrong json schema gives corrupted/notMorphcook', () {
      final payload = BackupPayload(
        profile: UserProfile(),
        saved: const [],
        history: const [],
        mealPlan: const {},
        contentRequests: const [],
      );
      final bytes = BackupCoder.encodePlain(payload);
      // corrupt the json inside (flip a byte in the gzip body)
      final body = Uint8List.fromList(bytes);
      final idx = body.length - 2;
      body[idx] = body[idx] ^ 0xFF;
      expect(
        () => BackupService.decode(body),
        throwsA(isA<BackupException>()),
      );
    });

    test('json payload survives utf8 with umlauts', () {
      final payload = BackupPayload(
        profile: UserProfile(name: 'jörg', lang: 'de'),
        saved: const [],
        history: const [],
        mealPlan: const {},
        contentRequests: const ['weiße Soße'],
      );
      final bytes = BackupService.encode(payload);
      final out = BackupService.decode(bytes);
      expect(out.profile.name, 'jörg');
      expect(out.contentRequests, ['weiße Soße']);
    });
  });
}