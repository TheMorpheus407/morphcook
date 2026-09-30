import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:morphcook/state/storage/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real persistence classes: `shared_preferences` and Hive on disk. Every
/// other test uses the in-memory twins, so this is where a break in the real
/// ones would show.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('morphcook_storage');
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  group('SharedPrefsStore', () {
    Future<SharedPrefsStore> open() async => SharedPrefsStore(await SharedPreferences.getInstance());

    test('stores, reads, lists and removes strings', () async {
      final store = await open();
      expect(store.getString('profile.v1'), isNull);
      await store.setString('profile.v1', '{"name":"Sam"}');
      await store.setString('onboarded.v1', 'true');
      expect(store.getString('profile.v1'), '{"name":"Sam"}');
      expect(store.keys.toSet(), {'profile.v1', 'onboarded.v1'});
      await store.remove('profile.v1');
      expect(store.getString('profile.v1'), isNull);
      expect(store.keys.toSet(), {'onboarded.v1'});
    });

    test('values from an earlier run are there when the app opens again', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'onboarded.v1': 'true'});
      final store = await open();
      expect(store.getString('onboarded.v1'), 'true');
    });

    test('behaves like the in-memory store the other tests use', () async {
      final real = await open();
      final memory = MemoryKeyValueStore();
      for (final store in <KeyValueStore>[real, memory]) {
        await store.setString('a', '1');
        await store.setString('a', '2');
        await store.setString('b', '3');
        await store.remove('b');
        await store.remove('never-there');
      }
      expect(real.getString('a'), memory.getString('a'));
      expect(real.keys.toSet(), memory.keys.toSet());
    });
  });

  group('HiveRecordStore', () {
    test('a box stores, reads, lists, counts, deletes and clears', () async {
      final box = await HiveRecordStore.initAt(dir.path).open('saved');
      expect(box.length, 0);
      await box.put('doener-vegan', '{"saved_at":"2026-09-01"}');
      await box.put('pancakes-vegan', '{"saved_at":"2026-09-02"}');
      expect(box.length, 2);
      expect(box.keys.toSet(), {'doener-vegan', 'pancakes-vegan'});
      expect(box.get('doener-vegan'), '{"saved_at":"2026-09-01"}');
      expect(box.entries.map((e) => e.key).toSet(), {'doener-vegan', 'pancakes-vegan'});
      await box.delete('doener-vegan');
      expect(box.get('doener-vegan'), isNull);
      await box.clear();
      expect(box.length, 0);
    });

    test('JSON records round trip, and a damaged record reads as missing', () async {
      final box = await HiveRecordStore.initAt(dir.path).open('history');
      await box.putJson('a', <String, dynamic>{'recipe_id': 'chili-vegan', 'servings': 4});
      expect(box.getJson('a'), {'recipe_id': 'chili-vegan', 'servings': 4});
      await box.put('broken', '{not json');
      expect(box.getJson('broken'), isNull);
      expect(box.getJson('missing'), isNull);
    });

    test('what was written survives closing and opening again, like a restart of the app', () async {
      var box = await HiveRecordStore.initAt(dir.path).open('meal_plan');
      await box.putJson('2026-W40', <String, dynamic>{'mon.dinner': 'chili-vegan'});
      await Hive.close();

      box = await HiveRecordStore.initAt(dir.path).open('meal_plan');
      expect(box.getJson('2026-W40'), {'mon.dinner': 'chili-vegan'});
      expect(File('${dir.path}/meal_plan.hive').existsSync(), isTrue, reason: 'it is on disk');
    });

    test('boxes are separate collections', () async {
      final store = HiveRecordStore.initAt(dir.path);
      final saved = await store.open('saved');
      final history = await store.open('history');
      await saved.put('x', '1');
      expect(history.get('x'), isNull);
      expect(history.length, 0);
    });

    test('unicode and large values are kept exactly', () async {
      final box = await HiveRecordStore.initAt(dir.path).open('shopping');
      final value = jsonEncode(<String, dynamic>{'label': 'Käsespätzle für Zwölf – 日本語', 'pad': 'x' * 50000});
      await box.put('k', value);
      await Hive.close();
      final again = await HiveRecordStore.initAt(dir.path).open('shopping');
      expect(again.get('k'), value);
    });

    test('behaves like the in-memory store the other tests use', () async {
      final real = await HiveRecordStore.initAt(dir.path).open('parity');
      final memory = await MemoryRecordStore().open('parity');
      for (final box in <RecordBox>[real, memory]) {
        await box.put('a', '1');
        await box.put('a', '2');
        await box.put('b', '3');
        await box.delete('b');
        await box.delete('never-there');
        await box.put('c', '4');
      }
      expect(real.keys.toSet(), memory.keys.toSet());
      expect(real.length, memory.length);
      expect({for (final e in real.entries) e.key: e.value}, {for (final e in memory.entries) e.key: e.value});
    });
  });

  group('AppStorage.openDefault', () {
    setUp(() {
      // The documents folder of the app: a temporary one.
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => dir.path,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
    });

    test('opens the preferences and keeps records in a morphcook folder of the documents', () async {
      final storage = await AppStorage.openDefault();
      await storage.prefs.setString('onboarded.v1', 'true');
      final box = await storage.records.open(Boxes.saved);
      await box.put('doener-vegan', '{}');
      expect(storage.prefs.getString('onboarded.v1'), 'true');
      expect(Directory('${dir.path}/morphcook').existsSync(), isTrue);
      expect(File('${dir.path}/morphcook/${Boxes.saved}.hive').existsSync(), isTrue);
    });

    test('opening twice reads what the first time wrote', () async {
      var storage = await AppStorage.openDefault();
      await (await storage.records.open(Boxes.history)).put('h1', '{"recipe_id":"chili-vegan"}');
      await Hive.close();
      storage = await AppStorage.openDefault();
      expect((await storage.records.open(Boxes.history)).get('h1'), '{"recipe_id":"chili-vegan"}');
    });

    test('the names of the collections are stable, because they are the names on disk', () {
      expect(
        [
          Boxes.saved,
          Boxes.history,
          Boxes.mealPlan,
          Boxes.shopping,
          Boxes.shoppingEvents,
          Boxes.contentRequests,
          Boxes.cookSession,
        ],
        ['saved', 'history', 'meal_plan', 'shopping', 'shopping_events', 'content_requests', 'cook_session'],
      );
    });
  });
}
