import 'package:flutter/material.dart';

import 'screens.dart';
import 'store.dart';
import 'theme.dart';
import 'models.dart';
import 'widgets.dart';

void main() {
  runApp(const MorphCookApp());
}

class MorphCookApp extends StatefulWidget {
  const MorphCookApp({super.key});

  @override
  State<MorphCookApp> createState() => _MorphCookAppState();
}

class _MorphCookAppState extends State<MorphCookApp> {
  late final AppStore store;

  @override
  void initState() {
    super.initState();
    store = AppStore();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp(
          title: 'MorphCook',
          debugShowCheckedModeBanner: false,
          theme: buildMorphTheme(),
          home: AppShell(store: store),
        );
      },
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final showNavigation = <AppRoute>{
      AppRoute.home,
      AppRoute.cookbook,
      AppRoute.plan,
      AppRoute.search,
      AppRoute.settings,
    }.contains(store.route);
    return Scaffold(
      backgroundColor: store.route == AppRoute.cook ? night : paper,
      body: AnimatedSwitcher(
        duration: store.profile.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 230),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(
          key: ValueKey<AppRoute>(store.route),
          child: _screen(),
        ),
      ),
      bottomNavigationBar: showNavigation
          ? BottomNavBar(current: store.currentTab, onChanged: store.goToTab)
          : null,
    );
  }

  Widget _screen() {
    return switch (store.route) {
      AppRoute.home => HomeScreen(store: store),
      AppRoute.cookbook => CookbookScreen(store: store),
      AppRoute.plan => PlanScreen(store: store),
      AppRoute.search => SearchScreen(store: store),
      AppRoute.settings => SettingsScreen(store: store),
      AppRoute.recipe => RecipeDetailScreen(store: store),
      AppRoute.cook => CookModeScreen(store: store),
      AppRoute.shopping => ShoppingListScreen(store: store),
      AppRoute.insights => InsightsScreen(store: store),
      AppRoute.help => HelpScreen(store: store),
      AppRoute.profileEditor => ProfileEditorScreen(store: store),
      AppRoute.backup => BackupScreen(store: store),
      AppRoute.onboarding => OnboardingScreen(store: store),
    };
  }
}
