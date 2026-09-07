import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_state.dart';
import 'package:morphcook/core/models.dart';
import 'package:morphcook/core/pagination.dart';
import 'package:morphcook/core/repository.dart';
import 'package:morphcook/screens/planner_screen.dart';
import 'package:morphcook/ui/design.dart';

void main() {
  for (final anchor in [DateTime(2026, 3, 30), DateTime(2026, 10, 26)]) {
    test('weekly pagination uses calendar boundaries around $anchor', () async {
      final requests = <PageRequest>[];
      final pages = PaginationController<int>(
        type: PaginationType.weekly,
        initialDate: anchor,
        pageSize: 1,
        loader: (request) async {
          requests.add(request);
          return const PageResult(items: [1], hasMore: true);
        },
      );
      await pages.loadMore();
      await pages.loadMore();
      expect(requests.first.endDate, anchor);
      expect(
        requests.first.startDate,
        DateTime(anchor.year, anchor.month, anchor.day - 7),
      );
      expect(requests.last.endDate, requests.first.startDate);
      expect(
        requests.last.startDate,
        DateTime(anchor.year, anchor.month, anchor.day - 14),
      );
      expect(
        requests.every((r) => r.startDate!.hour == 0 && r.endDate!.hour == 0),
        isTrue,
      );
      pages.dispose();
    });
  }

  for (final scenario in [
    (DateTime(2026, 10, 19), 'Next week', '26.10 — 01.11 / 2026', '2026-W44'),
    (
      DateTime(2026, 3, 30),
      'Previous week',
      '23.03 — 29.03 / 2026',
      '2026-W13',
    ),
  ]) {
    testWidgets('planner keeps the right week across ${scenario.$1}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const recipe = Recipe(
        id: 'meal',
        dishId: 'meal',
        title: {'en': 'A good meal', 'de': 'Ein gutes Essen'},
      );
      final state = AppState.inMemory(
        repo: Repository.fromData(recipes: [recipe]),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: morphTheme(),
          home: PaperScaffold(
            child: PlannerScreen(state: state, initialDate: scenario.$1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(scenario.$2));
      await tester.pumpAndSettle();
      expect(find.text(scenario.$3), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('A good meal'));
      await tester.pumpAndSettle();
      expect(state.mealPlan[scenario.$4]?['mon.breakfast'], 'meal');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
