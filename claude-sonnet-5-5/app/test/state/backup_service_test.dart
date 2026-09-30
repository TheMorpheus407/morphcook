import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/models/history_entry.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/backup/backup_codec.dart';
import 'package:morphcook/domain/backup/backup_models.dart';
import 'package:morphcook/domain/plan/meal_plan.dart';
import 'package:morphcook/domain/shopping/aggregator.dart';
import 'package:morphcook/state/app_services.dart';

import '../support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 28, 12);
  final week = WeekKey.fromDate(now);

  Future<AppServices> filled() async {
    final s = await makeServices(
      onboarded: true,
      profile: const Profile(
        name: 'Sam',
        lang: 'de',
        avoidFlags: {'dairy', 'nuts'},
        avoidIngredients: {'apple'},
        maxTimeMinutes: 45,
        calorieTarget: 600,
        preferredEffort: 'easy',
      ),
      now: now,
    );
    await s.profile.setSettings(const AppSettings(quickNextTapEnabled: true, visualAlertEnabled: false));
    await s.cookbook.save('doener-vegan', at: DateTime(2026, 9, 1));
    await s.cookbook.save('pancakes-vegan', at: DateTime(2026, 9, 2));
    await s.history.add(HistoryEntry(recipeId: 'chili-vegan', cookedAt: DateTime(2026, 9, 10), servings: 4));
    await s.mealPlan.assign(week, 'mon.dinner', 'chili-vegan');
    await s.contentRequests.add('sushi');
    await s.shopping.addRecipe((await s.corpus.loadRecipe('pancakes-vegan'))!, at: DateTime(2026, 9, 3));
    await s.shopping.addManual(const ManualItem(id: 'm1', label: 'candles'));
    return s;
  }

  Future<AppServices> empty() => makeServices(onboarded: false, now: now);

  group('export', () {
    test('writes both files, the JSON readable and the GZip compressed', () async {
      final s = await filled();
      final bundle = await s.backup.export();
      expect(bundle.jsonName, 'morphcook-backup.json');
      expect(bundle.gzipName, 'morphcook-backup.json.gz');
      expect(bundle.encrypted, isFalse);
      expect(BackupCodec.isEncrypted(bundle.json), isFalse);
      expect(BackupCodec.isGzip(bundle.gzip), isTrue);
      final json = jsonDecode(utf8.decode(bundle.json)) as Map<String, dynamic>;
      expect(json['schema_version'], 1);
      expect(json['saved'], ['doener-vegan', 'pancakes-vegan'], reason: 'oldest first');
      expect(json['meal_plan'], {
        week.toString(): {'mon.dinner': 'chili-vegan'},
      });
      expect(json['content_requests'], ['sushi']);
      expect((json['profile'] as Map)['name'], 'Sam');
      expect((json['profile'] as Map)['avoid_flags'], ['dairy', 'nuts']);
      expect((json['history'] as List), hasLength(1));
    });

    test('with a password the JSON is encrypted and the GZip stays readable', () async {
      final s = await filled();
      final bundle = await s.backup.export(password: 'open sesame');
      expect(bundle.encrypted, isTrue);
      expect(BackupCodec.isEncrypted(bundle.json), isTrue);
      expect(BackupCodec.isGzip(bundle.gzip), isTrue);
      expect(s.backup.read(bundle.gzip).saved, contains('doener-vegan'), reason: 'compatible, unencrypted');
    });

    test('an empty password means no encryption', () async {
      final s = await filled();
      final bundle = await s.backup.export(password: '');
      expect(bundle.encrypted, isFalse);
    });

    test('the reserved B2B block travels inside the profile, and the password protects it', () async {
      final source = await makeServices(
        profile: const Profile(
          name: 'Sam',
          b2b: {
            'organization': 'acme-health',
            'seat': {'cohort': 'q4'},
          },
        ),
        now: now,
      );
      final plain = await source.backup.export();
      expect(utf8.decode(plain.json), contains('acme-health'));

      final encrypted = await source.backup.export(password: 'open sesame');
      expect(utf8.decode(encrypted.json, allowMalformed: true), isNot(contains('acme-health')));

      final target = await empty();
      await target.backup.apply(await target.backup.readEncrypted(encrypted.json, 'open sesame'), ImportMode.merge);
      expect(target.profile.profile.b2b, {
        'organization': 'acme-health',
        'seat': {'cohort': 'q4'},
      });
    });

    test('the snapshot never contains the corpus', () async {
      final s = await filled();
      final text = utf8.decode((await s.backup.export()).json);
      expect(text, isNot(contains('"steps"')));
      expect(text, isNot(contains('calories_per_serving')));
    });
  });

  group('import', () {
    test('a full round trip into a fresh install restores everything', () async {
      final source = await filled();
      final bundle = await source.backup.export();
      final target = await empty();
      final data = target.backup.read(bundle.json);
      final summary = await target.backup.apply(data, ImportMode.merge);

      expect(summary.profileApplied, isTrue, reason: 'a fresh install has no profile of its own to protect');
      expect(target.profile.profile.name, 'Sam');
      expect(target.profile.profile.avoidFlags, {'dairy', 'nuts'});
      expect(target.profile.profile.avoidIngredients, {'apple'});
      expect(target.profile.profile.calorieTarget, 600);
      expect(target.profile.settings.quickNextTapEnabled, isTrue);
      expect(target.profile.onboarded, isTrue);
      expect(target.cookbook.saved.map((s) => s.recipeId), unorderedEquals(['doener-vegan', 'pancakes-vegan']));
      expect(target.history.entries.single.recipeId, 'chili-vegan');
      expect(target.mealPlan.recipeAt(week, 'mon.dinner'), 'chili-vegan');
      expect(target.contentRequests.queries, ['sushi']);
      expect(target.shopping.sources.single.recipeId, 'pancakes-vegan');
      expect(target.shopping.manualItems.single.label, 'candles');
      expect(target.shopping.events, isNotEmpty);
      expect(summary.saved, 2);
      expect(summary.history, 1);
      expect(summary.planSlots, 1);
      expect(summary.contentRequests, 1);
    });

    test('GZip and encrypted files restore the same data', () async {
      final source = await filled();
      final plain = await source.backup.export();
      final secret = await source.backup.export(password: 'pw');

      final fromGzip = await empty();
      await fromGzip.backup.apply(fromGzip.backup.read(plain.gzip), ImportMode.replace);
      expect(fromGzip.cookbook.count, 2);

      final fromSecret = await empty();
      await expectLater(
        () async => fromSecret.backup.read(secret.json),
        throwsA(isA<DecryptionException>().having((e) => e.reason, 'reason', DecryptionFailure.passwordRequired)),
      );
      final data = await fromSecret.backup.readEncrypted(secret.json, 'pw');
      await fromSecret.backup.apply(data, ImportMode.replace);
      expect(fromSecret.cookbook.count, 2);
      expect(fromSecret.profile.profile.name, 'Sam');
    });

    test('merge never overwrites what is on the device', () async {
      final source = await filled();
      final data = source.backup.read((await source.backup.export()).json);

      final target = await makeServices(
        profile: const Profile(name: 'Local', avoidFlags: {'gluten'}),
        now: now,
      );
      await target.cookbook.save('doener-vegan', at: DateTime(2020));
      await target.mealPlan.assign(week, 'mon.dinner', 'local-recipe');
      await target.mealPlan.assign(week, 'tue.dinner', 'other-local');
      final summary = await target.backup.apply(data, ImportMode.merge);

      expect(summary.profileApplied, isFalse, reason: 'an onboarded profile is kept in merge mode');
      expect(target.profile.profile.name, 'Local');
      expect(target.profile.profile.avoidFlags, {'gluten'});
      expect(target.cookbook.saved.firstWhere((s) => s.recipeId == 'doener-vegan').savedAt, DateTime(2020));
      expect(target.cookbook.count, 2, reason: 'doener-vegan kept, pancakes-vegan added');
      expect(target.mealPlan.recipeAt(week, 'mon.dinner'), 'local-recipe');
      expect(target.mealPlan.recipeAt(week, 'tue.dinner'), 'other-local');
    });

    test('replace restores the backup as it is', () async {
      final source = await filled();
      final data = source.backup.read((await source.backup.export()).json);

      final target = await makeServices(
        profile: const Profile(name: 'Local'),
        now: now,
      );
      await target.cookbook.save('something-else');
      await target.mealPlan.assign(week, 'sun.lunch', 'local-recipe');
      await target.contentRequests.add('tacos');
      await target.backup.apply(data, ImportMode.replace);

      expect(target.profile.profile.name, 'Sam');
      expect(target.cookbook.saved.map((s) => s.recipeId), unorderedEquals(['doener-vegan', 'pancakes-vegan']));
      expect(target.mealPlan.plan.slotsOf(week), {'mon.dinner': 'chili-vegan'});
      expect(target.contentRequests.queries, ['sushi']);
    });

    test('importing the same backup twice changes nothing the second time', () async {
      final source = await filled();
      final data = source.backup.read((await source.backup.export()).json);
      final target = await empty();
      await target.backup.apply(data, ImportMode.merge);
      final events = target.shopping.events.length;
      await target.backup.apply(data, ImportMode.merge);
      expect(target.cookbook.count, 2);
      expect(target.history.count, 1);
      expect(target.shopping.events.length, events);
      expect(target.contentRequests.count, 1);
    });

    test('a backup without the optional sections restores what it has', () async {
      final target = await empty();
      final data = target.backup.read(
        utf8.encode('{"schema_version":1,"profile":{"name":"Min","lang":"en"},"saved":["x-1"]}'),
      );
      await target.backup.apply(data, ImportMode.replace);
      expect(target.profile.profile.name, 'Min');
      expect(target.cookbook.saved.single.recipeId, 'x-1');
      expect(target.history.count, 0);
    });

    test('a saved recipe without a date keeps the list order', () async {
      final target = await empty();
      final data = target.backup.read(
        utf8.encode(
          '{"schema_version":1,"exported_at":"2026-04-18T12:00:00Z","profile":{},"saved":["a-1","b-1","c-1"]}',
        ),
      );
      await target.backup.apply(data, ImportMode.replace);
      expect(target.cookbook.saved.map((s) => s.recipeId), [
        'c-1',
        'b-1',
        'a-1',
      ], reason: 'newest first, as exported oldest first');
    });

    test('the bundled corpus is never touched', () async {
      final source = await filled();
      final data = source.backup.read((await source.backup.export()).json);
      final target = await empty();
      final before = target.corpus.dishes.length;
      await target.backup.apply(data, ImportMode.replace);
      expect(target.corpus.dishes.length, before);
      expect(await target.corpus.loadRecipe('doener-vegan'), isNotNull);
    });
  });

  group('failures', () {
    test('a wrong password reports it, a broken file says so, and nothing is applied', () async {
      final source = await filled();
      final secret = await source.backup.export(password: 'right');
      final target = await empty();
      await expectLater(
        target.backup.readEncrypted(secret.json, 'wrong'),
        throwsA(
          isA<DecryptionException>().having((e) => e.message, 'message', 'Incorrect password. Please try again.'),
        ),
      );
      expect(
        () => target.backup.read(utf8.encode('nope')),
        throwsA(
          isA<DecryptionException>().having((e) => e.message, 'message', 'This file is not a valid MorphCook backup.'),
        ),
      );
      expect(target.cookbook.count, 0);
      expect(target.profile.onboarded, isFalse);
    });
  });
}
