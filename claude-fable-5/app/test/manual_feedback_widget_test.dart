import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/data/user_manual.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/ui/screens/faq_screen.dart';
import 'package:morphcook/ui/screens/feedback_screen.dart';
import 'package:morphcook/ui/screens/settings_screen.dart';
import 'package:morphcook/ui/screens/user_manual_screen.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

Future<AppState> helpState({String lang = 'en'}) async {
  final state = AppState(
    corpus: await loadRealCorpus(all: false),
    store: MemoryStore(),
  );
  await state.load();
  await state.completeOnboarding(
    Profile(name: 'private profile never attached', lang: lang),
  );
  return state;
}

Widget helpApp(AppState state, Widget home) => ChangeNotifierProvider.value(
  value: state,
  child: MaterialApp(theme: morphThemeData(MorphColors.light), home: home),
);

Future<void> tapKey(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> enterFeedback(
  WidgetTester tester, {
  String title = 'Timer & portions?',
  String message = 'Step 2\nExpected: pause. Actual: reset.',
}) async {
  await tester.enterText(find.byKey(const ValueKey('feedback-title')), title);
  await tester.enterText(
    find.byKey(const ValueKey('feedback-message')),
    message,
  );
}

void main() {
  WidgetController.hitTestWarningShouldBeFatal = true;

  for (final lang in ['en', 'de']) {
    testWidgets('Settings opens the offline manual and feedback in $lang', (
      tester,
    ) async {
      final state = (await tester.runAsync(() => helpState(lang: lang)))!;
      await tester.pumpWidget(
        helpApp(state, const Scaffold(body: SettingsScreen())),
      );
      await tester.pumpAndSettle();
      final manual = find.text(
        lang == 'de' ? 'Bedienungsanleitung' : 'User manual',
      );
      await tester.scrollUntilVisible(
        manual,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(find.byType(UserManualScreen), findsOneWidget);
      expect(
        find.textContaining(
          lang == 'de' ? 'Offline verfügbar.' : 'Available offline.',
        ),
        findsOneWidget,
      );

      // Search the actual bundled body text, then read the result on screen.
      await tester.enterText(
        find.byKey(const ValueKey('manual-search')),
        'Sonnet',
      );
      await tester.pumpAndSettle();
      expect(find.byType(ExpansionTile), findsOneWidget);
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      final body = tester
          .widget<SelectableText>(find.byType(SelectableText))
          .data!;
      expect(body, contains('Sonnet'));
      expect(body, contains(lang == 'de' ? 'Kein KI-Dienst' : 'No AI service'));
      expect(
        body,
        contains(
          lang == 'de' ? 'passwortgeschützte PDFs' : 'password-protected PDFs',
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('manual-search')),
        'no-such-topic-9182',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('manual-no-results')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      final feedback = find.text('Feedback');
      await tester.scrollUntilVisible(
        feedback,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(feedback);
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackScreen), findsOneWidget);
      expect(find.text(lang == 'de' ? 'Titel' : 'Title'), findsOneWidget);
      expect(
        find.text(lang == 'de' ? 'GitHub-Entwurf öffnen' : 'Open GitHub draft'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('FAQ links to the manual, and the manual links to the composer', (
    tester,
  ) async {
    final state = (await tester.runAsync(helpState))!;
    await tester.pumpWidget(helpApp(state, const FaqScreen()));
    await tapKey(tester, 'faq-manual');
    expect(find.byType(UserManualScreen), findsOneWidget);
    await tapKey(tester, 'manual-feedback');
    expect(find.byType(FeedbackScreen), findsOneWidget);
  });

  test(
    'both offline manuals cover the shipped workflows and review limits',
    () {
      expect(
        userManualSections.map((e) => e.id).toSet(),
        containsAll([
          'profile',
          'variants',
          'personal',
          'website',
          'pdf',
          'sharing',
          'planning',
          'cooking',
          'expert',
          'backup',
          'accessibility',
          'feedback',
        ]),
      );
      for (final section in userManualSections) {
        expect(section.titleEn, isNotEmpty);
        expect(section.titleDe, isNotEmpty);
        expect(section.bodyEn, isNotEmpty);
        expect(section.bodyDe, isNotEmpty);
      }
      final expert = userManualSections.singleWhere((e) => e.id == 'expert');
      expect(expert.bodyEn, contains('not verified ratings'));
      expect(expert.bodyDe, contains('keine verifizierten Bewertungen'));
      expect(expert.bodyEn, contains('excluded from recipe-sharing ZIPs'));
      final timer = userManualSections.singleWhere((e) => e.id == 'cooking');
      expect(timer.bodyEn, contains('Pause a running timer before leaving'));
      expect(timer.bodyDe, contains('Pausiere einen laufenden Timer'));
    },
  );

  testWidgets(
    'opening a draft requires entered text and passes no profile data',
    (tester) async {
      final state = (await tester.runAsync(helpState))!;
      final opened = <Uri>[];
      await tester.pumpWidget(
        helpApp(
          state,
          FeedbackScreen(
            openDraft: (uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await tapKey(tester, 'open-feedback-draft');
      expect(opened, isEmpty);
      expect(find.text('Please enter some text.'), findsNWidgets(2));
      await enterFeedback(tester);
      await tapKey(tester, 'open-feedback-draft');
      expect(opened, hasLength(1));
      expect(opened.single.queryParameters, {
        'title': 'Timer & portions?',
        'body': 'Step 2\nExpected: pause. Actual: reset.',
      });
      expect(opened.single.toString(), isNot(contains('private')));
      expect(
        find.textContaining('Review it and submit it there.'),
        findsOneWidget,
      );
    },
  );

  for (final throwsError in [false, true]) {
    testWidgets(
      'browser ${throwsError ? 'exception' : 'refusal'} keeps a copyable draft',
      (tester) async {
        final state = (await tester.runAsync(helpState))!;
        String? copied;
        var attempts = 0;
        await tester.pumpWidget(
          helpApp(
            state,
            FeedbackScreen(
              openDraft: (_) async {
                attempts++;
                if (throwsError) throw StateError('browser unavailable');
                return false;
              },
              copyDraft: (text) async => copied = text,
            ),
          ),
        );
        await enterFeedback(tester);
        await tapKey(tester, 'open-feedback-draft');
        expect(attempts, 1);
        expect(
          find.textContaining('The browser could not open the draft.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const ValueKey('feedback-title')),
              )
              .controller!
              .text,
          'Timer & portions?',
        );
        await tapKey(tester, 'copy-feedback');
        expect(
          copied,
          'Timer & portions?\n\nStep 2\nExpected: pause. Actual: reset.',
        );
        expect(attempts, 1);
        expect(find.text('Feedback copied.'), findsOneWidget);
      },
    );
  }

  testWidgets('encoded URL overflow still permits complete offline copying', (
    tester,
  ) async {
    final state = (await tester.runAsync(helpState))!;
    var opened = false;
    String? copied;
    await tester.pumpWidget(
      helpApp(
        state,
        FeedbackScreen(
          openDraft: (_) async => opened = true,
          copyDraft: (text) async => copied = text,
        ),
      ),
    );
    final message = '料' * 1000;
    await enterFeedback(tester, title: 'PDF', message: message);
    await tapKey(tester, 'open-feedback-draft');
    expect(opened, isFalse);
    expect(find.textContaining('too long for a browser link'), findsOneWidget);
    await tapKey(tester, 'copy-feedback');
    expect(copied, 'PDF\n\n$message');
    expect(opened, isFalse);
  });

  testWidgets('clipboard errors retain text and allow retry', (tester) async {
    final state = (await tester.runAsync(() => helpState(lang: 'de')))!;
    var copies = 0;
    String? copied;
    await tester.pumpWidget(
      helpApp(
        state,
        FeedbackScreen(
          copyDraft: (text) async {
            if (copies++ == 0) throw StateError('clipboard busy');
            copied = text;
          },
        ),
      ),
    );
    await enterFeedback(tester);
    await tapKey(tester, 'copy-feedback');
    expect(find.textContaining('Kopieren fehlgeschlagen.'), findsOneWidget);
    await tapKey(tester, 'copy-feedback');
    expect(copies, 2);
    expect(copied, startsWith('Timer & portions?\n\n'));
    expect(find.text('Feedback kopiert.'), findsOneWidget);
  });

  testWidgets('cancel discards the local draft without launching or copying', (
    tester,
  ) async {
    final state = (await tester.runAsync(helpState))!;
    var actions = 0;
    await tester.pumpWidget(
      helpApp(
        state,
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                key: const ValueKey('compose'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FeedbackScreen(
                      openDraft: (_) async {
                        actions++;
                        return true;
                      },
                      copyDraft: (_) async {
                        actions++;
                      },
                    ),
                  ),
                ),
                child: const Text('Compose'),
              ),
            );
          },
        ),
      ),
    );
    await tapKey(tester, 'compose');
    await enterFeedback(tester);
    await tapKey(tester, 'cancel-feedback');
    expect(find.byType(FeedbackScreen), findsNothing);
    await tapKey(tester, 'compose');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('feedback-title')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('feedback-message')))
          .controller!
          .text,
      isEmpty,
    );
    expect(actions, 0);
  });

  testWidgets(
    'pending browser handoff disables repeat actions and tolerates back',
    (tester) async {
      final state = (await tester.runAsync(helpState))!;
      final pending = Completer<bool>();
      var calls = 0;
      await tester.pumpWidget(
        helpApp(
          state,
          Builder(
            builder: (context) {
              return Scaffold(
                body: TextButton(
                  key: const ValueKey('compose'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FeedbackScreen(
                        openDraft: (_) {
                          calls++;
                          return pending.future;
                        },
                      ),
                    ),
                  ),
                  child: const Text('Compose'),
                ),
              );
            },
          ),
        ),
      );
      await tapKey(tester, 'compose');
      await enterFeedback(tester);
      await tapKey(tester, 'open-feedback-draft');
      expect(calls, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('open-feedback-draft')),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('copy-feedback')))
            .onPressed,
        isNull,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(FeedbackScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
