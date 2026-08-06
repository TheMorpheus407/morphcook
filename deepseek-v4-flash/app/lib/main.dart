import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/app_state.dart';
import 'data/corpus.dart';
import 'data/services.dart';
import 'logic/matching.dart';
import 'ui/app_shell.dart';
import 'ui/onboarding.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final dir = await getApplicationDocumentsDirectory();
  await AppState.openHive(dir.path);
  final state = AppState.instance;
  await state.init(
    prefs: prefs,
    cookbookBox: Hive.box('cookbook'),
    historyBox: Hive.box('history'),
    mealPlanBox: Hive.box('meal_plan'),
    shoppingBox: Hive.box('shopping'),
    checkedBox: Hive.box('shopping_checked'),
    eventsBox: Hive.box('events'),
  );

  final corpus = Corpus();
  await corpus.load();

  runApp(MorphCookApp(state: state, corpus: corpus));
}

class MorphCookApp extends StatelessWidget {
  final AppState state;
  final Corpus corpus;

  const MorphCookApp({super.key, required this.state, required this.corpus});

  @override
  Widget build(BuildContext context) {
    final matcher = RecipeMatcher(corpus);
    return Services(
      corpus: corpus,
      state: state,
      matcher: matcher,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final lang = state.lang;
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            locale: Locale(lang == 'de' ? 'de' : 'en'),
            supportedLocales: const [Locale('en'), Locale('de')],
            home: state.profile.completedOnboarding
                ? const AppShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}