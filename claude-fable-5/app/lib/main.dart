import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'data/corpus.dart';
import 'data/store.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/cookbook_screen.dart';
import 'ui/screens/meal_plan_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/search_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/strings.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // OFL fonts must ship with their license text; surface it on the
  // standard licenses page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle
        .loadString('assets/fonts/OFL-AtkinsonHyperlegible.txt');
    yield LicenseEntryWithLineBreaks(const ['Atkinson Hyperlegible'], text);
  });
  runApp(const MorphCookApp());
}

class MorphCookApp extends StatefulWidget {
  const MorphCookApp({super.key});

  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  late final Future<AppState> _boot = _initialize();

  Future<AppState> _initialize() async {
    final corpus = CorpusRepository(bundle: rootBundle);
    await corpus.initialize();
    final state = AppState(store: HiveStore(), corpus: corpus);
    await state.load();
    return state;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppState>(
      future: _boot,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return MaterialApp(
            title: 'MorphCook',
            debugShowCheckedModeBanner: false,
            theme: morphThemeData(MorphColors.light),
            home: const _BootSplash(),
          );
        }
        // The provider must sit ABOVE MaterialApp: routes pushed via the
        // Navigator live outside `home`'s subtree and would otherwise not
        // find AppState.
        return ChangeNotifierProvider.value(
            value: state, child: const ThemedApp());
      },
    );
  }
}

/// MaterialApp that follows the profile's appearance settings. Sits below
/// the provider so a settings change re-themes the running app in place.
class ThemedApp extends StatelessWidget {
  const ThemedApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AppState>().profile;
    final mode = switch (profile.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'MorphCook',
      debugShowCheckedModeBanner: false,
      theme: morphThemeData(MorphColors.light, readable: profile.readableText),
      darkTheme:
          morphThemeData(MorphColors.dark, readable: profile.readableText),
      themeMode: mode,
      // The builder wraps the Navigator, so every route sees MorphTheme.
      builder: (context, child) {
        final dark = switch (mode) {
          ThemeMode.dark => true,
          ThemeMode.light => false,
          ThemeMode.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return MorphTheme(
          data: MorphThemeData(
            colors: dark ? MorphColors.dark : MorphColors.light,
            readable: profile.readableText,
          ),
          child: child!,
        );
      },
      home: const _Root(),
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    return Scaffold(
      body: PaperBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('morphcook',
                  style: morph.text.display.copyWith(fontSize: 40)),
              const SizedBox(height: 8),
              Text('&', style: morph.text.handAt(28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<AppState, bool>((s) => s.onboarded);
    return onboarded ? const RootShell() : const OnboardingScreen();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().lang);
    final morph = MorphTheme.of(context);
    const pages = [
      HomeScreen(),
      SearchScreen(),
      CookbookScreen(),
      MealPlanScreen(),
      SettingsScreen(),
    ];
    return Scaffold(
      body: PaperBackground(
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: morph.colors.card,
          border: Border(top: BorderSide(color: morph.colors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _navItem(0, Icons.auto_stories_outlined, s('navHome')),
                _navItem(1, Icons.search, s('navSearch')),
                _navItem(2, Icons.bookmark_border, s('navCookbook')),
                _navItem(3, Icons.calendar_today_outlined, s('navPlan')),
                _navItem(4, Icons.tune, s('navSettings')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    final morph = MorphTheme.of(context);
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Semantics(
          selected: selected,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 20,
                  color: selected
                      ? morph.colors.terracotta
                      : morph.colors.inkSoft),
              const SizedBox(height: 2),
              Text(morph.cased(label),
                  style: morph.text.label(
                      size: 9,
                      color: selected
                          ? morph.colors.terracotta
                          : morph.colors.inkSoft)),
            ],
          ),
        ),
      ),
    );
  }
}
