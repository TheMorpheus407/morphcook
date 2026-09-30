import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/backup.dart';
import 'fixtures.dart';

void main() {
  final service = BackupService();
  test('plain JSON is readable, indented and round trips', () async {
    final data = backupFixture();
    final files = await service.export(data);
    expect(files.encrypted, isFalse);
    expect(utf8.decode(files.json), contains('\n  "schema_version": 1'));
    expect(await service.import(files.json), data);
    expect(await service.import(files.compressed), data);
    expect(gzip.decode(files.compressed), files.json);
  });
  test('password encrypts JSON and leaves GZip unencrypted', () async {
    final data = backupFixture();
    final files = await service.export(
      data,
      password: 'a strong little password',
    );
    expect(files.json.take(3).toList(), [0x45, 0x4e, 0x43]);
    expect(files.encrypted, isTrue);
    expect(
      () => jsonDecode(utf8.decode(files.json, allowMalformed: true)),
      throwsFormatException,
    );
    expect(files.compressed.take(2).toList(), [0x1f, 0x8b]);
    expect(await service.import(files.compressed), data);
    expect(
      await service.import(files.json, password: 'a strong little password'),
      data,
    );
    await expectLater(
      service.import(files.json),
      throwsA(
        isA<DecryptionException>().having(
          (e) => e.reason,
          'reason',
          DecryptionReason.passwordRequired,
        ),
      ),
    );
  });
  test(
    'wrong password, invalid format and damaged GZip have actionable reasons',
    () async {
      final encrypted = await service.export(
        backupFixture(),
        password: 'correct',
      );
      await expectLater(
        service.import(encrypted.json, password: 'wrong'),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.message,
            'message',
            'Incorrect password. Please try again.',
          ),
        ),
      );
      await expectLater(
        service.import([0x45, 0x4e, 0x43, 1], password: 'correct'),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionReason.corrupted,
          ),
        ),
      );
      await expectLater(
        service.import([0x1f, 0x8b, 1, 2, 3]),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionReason.corrupted,
          ),
        ),
      );
      await expectLater(
        service.import(utf8.encode('not JSON')),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionReason.invalidFormat,
          ),
        ),
      );
    },
  );
  test('fresh salt and IV are used for every export', () async {
    final first = await service.export(backupFixture(), password: 'correct');
    final second = await service.export(backupFixture(), password: 'correct');
    expect(first.json.sublist(4, 20), isNot(second.json.sublist(4, 20)));
    expect(first.json.sublist(20, 32), isNot(second.json.sublist(20, 32)));
    expect(
      await service.import(first.json, password: 'correct'),
      await service.import(second.json, password: 'correct'),
    );
  });
  test('authenticated encryption rejects altered ciphertext', () async {
    final files = await service.export(backupFixture(), password: 'correct');
    final damaged = [...files.json];
    damaged[damaged.length - 1] ^= 1;
    await expectLater(
      service.import(damaged, password: 'correct'),
      throwsA(isA<DecryptionException>()),
    );
  });
  test('compression is effective for a realistic growing journal', () async {
    final data = backupFixture();
    data['history'] = List.generate(
      1000,
      (i) => {
        'recipe_id': 'doener-mushroom',
        'cooked_at': DateTime.utc(
          2026,
          1,
          1,
        ).add(Duration(hours: i)).toIso8601String(),
        'servings': 2,
      },
    );
    final files = await service.export(data);
    expect(files.compressed.length / files.json.length, lessThan(.3));
    expect(await service.import(files.compressed), data);
  });
  test(
    'optional content requests and future private profile fields survive',
    () async {
      final data = backupFixture()..remove('content_requests');
      (data['profile'] as Map)['b2b'] = {
        'company': 'Example',
        'notes': 'Private',
      };
      final files = await service.export(data, password: 'private');
      expect(await service.import(files.json, password: 'private'), data);
    },
  );
  for (final mutation in <String, void Function(Map<String, dynamic>)>{
    'schema': (data) => data['schema_version'] = 2,
    'profile': (data) => data['profile'] = [],
    'language': (data) => (data['profile'] as Map)['lang'] = 'invalid',
    'time': (data) => (data['profile'] as Map)['max_time_minutes'] = -1,
    'saved': (data) => data['saved'] = [1],
    'week': (data) => data['meal_plan'] = {'2026-W99': {}},
    'slot': (data) => data['meal_plan'] = {
      '2026-W40': {'mon.snack': 'doener-mushroom'},
    },
    'history': (data) => data['history'] = [
      {'recipe_id': 'a', 'cooked_at': 'invalid'},
    ],
    'requests': (data) => data['content_requests'] = [1],
    'export date': (data) => data['exported_at'] = 'invalid',
    'shopping': (data) => data['shopping'] = [
      {'ingredient_id': 'garlic', 'quantity': -2},
    ],
    'saved dates': (data) => data['saved_dates'] = {'unknown': 'invalid'},
    'plan servings': (data) =>
        data['plan_servings'] = {'2026-W40:mon.dinner': -1},
    'cook progress': (data) =>
        data['cook_progress'] = {'recipe_id': 'a', 'step': 'one'},
  }.entries) {
    test('malformed ${mutation.key} is rejected before restoration', () async {
      final data = backupFixture();
      mutation.value(data);
      await expectLater(
        service.import(utf8.encode(jsonEncode(data))),
        throwsA(isA<DecryptionException>()),
      );
    });
  }
}
