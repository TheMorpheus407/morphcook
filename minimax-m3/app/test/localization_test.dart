import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/localization/i18n.dart';
import 'package:morphcook/localization/strings.dart';

void main() {
  group('Localization', () {
    testWidgets('English copy is reachable', (tester) async {
      final notifier = LanguageNotifier('en');
      late Strings s;
      await tester.pumpWidget(
        MaterialApp(
          home: I18n(
            notifier: notifier,
            child: Builder(
              builder: (context) {
                s = I18n.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(s.appName, equals('MorphCook'));
      expect(s.tabHome, equals('home'));
      expect(s.cookbookEmpty, isNotEmpty);
    });

    testWidgets('German copy is reachable', (tester) async {
      final notifier = LanguageNotifier('de');
      late Strings s;
      await tester.pumpWidget(
        MaterialApp(
          home: I18n(
            notifier: notifier,
            child: Builder(
              builder: (context) {
                s = I18n.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(s.appName, equals('MorphCook'));
      expect(s.tabHome, equals('start'));
      expect(s.cookbookEmpty, isNotEmpty);
    });

    test('Language switch propagates', () {
      final s1 = Strings('en');
      final s2 = Strings('de');
      expect(s1.tabHome, isNot(equals(s2.tabHome)));
    });

    test('Unknown language falls back to English', () {
      final s = Strings('xx');
      expect(s.appName, equals('MorphCook'));
    });
  });
}
