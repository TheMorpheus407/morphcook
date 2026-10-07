import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'core/corpus.dart';
import 'core/i18n/strings.dart';
import 'core/matching.dart';
import 'core/theme/app_theme.dart';
import 'features/cookbook/cookbook_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/plan/plan_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shopping/shopping_screen.dart';
import 'state/app_state.dart';
import 'state/storage.dart';
import 'widgets/paper.dart';
import 'widgets/spine_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/google_fonts/ — never fetched at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;

  await AppStorage.init();
  final corpus = Corpus();
  await corpus.init();
  final matcher = Matcher(ontology: corpus.ontology, ingredients: corpus.ingredients);
  final appState = AppState();
  await appState.init(corpus: corpus, matcher: matcher);

  runApp(MorphCookApp(appState: appState));
}

class MorphCookApp extends StatelessWidget {
  final AppState appState;

  const MorphCookApp({super.key, required this.appState});

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
        value: appState,
        child: Consumer<AppState>(
          builder: (context, appState, _) {
            final lang = appState.profile.lang == 'de' ? const Locale('de') : const Locale('en');
            return MaterialApp(
              title: 'morphcook',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              locale: lang,
              supportedLocales: const [Locale('en'), Locale('de')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: appState.onboardingComplete ? const Shell() : const OnboardingScreen(),
            );
          },
        ),
      );
}

/// The shell: five tabs on the spine (home, cookbook, week, market,
/// settings) over a fixed bottom nav with the coral tick.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    return PaperScaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          CookbookScreen(),
          PlanScreen(),
          ShoppingScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SpineNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        s: s,
      ),
    );
  }
}
