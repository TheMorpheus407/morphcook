import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/ui/onboarding.dart';
import 'package:morphcook/ui/strings.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

void main() {
  testWidgets('onboarding language step renders', (tester) async {
    final state = AppState(
      store: MemoryStore(),
      corpus: CorpusRepository(bundle: rootBundle),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: LedgerTheme.of(InkPalette.morning),
          builder: (context, child) => LedgerScope(
            palette: InkPalette.morning,
            reduceMotion: true,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.textContaining(S('en')('obLanguageTitle').split(' ').first), findsWidgets);
    expect(find.text('english'), findsOneWidget);
    expect(find.text('deutsch'), findsOneWidget);
  });
}
