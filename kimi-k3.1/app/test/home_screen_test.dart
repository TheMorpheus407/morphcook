import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets('completed profile opens the home shell cleanly', (tester) async {
    usePhone(tester);
    final app = await makeTestApp(
      tester,
      profile: const Profile(avoidFlags: {'vegan'}, onboardingComplete: true),
    );
    await pumpMorphCook(tester, app);
    expect(find.text('morphcook.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
