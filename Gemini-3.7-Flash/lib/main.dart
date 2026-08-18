import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'theme/vintage_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/cookbook_screen.dart';
import 'screens/meal_planner_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState();
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const MorphCookApp(),
    ),
  );
}

class MorphCookApp extends StatelessWidget {
  const MorphCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MorphCook',
      debugShowCheckedModeBanner: false,
      theme: VintageTheme.lightTheme,
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (!appState.isInitialized) {
      return const Scaffold(
        backgroundColor: VintageColors.paperBg,
        body: Center(
          child: CircularProgressIndicator(color: VintageColors.terracotta),
        ),
      );
    }

    if (!appState.profile.onboardingCompleted) {
      return OnboardingScreen(
        onComplete: () {
          setState(() {});
        },
      );
    }

    final lang = appState.lang;

    final screens = [
      const HomeScreen(),
      const SearchScreen(),
      const CookbookScreen(),
      const MealPlannerScreen(),
      const ShoppingScreen(),
    ];

    return Scaffold(
      backgroundColor: VintageColors.paperBg,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: VintageColors.paperCard,
          border: Border(top: BorderSide(color: VintageColors.paperBorder, width: 1)),
        ),
        child: SafeArea(
          child: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: VintageColors.paperCard,
            indicatorColor: VintageColors.terracotta.withValues(alpha: 0.15),
            elevation: 0,
            onDestinationSelected: (idx) {
              if (idx == 5) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else {
                setState(() => _currentIndex = idx);
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.newspaper_outlined),
                selectedIcon: const Icon(Icons.newspaper, color: VintageColors.terracotta),
                label: lang == 'de' ? 'Chronik' : 'Feed',
              ),
              NavigationDestination(
                icon: const Icon(Icons.search_outlined),
                selectedIcon: const Icon(Icons.search, color: VintageColors.terracotta),
                label: lang == 'de' ? 'Katalog' : 'Search',
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book, color: VintageColors.terracotta),
                label: lang == 'de' ? 'Kochbuch' : 'Notebook',
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month, color: VintageColors.terracotta),
                label: lang == 'de' ? 'Speiseplan' : 'Planner',
              ),
              NavigationDestination(
                icon: const Icon(Icons.shopping_bag_outlined),
                selectedIcon: const Icon(Icons.shopping_bag, color: VintageColors.terracotta),
                label: lang == 'de' ? 'Markt' : 'Market',
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings, color: VintageColors.terracotta),
                label: lang == 'de' ? 'Profil' : 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
