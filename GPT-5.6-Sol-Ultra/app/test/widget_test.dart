import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/l10n/app_strings.dart';

void main() {
  testWidgets('bilingual strings scope updates visible copy', (tester) async {
    Widget testApp(String language) => MaterialApp(
      home: MorphStringsScope(
        languageCode: language,
        child: Builder(
          builder: (context) => Text(context.strings('nav.cookbook')),
        ),
      ),
    );

    await tester.pumpWidget(testApp('en'));
    expect(find.text('cookbook'), findsOneWidget);

    await tester.pumpWidget(testApp('de'));
    expect(find.text('kochbuch'), findsOneWidget);
  });
}
