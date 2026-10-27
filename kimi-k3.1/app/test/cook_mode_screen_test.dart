import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/screens/cook_mode_screen.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets('cook screen advances through every step and completes cleanly', (
    tester,
  ) async {
    usePhone(tester);
    final app = await makeTestApp(tester);
    final recipe = app.repository.recipes['doener-vegan-easy']!;
    await pumpScreen(tester, app, CookModeScreen(recipe: recipe));
    expect(find.text('step 1 of 5'), findsOneWidget);
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.text('Next step'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('I made this'));
    await tester.pumpAndSettle();
    expect(find.text('You made Easy Seitan Döner.'), findsOneWidget);
    expect(app.snapshot.history.single.recipeId, recipe.id);
    expect(tester.takeException(), isNull);
  });
}
