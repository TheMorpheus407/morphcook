import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/theme/app_theme.dart';
import 'package:morphcook/widgets/paper_widgets.dart';

void main() {
  testWidgets('paper and typography render without network assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(
          body: Paper(child: Center(child: Text('morphcook.'))),
        ),
      ),
    );
    expect(find.text('morphcook.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.text('morphcook.'));
    expect(
      DefaultTextStyle.of(tester.element(find.byWidget(text))).style.fontFamily,
      'Playfair Display',
    );
  });
}
