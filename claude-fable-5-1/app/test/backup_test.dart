import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/meal_plan.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/backup_codec.dart';
import 'package:morphcook/domain/backup_crypto.dart';

BackupData sample() => BackupData(
      exportedAt: DateTime.utc(2026, 4, 18, 12),
      profile: const Profile(name: 'cedric', lang: 'de', avoidFlags: {'vegan'}, calorieTarget: 600, onboardingComplete: true),
      saved: const ['doener-vegan-easy', 'alfredo-vegan-easy'],
      mealPlan: MealPlan({
        '2026-W16': {'mon.dinner': 'doener-vegan-easy'}
      }),
      history: [HistoryEntry(recipeId: 'doener-vegan-easy', dishId: 'doener', cookedAt: DateTime.utc(2026, 4, 10, 18), servings: 2)],
      contentRequests: const ['pad thai', 'sushi'],
    );

void main() {
  test('json matches the documented shape', () {
    final j = jsonDecode(BackupCodec.encodeJsonString(sample())) as Map;
    expect(j['schema_version'], 1);
    expect(j['exported_at'], '2026-04-18T12:00:00.000Z');
    expect(j['profile']['name'], 'cedric');
    expect(j['saved'], ['doener-vegan-easy', 'alfredo-vegan-easy']);
    expect(j['meal_plan']['2026-W16']['mon.dinner'], 'doener-vegan-easy');
    expect(j['history'], hasLength(1));
    expect(j['content_requests'], ['pad thai', 'sushi']);
  });

  test('plain, gzip and encrypted round-trip', () {
    final data = sample();
    final plain = BackupCodec.encodeJson(data);
    final gz = BackupCodec.encodeGzip(data);
    final enc = BackupCodec.encodeJson(data, password: 'hunter2');
    expect(BackupCodec.detectFormat(plain), BackupFormat.json);
    expect(BackupCodec.detectFormat(gz), BackupFormat.gzip);
    expect(BackupCodec.detectFormat(enc), BackupFormat.encrypted);
    expect(enc.sublist(0, 3), [0x45, 0x4E, 0x43]);
    for (final bytes in [plain, gz]) {
      final back = BackupCodec.decode(bytes);
      expect(back.saved, data.saved);
      expect(back.profile.name, 'cedric');
      expect(back.mealPlan.recipeAt('2026-W16', 'mon.dinner'), 'doener-vegan-easy');
    }
    final dec = BackupCodec.decode(enc, password: 'hunter2');
    expect(dec.contentRequests, ['pad thai', 'sushi']);
  });

  test('gzip is much smaller for a realistic backup', () {
    final big = BackupData(
      exportedAt: DateTime.now(),
      profile: const Profile(),
      saved: List.generate(200, (i) => 'recipe-$i'),
      mealPlan: MealPlan(),
      history: List.generate(300, (i) => HistoryEntry(recipeId: 'recipe-${i % 30}', dishId: 'd', cookedAt: DateTime(2026, 1, 1).add(Duration(days: i)), servings: 2)),
    );
    final plain = BackupCodec.encodeJson(big).length;
    final gz = BackupCodec.encodeGzip(big).length;
    expect(gz / plain, lessThan(0.3));
  });

  test('encrypted import without a password asks for one', () {
    final enc = BackupCodec.encodeJson(sample(), password: 'pw');
    expect(
      () => BackupCodec.decode(enc),
      throwsA(isA<DecryptionException>().having((e) => e.reason, 'reason', DecryptionReason.needsPassword)),
    );
  });

  test('wrong password, corrupted data and invalid files carry actionable messages', () {
    final enc = BackupCodec.encodeJson(sample(), password: 'right');
    expect(
      () => BackupCodec.decode(enc, password: 'wrong'),
      throwsA(isA<DecryptionException>()
          .having((e) => e.reason, 'reason', DecryptionReason.wrongPassword)
          .having((e) => e.message, 'message', 'Incorrect password. Please try again.')),
    );
    final truncated = Uint8List.fromList(enc.sublist(0, 20));
    expect(
      () => BackupCodec.decode(truncated, password: 'right'),
      throwsA(isA<DecryptionException>().having((e) => e.message, 'message', 'Backup file is corrupted and cannot be restored.')),
    );
    expect(
      () => BackupCodec.decode(utf8.encode('hello there')),
      throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', 'This file is not a valid MorphCook backup.')),
    );
    expect(() => BackupCodec.decode(utf8.encode('{"schema_version": 99, "profile": {}}')), throwsA(isA<BackupFormatException>()));
    expect(() => BackupCodec.decode(utf8.encode('{"foo": 1}')), throwsA(isA<BackupFormatException>()));
  });

  test('each encryption uses a fresh salt and iv', () {
    final a = BackupCrypto.encrypt(Uint8List.fromList(utf8.encode('x')), 'pw');
    final b = BackupCrypto.encrypt(Uint8List.fromList(utf8.encode('x')), 'pw');
    expect(a.sublist(4, 20), isNot(b.sublist(4, 20)));
    expect(BackupCrypto.decrypt(a, 'pw'), utf8.encode('x'));
    expect(BackupCrypto.decrypt(b, 'pw'), utf8.encode('x'));
    expect(BackupCrypto.iterations, 10000);
    expect(BackupCrypto.keyLength, 32);
  });

  test('merge keeps local data and adds the backup; replace does not', () {
    final local = BackupData(
      exportedAt: DateTime.now(),
      profile: const Profile(name: 'local'),
      saved: const ['a'],
      mealPlan: MealPlan({
        '2026-W16': {'tue.lunch': 'b'}
      }),
      history: [HistoryEntry(recipeId: 'a', dishId: 'd', cookedAt: DateTime.utc(2026, 1, 1), servings: 2)],
      contentRequests: const ['x'],
    );
    final merged = BackupCodec.merge(local, sample(), MergeMode.merge);
    expect(merged.saved, ['a', 'doener-vegan-easy', 'alfredo-vegan-easy']);
    expect(merged.mealPlan.recipeAt('2026-W16', 'tue.lunch'), 'b');
    expect(merged.mealPlan.recipeAt('2026-W16', 'mon.dinner'), 'doener-vegan-easy');
    expect(merged.history.length, 2);
    expect(merged.contentRequests, ['x', 'pad thai', 'sushi']);
    expect(merged.profile.name, 'cedric');
    final replaced = BackupCodec.merge(local, sample(), MergeMode.replace);
    expect(replaced.saved, sample().saved);
    expect(replaced.mealPlan.recipeAt('2026-W16', 'tue.lunch'), isNull);
  });
}
