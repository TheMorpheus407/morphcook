import 'package:flutter_test/flutter_test.dart';

import 'package:morphcook/main.dart';
import 'package:morphcook/widgets.dart';

void main() {
  testWidgets('home opens with the calm cookbook masthead', (tester) async {
    await tester.pumpWidget(const MorphCookApp());
    await tester.pumpAndSettle();

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.textContaining('good'), findsOneWidget);
    expect(find.text('Döner'), findsWidgets);
  });
}
