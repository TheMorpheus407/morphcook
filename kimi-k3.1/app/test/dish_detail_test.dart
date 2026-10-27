import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/screens/dish_detail_screen.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets(
    'dimension switchers follow real chains and explain disabled combinations',
    (tester) async {
      usePhone(tester);
      final app = await makeTestApp(
        tester,
        profile: const Profile(
          maxTimeMinutes: 60,
          calorieTarget: 600,
          calorieTolerance: 300,
          onboardingComplete: true,
        ),
      );
      await pumpScreen(
        tester,
        app,
        DishDetailScreen(
          dish: app.repository.dishes['pancakes']!,
          initialRecipeId: 'pancakes-vegan-easy',
        ),
      );
      expect(find.text('Fluffy Vegan Banana Pancakes'), findsOneWidget);

      await tester.tap(find.text('effort'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Medium'));
      await tester.pumpAndSettle();
      expect(find.text('Blueberry Oat Pancakes'), findsOneWidget);

      await tester.tap(find.text('calorie level'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light · 380'));
      await tester.pumpAndSettle();
      expect(find.text('Light Buckwheat Berry Pancakes'), findsOneWidget);

      await tester.tap(find.text('diet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keto'));
      await tester.pumpAndSettle();
      expect(find.text('Keto Almond Pancakes'), findsOneWidget);

      await tester.tap(find.text('diet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Classic'));
      await tester.pump();
      expect(
        find.text('No Classic × Medium × Light version yet.'),
        findsOneWidget,
      );
      expect(app.snapshot.saved, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
