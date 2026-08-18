import 'package:flutter/material.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';
import 'state/app_state.dart';

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({
    super.key,
    required this.corpus,
    required this.store,
    required this.loc,
  });

  final Corpus corpus;
  final AppStore store;
  final LocaleController loc;

  @override
  Widget build(BuildContext context) {
    // AppScope sits above the Navigator so every pushed route
    // (dish detail, cook mode, backup…) can reach the providers.
    return AppScope(
      corpus: corpus,
      store: store,
      loc: loc,
      child: AnimatedBuilder(
        animation: loc,
        builder: (context, _) {
          final reduceMotion = store.profile.reduceMotion;
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: MorphTheme.light(reduceMotion: reduceMotion),
            themeMode: ThemeMode.light,
            home: ListenableBuilder(
              listenable: store,
              builder: (context, _) => store.profile.onboarded
                  ? const Shell()
                  : const OnboardingScreen(),
            ),
          );
        },
      ),
    );
  }
}
