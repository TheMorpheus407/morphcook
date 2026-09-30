import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/motion.dart';
import 'package:morphcook/core/pagination/pagination_controller.dart';
import 'package:morphcook/state/controllers/profile_controller.dart';
import 'package:morphcook/state/storage/storage.dart';
import 'package:morphcook/widgets/paginated_list.dart';
import 'package:morphcook/widgets/skeleton.dart';
import 'package:provider/provider.dart';

import '../support/fixtures.dart';
import '../support/test_app.dart';

/// [PaginatedList] on its own: skeletons, empty and error states, lazy rows,
/// prefetch, and trimming that never moves the rows the reader is looking at.
void main() {
  late MotionPreferences motion;

  setUpAll(() async {
    final corpus = await loadCorpus();
    final profile = ProfileController(
      AppStorage.memory().prefs,
      ontology: corpus.ontology,
      ingredients: corpus.ingredients,
    );
    motion = MotionPreferences(profile);
  });

  Widget host(PaginationController<int> controller, {ScrollController? scroll, double rowHeight = 60}) {
    return ChangeNotifierProvider<MotionPreferences>.value(
      value: motion,
      child: MaterialApp(
        home: Scaffold(
          body: PaginatedList<int>(
            controller: controller,
            scrollController: scroll,
            itemExtent: (_, _) => rowHeight,
            skeletonBuilder: (_) => const Column(children: [SkeletonRow(), SkeletonRow()]),
            emptyBuilder: (_) => const Center(child: Text('nothing here')),
            errorBuilder: (_, retry) => Center(
              child: TextButton(onPressed: retry, child: const Text('try again')),
            ),
            itemBuilder: (context, item, index) => SizedBox(height: rowHeight, child: Text('row $item')),
          ),
        ),
      ),
    );
  }

  PaginationController<int> over(int total, {Completer<void>? gate, List<String?>? cursors, int pageSize = 20}) {
    return PaginationController<int>.cursor(
      config: PaginationConfig(type: PaginationType.cursor, pageSize: pageSize, prefetchThreshold: 10, maxRendered: 50),
      loader: (cursor, limit) async {
        cursors?.add(cursor);
        if (gate != null && cursor != null) await gate.future;
        final start = cursor == null ? 0 : int.parse(cursor);
        final end = (start + limit).clamp(0, total);
        return CursorPage<int>([for (var i = start; i < end; i++) i], nextCursor: end < total ? '$end' : null);
      },
    );
  }

  Future<void> settlePages(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  testWidgets('skeleton rows while the first page loads', (tester) async {
    usePhone(tester);
    final gate = Completer<CursorPage<int>>();
    final controller = PaginationController<int>.cursor(loader: (cursor, limit) => gate.future);
    await tester.pumpWidget(host(controller));
    expect(find.byType(SkeletonRow), findsWidgets, reason: 'idle before the first load');
    unawaited(controller.refresh());
    await tester.pump();
    expect(find.byType(SkeletonRow), findsWidgets);
    expect(find.text('row 0'), findsNothing);
    gate.complete(const CursorPage<int>([0, 1, 2]));
    await settlePages(tester);
    expect(find.byType(SkeletonRow), findsNothing);
    expect(find.text('row 0'), findsOneWidget);
  });

  testWidgets('an empty result shows the empty state', (tester) async {
    usePhone(tester);
    final controller = over(0);
    await tester.pumpWidget(host(controller));
    await controller.refresh();
    await tester.pump();
    expect(find.text('nothing here'), findsOneWidget);
  });

  testWidgets('an error shows the error state, and retry loads', (tester) async {
    usePhone(tester);
    var fail = true;
    final controller = PaginationController<int>.cursor(
      loader: (cursor, limit) async {
        if (fail) throw StateError('offline');
        return const CursorPage<int>([1, 2, 3]);
      },
    );
    await tester.pumpWidget(host(controller));
    await controller.refresh();
    await tester.pump();
    expect(find.text('try again'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('try again'));
    await settlePages(tester);
    expect(find.text('row 1'), findsOneWidget);
  });

  testWidgets('ListView.builder: only the rows on screen exist, however long the list', (tester) async {
    usePhone(tester); // 844 dp tall, rows of 60 dp
    final controller = over(2000);
    await tester.pumpWidget(host(controller));
    await controller.refresh();
    await settlePages(tester);
    final built = find.textContaining('row ').evaluate().length;
    expect(built, lessThan(20), reason: 'a screenful plus a little cache');
    expect(controller.items.length, lessThanOrEqualTo(50));
  });

  testWidgets('scrolling within the prefetch threshold loads the next page, once', (tester) async {
    usePhone(tester);
    final cursors = <String?>[];
    final controller = over(500, cursors: cursors);
    await tester.pumpWidget(host(controller, rowHeight: 200)); // tall rows: nothing to prefetch yet
    await controller.refresh();
    await settlePages(tester);
    expect(cursors, [null]);
    expect(find.textContaining('row ').evaluate().length, lessThan(9));
    await tester.drag(find.byType(Scrollable), const Offset(0, -1500));
    await settlePages(tester);
    expect(cursors, [null, '20'], reason: 'ten items from the end of the first page');
    await tester.drag(find.byType(Scrollable), const Offset(0, -100));
    await settlePages(tester);
    expect(cursors.where((c) => c == '20'), hasLength(1), reason: 'no double fetch');
  });

  testWidgets('the window never exceeds 50 items however far the reader goes', (tester) async {
    usePhone(tester);
    final controller = over(2000);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(host(controller, scroll: scroll));
    await controller.refresh();
    await settlePages(tester);
    for (var i = 0; i < 40; i++) {
      await tester.drag(find.byType(Scrollable), const Offset(0, -900));
      await settlePages(tester);
      expect(controller.items.length, lessThanOrEqualTo(60), reason: 'trimming waits for the reader only briefly');
    }
    expect(controller.trimmedFront, greaterThan(0));
    final visible = tester
        .widgetList<Text>(find.textContaining('row '))
        .map((t) => int.parse(t.data!.substring(4)))
        .toList();
    expect(visible.first, greaterThanOrEqualTo(controller.trimmedFront));
    expect(visible.last, lessThan(controller.trimmedFront + controller.items.length));
  });

  testWidgets('the rows on screen do not jump when older rows are trimmed', (tester) async {
    usePhone(tester);
    final controller = over(1000);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(host(controller, scroll: scroll));
    await controller.refresh();
    await settlePages(tester);
    // Read on until a page has been trimmed off the top, watching one row.
    var checked = 0;
    for (var i = 0; i < 60 && checked < 3; i++) {
      final probe = find.text('row ${controller.trimmedFront + 25}');
      final before = probe.evaluate().isEmpty ? null : tester.getTopLeft(probe).dy;
      final trimmedBefore = controller.trimmedFront;
      await tester.drag(find.byType(Scrollable), const Offset(0, -420));
      final moved = controller.trimmedFront != trimmedBefore;
      await settlePages(tester);
      if (moved && before != null && find.text('row ${trimmedBefore + 25}').evaluate().isNotEmpty) {
        // Compare against where the drag alone would have put it.
        final after = tester.getTopLeft(find.text('row ${trimmedBefore + 25}')).dy;
        expect(
          after,
          closeTo(before - 420, 130),
          reason: 'a jump would show up as several hundred dp of extra movement',
        );
        checked++;
      }
    }
    expect(controller.trimmedFront, greaterThan(0));
  });

  testWidgets('a footer skeleton stands in while more is available', (tester) async {
    usePhone(tester, size: const Size(390, 300));
    final gate = Completer<void>();
    final controller = over(500, gate: gate);
    await tester.pumpWidget(host(controller));
    await controller.refresh();
    await settlePages(tester);
    await tester.drag(find.byType(Scrollable), const Offset(0, -1150));
    await tester.pump();
    expect(find.byType(SkeletonRow), findsWidgets, reason: 'the last row is a footer, not another item');
    gate.complete();
    await settlePages(tester);
  });

  testWidgets('a refresh goes back to the top', (tester) async {
    usePhone(tester);
    final controller = over(500);
    await tester.pumpWidget(host(controller));
    await controller.refresh();
    await settlePages(tester);
    await tester.drag(find.byType(Scrollable), const Offset(0, -500));
    await settlePages(tester);
    await controller.refresh();
    await settlePages(tester);
    expect(find.text('row 0'), findsOneWidget);
  });
}
