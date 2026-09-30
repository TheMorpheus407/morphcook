import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/logic/calendar.dart';
import 'package:morphcook/state/cook_mode.dart';
import 'package:morphcook/state/kv_store.dart';
import 'package:morphcook/state/library_store.dart';

import 'support.dart';

void main() {
  final c = Corpus.instance;
  late MemoryKvStore store;
  late DateTime now;
  LibraryStore lib() => LibraryStore(store, clock: () => now);

  setUp(() {
    store = MemoryKvStore();
    now = DateTime(2026, 9, 22, 18);
  });

  group('ISO weeks', () {
    test('keys and mondays', () {
      expect(IsoWeek.of(DateTime(2026, 9, 22)).key, '2026-W39');
      expect(IsoWeek.of(DateTime(2026, 4, 18)).key, '2026-W16');
      expect(IsoWeek.of(DateTime(2027, 1, 1)).key, '2026-W53');
      expect(IsoWeek.parse('2026-W39').monday, DateTime(2026, 9, 21));
      expect(IsoWeek.parse('2026-W53').shift(1).key, '2027-W01');
      expect(IsoWeek.parse('2026-W01').shift(-1).key, '2025-W52');
    });
  });

  group('cookbook', () {
    test('saves specific variants and persists them', () async {
      final l = lib();
      await l.toggleSaved('doener-vegan');
      now = now.add(const Duration(minutes: 1));
      await l.toggleSaved('pad-thai-vegan');
      expect(l.savedNewestFirst, ['pad-thai-vegan', 'doener-vegan']);
      expect(lib().isSaved('doener-vegan'), isTrue, reason: 'reloaded from store');
      await l.toggleSaved('doener-vegan');
      expect(l.isSaved('doener-vegan'), isFalse);
    });

    test('offset pages of 30', () async {
      final l = lib();
      for (var i = 0; i < 65; i++) {
        now = now.add(const Duration(seconds: 1));
        await l.toggleSaved('r$i');
      }
      final p1 = await l.savedPage(null, 30);
      expect(p1.items.first, 'r64');
      expect(p1.nextToken, '30');
      final p3 = await l.savedPage('60', 30);
      expect(p3.items, hasLength(5));
      expect(p3.nextToken, isNull);
    });
  });

  group('meal plan', () {
    test('assign, move into empty slot, swap with filled slot, clear', () async {
      final l = lib();
      await l.assign('2026-W39', 'mon.dinner', 'chili-classic');
      await l.assign('2026-W39', 'tue.dinner', 'pad-thai-vegan');
      await l.moveSlot('2026-W39', 'mon.dinner', '2026-W39', 'wed.lunch');
      expect(l.week('2026-W39'), {'tue.dinner': 'pad-thai-vegan', 'wed.lunch': 'chili-classic'});
      await l.moveSlot('2026-W39', 'wed.lunch', '2026-W39', 'tue.dinner');
      expect(l.week('2026-W39'), {'tue.dinner': 'chili-classic', 'wed.lunch': 'pad-thai-vegan'});
      await l.moveSlot('2026-W39', 'tue.dinner', '2026-W40', 'mon.breakfast');
      expect(l.week('2026-W40'), {'mon.breakfast': 'chili-classic'});
      await l.clearSlot('2026-W40', 'mon.breakfast');
      expect(l.plan.containsKey('2026-W40'), isFalse);
    });

    test('weekly pages start at the current week', () async {
      final page = await lib().weekPage(null, 1);
      expect(page.items.single.key, '2026-W39');
      expect(page.nextToken, '2026-W40');
    });
  });

  group('history', () {
    test('time-based pages group by week, newest first', () async {
      final l = lib();
      final base = DateTime(2026, 9, 22, 19);
      for (final daysAgo in [0, 1, 8, 20, 60, 100]) {
        now = base.subtract(Duration(days: daysAgo));
        await l.logCooked('chili-classic', 4);
      }
      now = base;
      final p1 = await l.historyPage(null, 7);
      expect(p1.items.first.week.key, '2026-W39');
      expect(p1.items.first.entries, hasLength(2));
      expect(p1.items.map((w) => w.week.key), ['2026-W39', '2026-W38', '2026-W36']);
      expect(p1.nextToken, isNotNull);
      final p2 = await l.historyPage(p1.nextToken, 7);
      expect(p2.items, hasLength(1)); // 60 days ago
      final p3 = await l.historyPage(p2.nextToken, 7);
      expect(p3.items, hasLength(1)); // 100 days ago
      expect(p3.nextToken, isNull);
      expect(l.lastCooked['chili-classic'], base);
    });
  });

  group('shopping', () {
    test('sources, log for insights, checks, clear', () async {
      final l = lib();
      await l.addToShopping(c.r('doener-classic'), 2);
      expect(l.shoppingSources.single.servings, 2);
      expect(l.shoppingLog.length, c.r('doener-classic').ingredientIds.length);
      await l.addManual('candles');
      await l.toggleChecked('manual|${l.manualItems.single.id}');
      await l.toggleChecked('garlic|count:clove');
      await l.clearChecked();
      expect(l.manualItems, isEmpty);
      expect(l.checked, isEmpty);
      await l.clearShopping();
      expect(l.shoppingSources, isEmpty);
      expect(l.shoppingLog, isNotEmpty, reason: 'insights keep their history');
    });

    test('content requests are normalised and deduplicated', () async {
      final l = lib();
      await l.logContentRequest('Sushi ');
      await l.logContentRequest('sushi');
      await l.logContentRequest('ab');
      expect(l.contentRequests, ['sushi']);
    });
  });

  group('backup snapshot', () {
    test('replace and merge', () async {
      final a = lib();
      await a.toggleSaved('doener-vegan');
      await a.assign('2026-W16', 'mon.dinner', 'chili-sin-carne');
      await a.logContentRequest('pad thai');
      final snap = a.exportSnapshot();
      expect(snap['saved'], ['doener-vegan']);
      expect(snap['meal_plan'], {
        '2026-W16': {'mon.dinner': 'chili-sin-carne'},
      });
      expect(snap['content_requests'], ['pad thai']);

      store = MemoryKvStore();
      final b = lib();
      await b.toggleSaved('ramen-pork');
      await b.importSnapshot(snap, ImportMode.merge);
      expect(b.savedIds, {'ramen-pork', 'doener-vegan'});
      await b.importSnapshot(snap, ImportMode.replace);
      expect(b.savedIds, {'doener-vegan'});
      expect(b.week('2026-W16'), {'mon.dinner': 'chili-sin-carne'});
    });
  });

  group('OneHandedCookModeController', () {
    test('quick tap is opt-in', () {
      final ctrl = OneHandedCookModeController(haptic: () async {});
      expect(ctrl.registerTap(), isFalse);
    });

    test('300 ms debounce and haptic feedback on accepted taps', () {
      var t = DateTime(2026);
      var haptics = 0;
      final ctrl = OneHandedCookModeController(
        quickNextTapEnabled: true,
        clock: () => t,
        haptic: () async => haptics++,
      );
      expect(ctrl.registerTap(), isTrue);
      t = t.add(const Duration(milliseconds: 120));
      expect(ctrl.registerTap(), isFalse);
      t = t.add(const Duration(milliseconds: 179));
      expect(ctrl.registerTap(), isFalse);
      t = t.add(const Duration(milliseconds: 1));
      expect(ctrl.registerTap(), isTrue);
      expect(haptics, 2);
      expect(ctrl.debounce, const Duration(milliseconds: 300));
    });

    test('reduce motion removes the step transition', () {
      expect(OneHandedCookModeController(reduceMotion: true).transitionDuration, Duration.zero);
      expect(OneHandedCookModeController().transitionDuration, greaterThan(Duration.zero));
    });
  });

  group('CookSession', () {
    test('steps, servings, timer, completion logs history', () async {
      final l = lib();
      final r = c.r('pad-thai-weeknight');
      var done = 0;
      final s = CookSession(recipe: r, library: l, clock: () => now)..onTimerDone = () => done++;
      expect(s.step, 0);
      expect(s.hasTimer, isTrue);
      expect(s.remaining, r.steps[0].timerSeconds);
      s.startTimer();
      for (var i = 0; i < r.steps[0].timerSeconds!; i++) {
        s.tick();
      }
      expect(s.timerStatus, TimerStatus.done);
      expect(done, 1);
      s.setServings(6);
      s.next();
      expect(s.step, 1);
      await s.persist();
      expect(l.progressFor(r.id)!.step, 1);
      expect(l.progressFor(r.id)!.servings, 6);
      while (!s.isLast) {
        s.next();
      }
      s.next(); // finish
      await Future<void>.delayed(Duration.zero);
      expect(s.completed, isTrue);
      expect(l.history.single.recipeId, r.id);
      expect(l.progressFor(r.id), isNull);
      s.dispose();
    });

    test('pause/resume restores step, servings and remaining timer', () async {
      final l = lib();
      final r = c.r('shakshuka-classic');
      final s = CookSession(recipe: r, library: l, clock: () => now);
      s.next(); // step 2 has a timer
      s.startTimer();
      s.tick();
      s.tick();
      await s.pauseSession();
      final saved = l.progressFor(r.id)!;
      expect(saved.step, 1);
      expect(saved.timerRemaining, r.steps[1].timerSeconds! - 2);
      s.dispose();

      final resumed = CookSession(recipe: r, library: l, resumeFrom: saved);
      expect(resumed.step, 1);
      expect(resumed.remaining, r.steps[1].timerSeconds! - 2);
      expect(resumed.timerStatus, TimerStatus.paused);
      resumed.dispose();
    });
  });
}
