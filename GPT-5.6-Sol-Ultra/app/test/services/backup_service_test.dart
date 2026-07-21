import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/services/backup_service.dart';

void main() {
  late BackupService service;
  late BackupData data;

  setUp(() {
    service = BackupService();
    data = BackupData(
      profile: <String, dynamic>{'name': 'Mira', 'lang': 'de'},
      saved: const <String>['doener-vegan'],
      mealPlan: const <String, Map<String, String>>{
        '2026-W16': <String, String>{'mon.dinner': 'doener-vegan'},
      },
      history: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'history-1',
          'recipe_id': 'doener-vegan',
          'cooked_at': '2026-04-18T12:00:00.000Z',
        },
      ],
      contentRequests: const <String>['sushi'],
      shoppingEntries: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'garlic', 'quantity': 5},
      ],
      exportedAt: DateTime.utc(2026, 4, 18, 12),
    );
  });

  test('exports human-readable schema 1 JSON and round-trips it', () async {
    final bundle = await service.export(data);

    expect(bundle.jsonEncrypted, isFalse);
    expect(service.detectEncoding(bundle.jsonBytes), BackupEncoding.json);
    final text = utf8.decode(bundle.jsonBytes);
    expect(text, contains('\n  "schema_version": 1'));
    expect(text, contains('"content_requests"'));

    final restored = await service.import(bundle.jsonBytes);
    expect(restored.toJson(), data.toJson());
  });

  test('auto-detects GZip and keeps it unencrypted with a password', () async {
    final bundle = await service.export(data, password: 'paper-and-ink');

    expect(bundle.jsonEncrypted, isTrue);
    expect(service.detectEncoding(bundle.jsonBytes), BackupEncoding.encrypted);
    expect(service.detectEncoding(bundle.gzipBytes), BackupEncoding.gzip);
    final restored = await service.import(bundle.gzipBytes);
    expect(restored.profile['name'], 'Mira');
    expect(restored.saved, <String>['doener-vegan']);
  });

  test('AES-256-GCM output uses ENC magic and unique salt/IV', () async {
    final first = await service.export(data, password: 'secret');
    final second = await service.export(data, password: 'secret');

    expect(first.jsonBytes.take(3), BackupService.encryptionMagic);
    expect(second.jsonBytes.take(3), BackupService.encryptionMagic);
    // Byte 3 is the format version; bytes 4..31 hold salt + IV.
    expect(
      first.jsonBytes.sublist(4, 32),
      isNot(orderedEquals(second.jsonBytes.sublist(4, 32))),
    );

    final restored = await service.import(first.jsonBytes, password: 'secret');
    expect(restored.mealPlan, data.mealPlan);
  });

  test('encrypted import reports that a password is required', () async {
    final bundle = await service.export(data, password: 'secret');

    await expectLater(
      service.import(bundle.jsonBytes),
      throwsA(
        isA<DecryptionException>().having(
          (error) => error.message,
          'message',
          'This backup is encrypted. Please enter its password.',
        ),
      ),
    );
  });

  test(
    'distinguishes an incorrect password from corrupted ciphertext',
    () async {
      final bundle = await service.export(data, password: 'right password');

      await expectLater(
        service.import(bundle.jsonBytes, password: 'wrong password'),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.message,
            'message',
            'Incorrect password. Please try again.',
          ),
        ),
      );

      final corrupted = List<int>.of(bundle.jsonBytes);
      corrupted[corrupted.length - 20] ^= 0xff;
      await expectLater(
        service.import(corrupted, password: 'right password'),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.message,
            'message',
            'Backup file is corrupted and cannot be restored.',
          ),
        ),
      );

      final corruptedHeader = List<int>.of(bundle.jsonBytes)..[4] ^= 0xff;
      await expectLater(
        service.import(corruptedHeader, password: 'right password'),
        throwsA(
          isA<DecryptionException>().having(
            (error) => error.message,
            'message',
            'Backup file is corrupted and cannot be restored.',
          ),
        ),
      );
    },
  );

  test('rejects invalid encrypted version and invalid plain JSON', () async {
    final bundle = await service.export(data, password: 'secret');
    final unsupported = List<int>.of(bundle.jsonBytes)..[3] = 99;
    await expectLater(
      service.import(unsupported, password: 'secret'),
      throwsA(
        isA<DecryptionException>().having(
          (error) => error.message,
          'message',
          'This file is not a valid MorphCook backup.',
        ),
      ),
    );

    await expectLater(
      service.import(utf8.encode('not json')),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('validates schema version', () async {
    final invalid = utf8.encode(
      jsonEncode(<String, dynamic>{
        'schema_version': 2,
        'exported_at': '2026-01-01T00:00:00Z',
        'profile': <String, dynamic>{},
        'saved': <String>[],
        'meal_plan': <String, dynamic>{},
        'history': <dynamic>[],
      }),
    );

    await expectLater(
      service.import(invalid),
      throwsA(
        isA<BackupFormatException>().having(
          (error) => error.message,
          'message',
          contains('Unsupported backup schema version: 2'),
        ),
      ),
    );
  });

  test('caps decompressed GZip backups', () async {
    final compressed = gzip.encode(
      List<int>.filled(BackupService.maxBackupBytes + 1, 0),
    );
    await expectLater(
      service.import(compressed),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test('merge unions collections and lets imported slots win', () {
    final current = BackupData(
      profile: <String, dynamic>{'name': 'Old', 'lang': 'en'},
      saved: const <String>['a'],
      mealPlan: const <String, Map<String, String>>{
        '2026-W16': <String, String>{'mon.dinner': 'old', 'tue.dinner': 'keep'},
      },
      history: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'h1', 'recipe_id': 'old'},
      ],
      contentRequests: const <String>['sushi'],
    );
    final imported = BackupData(
      profile: <String, dynamic>{'name': 'New'},
      saved: const <String>['b'],
      mealPlan: const <String, Map<String, String>>{
        '2026-W16': <String, String>{'mon.dinner': 'new'},
      },
      history: <Map<String, dynamic>>[
        <String, dynamic>{'id': 'h2', 'recipe_id': 'new'},
      ],
      contentRequests: const <String>[' SUSHI ', 'ramen'],
    );

    final merged = service.merge(current, imported, mode: RestoreMode.merge);
    expect(merged.profile, <String, dynamic>{'name': 'New', 'lang': 'en'});
    expect(merged.saved, <String>['a', 'b']);
    expect(merged.mealPlan['2026-W16'], <String, String>{
      'mon.dinner': 'new',
      'tue.dinner': 'keep',
    });
    expect(merged.history.map((entry) => entry['id']), <String>['h1', 'h2']);
    expect(merged.contentRequests.map((value) => value.toLowerCase()), <String>[
      'sushi',
      'ramen',
    ]);
  });

  test('replace drops current collections', () {
    final current = BackupData(
      profile: <String, dynamic>{'name': 'Old'},
      saved: const <String>['old'],
      mealPlan: const <String, Map<String, String>>{},
      history: const <Map<String, dynamic>>[],
    );
    final imported = BackupData(
      profile: <String, dynamic>{'name': 'New'},
      saved: const <String>['new'],
      mealPlan: const <String, Map<String, String>>{},
      history: const <Map<String, dynamic>>[],
    );

    final replaced = service.merge(
      current,
      imported,
      mode: RestoreMode.replace,
    );
    expect(replaced.profile['name'], 'New');
    expect(replaced.saved, <String>['new']);
  });
}
