/// MorphCook — app entrypoint.
/// Boots the local store + bundled corpus, then shells out to Home.
library;

import 'package:flutter/material.dart';

import 'core/l10n.dart';
import 'core/theme.dart';
import 'state/store.dart';
import 'ui/home.dart';
import 'ui/morph.dart';
import 'ui/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence first (plain JSON in the app's documents dir).
  final store = AppStore();
  await store.load();

  final locus = LanguageNotifier(store.profile.lang);
  final corpus = await bootCorpus();

  runApp(MorphCookApp(store: store, locus: locus, corpus: corpus));
}

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({
    super.key,
    required this.store,
    required this.locus,
    required this.corpus,
  });

  final AppStore store;
  final LanguageNotifier locus;
  final CorpusNotifier corpus;

  @override
  Widget build(BuildContext context) {
    final data = MorphData(store, corpus, locus, DateTime.now());
    return ListenableBuilder(
      listenable: locus,
      builder: (context, _) => MaterialApp(
        title: 'MorphCook',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        home: Morph(
          data: data,
          child: ListenableBuilder(
            listenable: Listenable.merge([store, corpus]),
            builder: (context, _) => store.onboarded
                ? const HomeScreen()
                : const OnboardingPage(),
          ),
        ),
      ),
    );
  }
}
