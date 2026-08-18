import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/backup.dart';
import 'package:morphcook/logic/crypto.dart';
import 'package:morphcook/models/collections.dart';
import 'package:morphcook/models/profile.dart';

BackupData sample() => BackupData(
      profile: const Profile(name: 'ada', lang: 'de', avoidFlags: {'vegan'}),
      saved: [
        SavedRecipe(recipeId: 'doener-vegan', savedAt: DateTime.utc(2026, 4, 18)),
      ],
      mealPlan: const {
        '2026-W16': {'mon.dinner': 'doener-vegan'},
      },
      history: [
        HistoryEntry(recipeId: 'doener-vegan', cookedAt: DateTime.utc(2026, 4, 1)),
      ],
      contentRequests: const ['pad thai'],
    );

void main() {
  test('plain json roundtrip', () {
    final exported = BackupService.export(sample(), exportedAt: DateTime.utc(2026, 4, 18, 12));
    expect(hasEncryptionMagic(exported.jsonFile), isFalse);
    expect(hasGzipMagic(exported.gzipFile), isTrue);
    final data = BackupService.import(exported.jsonFile);
    expect(data.profile.name, 'ada');
    expect(data.saved.single.recipeId, 'doener-vegan');
    expect(data.contentRequests, ['pad thai']);
  });

  test('gzip import', () {
    final exported = BackupService.export(sample());
    final data = BackupService.import(exported.gzipFile);
    expect(data.profile.lang, 'de');
  });

  test('encrypted json uses ENC magic and needs password', () {
    final exported = BackupService.export(sample(), password: 'secret-key');
    expect(hasEncryptionMagic(exported.jsonFile), isTrue);
    expect(hasEncryptionMagic(exported.gzipFile), isFalse);
    expect(
      () => BackupService.import(exported.jsonFile),
      throwsA(isA<DecryptionException>().having((e) => e.reason, 'reason', DecryptionFailure.needsPassword)),
    );
    final data = BackupService.import(exported.jsonFile, password: 'secret-key');
    expect(data.profile.name, 'ada');
  });

  test('wrong password message', () {
    final exported = BackupService.export(sample(), password: 'secret-key');
    try {
      BackupService.import(exported.jsonFile, password: 'nope');
      fail('expected');
    } on DecryptionException catch (e) {
      expect(e.reason, DecryptionFailure.wrongPassword);
      expect(e.message, 'Incorrect password. Please try again.');
    }
  });

  test('invalid format message', () {
    try {
      BackupService.import(utf8.encode('not-json'));
      fail('expected');
    } on DecryptionException catch (e) {
      expect(e.message, 'This file is not a valid MorphCook backup.');
    }
  });

  test('merge unions saved and incoming meal slots win', () {
    final current = sample();
    final incoming = BackupData(
      profile: const Profile(name: 'bea'),
      saved: [
        SavedRecipe(recipeId: 'alfredo-vegan', savedAt: DateTime.utc(2026, 5, 1)),
      ],
      mealPlan: const {
        '2026-W16': {'tue.lunch': 'alfredo-vegan'},
      },
      history: const [],
    );
    final merged = BackupService.merge(current, incoming);
    expect(merged.profile.name, 'bea');
    expect(merged.saved.map((s) => s.recipeId), containsAll(['doener-vegan', 'alfredo-vegan']));
    expect(merged.mealPlan['2026-W16']?['mon.dinner'], 'doener-vegan');
    expect(merged.mealPlan['2026-W16']?['tue.lunch'], 'alfredo-vegan');
  });

  test('gzip companion stays unencrypted when password set', () {
    final exported = BackupService.export(sample(), password: 'x');
    expect(gzip.decode(exported.gzipFile), isNotEmpty);
    expect(hasEncryptionMagic(exported.gzipFile), isFalse);
  });
}
