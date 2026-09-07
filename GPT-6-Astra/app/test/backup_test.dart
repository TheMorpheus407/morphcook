import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/backup.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/repository.dart';

Map<String, dynamic> fixture() => {
  'schema_version': 1,
  'exported_at': '2026-09-07T12:00:00Z',
  'profile': Profile(
    name: 'Mira',
    lang: 'de',
    avoidFlags: {'dairy'},
    reduceMotion: true,
  ).toJson(),
  'saved': ['doener-vegan'],
  'meal_plan': {
    '2026-W37': {'mon.dinner': 'doener-vegan'},
  },
  'history': [
    {'recipe_id': 'doener-vegan', 'cooked_at': '2026-09-01T12:00:00Z'},
  ],
  'content_requests': ['sushi'],
  'shopping': [
    {
      'id': 'item-1',
      'ingredient_id': 'garlic',
      'quantity': 5,
      'unit': 'clove',
      'checked': true,
    },
  ],
  'shopping_history': [
    {
      'id': 'event-1',
      'ingredient_id': 'garlic',
      'added_at': '2026-09-01T12:00:00Z',
      'count': 1,
    },
  ],
  'cook_progress': {
    'recipe_id': 'doener-vegan',
    'step': 2,
    'remaining_seconds': 15,
  },
};

void main() {
  test('readable JSON and GZip both round-trip all local state', () async {
    final data = fixture();
    final files = await BackupService.encode(data);
    expect(utf8.decode(files.jsonBytes), contains('\n  "schema_version"'));
    expect(files.gzipBytes.take(2), [0x1f, 0x8b]);
    expect(files.gzipBytes.length, lessThan(files.jsonBytes.length));
    expect(await BackupService.decode(files.jsonBytes), data);
    expect(await BackupService.decode(files.gzipBytes), data);
  });

  test('AES-256-GCM round-trip and fresh salt/nonce for each export', () async {
    final first = await BackupService.encode(
      fixture(),
      password: 'long cozy password',
    );
    final second = await BackupService.encode(
      fixture(),
      password: 'long cozy password',
    );
    expect(BackupService.isEncrypted(first.jsonBytes), isTrue);
    expect(first.jsonBytes.take(3), [0x45, 0x4e, 0x43]);
    expect(first.jsonBytes, isNot(second.jsonBytes));
    expect(
      await BackupService.decode(
        first.jsonBytes,
        password: 'long cozy password',
      ),
      fixture(),
    );
    expect(
      await BackupService.decode(first.gzipBytes),
      fixture(),
      reason: 'Companion GZip stays unencrypted by specification',
    );
  });

  test(
    'encrypted import requests password and reports wrong password actionably',
    () async {
      final encrypted = (await BackupService.encode(
        fixture(),
        password: 'correct',
      )).jsonBytes;
      await expectLater(
        BackupService.decode(encrypted),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionReason.passwordRequired,
          ),
        ),
      );
      await expectLater(
        BackupService.decode(encrypted, password: 'wrong'),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.message,
            'message',
            'Incorrect password. Please try again.',
          ),
        ),
      );
    },
  );

  test(
    'truncated encrypted and broken compressed files report corruption',
    () async {
      await expectLater(
        BackupService.decode([0x45, 0x4e, 0x43, 1]),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionReason.corrupted,
          ),
        ),
      );
      await expectLater(
        BackupService.decode([0x1f, 0x8b, 0xff, 0x01]),
        throwsA(
          isA<DecryptionException>().having(
            (e) => e.reason,
            'reason',
            DecryptionReason.corrupted,
          ),
        ),
      );
    },
  );

  test('authenticated ciphertext modification is rejected', () async {
    final encrypted = (await BackupService.encode(
      fixture(),
      password: 'correct',
    )).jsonBytes;
    encrypted[encrypted.length - 1] ^= 0x01;
    await expectLater(
      BackupService.decode(encrypted, password: 'correct'),
      throwsA(isA<DecryptionException>()),
    );
  });

  test(
    'invalid schema, wrong field types and non-backups are rejected',
    () async {
      for (final data in [
        {...fixture(), 'schema_version': 2},
        {...fixture(), 'saved': 'not-an-array'},
        {
          ...fixture(),
          'profile': {'reduceMotion': 'yes'},
        },
        {
          ...fixture(),
          'profile': {'max_time_minutes': 99999},
        },
        {
          ...fixture(),
          'profile': {'preferred_effort': 'impossible'},
        },
        {
          ...fixture(),
          'cook_progress': {'recipe_id': 'r', 'step': 'bad'},
        },
        {
          ...fixture(),
          'history': [
            {'recipe_id': 'r', 'cooked_at': 'invalid'},
          ],
        },
        {
          ...fixture(),
          'shopping': [
            {'id': 'i', 'quantity': -1},
          ],
        },
      ]) {
        await expectLater(
          BackupService.decode(utf8.encode(jsonEncode(data))),
          throwsA(isA<DecryptionException>()),
        );
      }
      await expectLater(
        BackupService.decode(utf8.encode('a grocery receipt')),
        throwsA(isA<DecryptionException>()),
      );
    },
  );

  test(
    'optional content requests and new extension fields preserve compatibility',
    () async {
      final data = fixture()..remove('content_requests');
      data['future_extension'] = {'lang': 'fr'};
      final encoded = await BackupService.encode(data);
      expect(await BackupService.decode(encoded.jsonBytes), data);
    },
  );

  test(
    'replace restores profile and all collections including cooking progress',
    () async {
      final state = AppState.inMemory(
        repo: Repository.empty(),
        profile: Profile(name: 'Old'),
      );
      state.toggleSaved('old-recipe');
      await state.importBackup(fixture());
      expect(state.profile.name, 'Mira');
      expect(state.profile.reduceMotion, isTrue);
      expect(state.saved, ['doener-vegan']);
      expect(state.shopping.single.checked, isTrue);
      expect(state.cookProgress['step'], 2);
      expect(state.exportBackup()['content_requests'], ['sushi']);
      state.dispose();
    },
  );

  test(
    'merge is idempotent and keeps local profile and occupied meal slots',
    () async {
      final state = AppState.inMemory(
        repo: Repository.empty(),
        profile: Profile(name: 'Local'),
      );
      state.toggleSaved('local-recipe');
      state.assignMeal('2026-W37', 'mon.dinner', 'local-recipe');
      await state.importBackup(fixture(), merge: true);
      await state.importBackup(fixture(), merge: true);
      expect(state.profile.name, 'Local');
      expect(state.saved, ['local-recipe', 'doener-vegan']);
      expect(state.mealPlan['2026-W37']!['mon.dinner'], 'local-recipe');
      expect(state.history.length, 1);
      expect(state.shopping.length, 1);
      expect(state.shoppingHistory.length, 1);
      state.dispose();
    },
  );

  test('invalid restore leaves existing state intact', () async {
    final state = AppState.inMemory(
      repo: Repository.empty(),
      profile: Profile(name: 'Local'),
    );
    state.toggleSaved('local-recipe');
    await expectLater(
      state.importBackup({...fixture(), 'shopping': 'bad'}),
      throwsA(isA<DecryptionException>()),
    );
    expect(state.profile.name, 'Local');
    expect(state.saved, ['local-recipe']);
    state.dispose();
  });

  test(
    'restore orders event timestamps chronologically across time zones',
    () async {
      final state = AppState.inMemory(repo: Repository.empty());
      final data = fixture();
      data['history'] = [
        {'recipe_id': 'earlier', 'cooked_at': '2026-09-01T10:00:00+02:00'},
        {'recipe_id': 'later', 'cooked_at': '2026-09-01T09:00:00Z'},
      ];
      await state.importBackup(data);
      expect(state.history.map((event) => event['recipe_id']), [
        'later',
        'earlier',
      ]);
      state.dispose();
    },
  );
}
