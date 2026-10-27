import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/user_data.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets(
    'saved recipe fills a slot, exports to smart shopping and builds insights',
    (tester) async {
      usePhone(tester);
      final app = await makeTestApp(
        tester,
        snapshot: UserSnapshot(
          saved: [
            SavedRecipe(
              recipeId: 'doener-vegan-easy',
              savedAt: DateTime.utc(2026, 4, 1),
            ),
          ],
        ),
      );
      await pumpMorphCook(tester, app);
      await tester.tap(find.text('PLAN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('a little blank space').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Easy Seitan Döner'));
      await tester.pumpAndSettle();
      expect(
        app.snapshot.mealPlan['2026-W16']?['mon.breakfast'],
        'doener-vegan-easy',
      );
      await tester.tap(find.text('Add this week to shopping'));
      await tester.pumpAndSettle();
      expect(app.snapshot.shoppingRecipeIds, ['doener-vegan-easy']);
      expect(
        app.snapshot.shoppingEvents.any(
          (event) => event.ingredientId == 'garlic',
        ),
        isTrue,
      );
      ScaffoldMessenger.of(
        tester.element(find.text('Add this week to shopping')),
      ).clearSnackBars();
      await tester.pump();
      await tester.tap(find.text('SHOPPING'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Garlic'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Garlic'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Most-added ingredients'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.runAsync(() => app.writesSettled);
      expect(tester.takeException(), isNull);
    },
  );
}
