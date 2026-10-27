import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';

import 'app_test_utils.dart';

void main() {
  testWidgets('settings switch German and FAQ search stays bilingual', (
    tester,
  ) async {
    usePhone(tester);
    final app = await makeTestApp(
      tester,
      profile: const Profile(onboardingComplete: true),
    );
    await pumpMorphCook(tester, app);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(app.profile.lang, 'de');
    expect(find.text('Profil & Ernährung'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('FAQ & Hilfe'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('FAQ & Hilfe'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kalorien');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Notizen am Rand'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
