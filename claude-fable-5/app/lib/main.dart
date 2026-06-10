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
        // The provider must sit ABOVE MaterialApp: routes pushed via the
        // Navigator live outside `home`'s subtree and would otherwise not
        // find AppState.
        final app = MaterialApp(
          title: 'MorphCook',
          debugShowCheckedModeBanner: false,
          theme: morphTheme(),
          home: state == null ? const _BootSplash() : const _Root(),
        );
        return state == null
            ? app
            : ChangeNotifierProvider.value(value: state, child: app);
      },
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PaperBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('morphcook',
                  style: MorphText.display.copyWith(fontSize: 40)),
              const SizedBox(height: 8),
              Text('&', style: MorphText.hand.copyWith(fontSize: 28)),
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
        decoration: const BoxDecoration(
          color: MorphColors.card,
          border: Border(top: BorderSide(color: MorphColors.line)),
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
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 20,
                color:
                    selected ? MorphColors.terracotta : MorphColors.inkSoft),
            const SizedBox(height: 2),
            Text(label.toLowerCase(),
                style: MorphText.label(
                    size: 9,
                    color: selected
                        ? MorphColors.terracotta
                        : MorphColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}
