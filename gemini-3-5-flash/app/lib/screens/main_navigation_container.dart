import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/brand_theme.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'cookbook_screen.dart';
import 'meal_planner_screen.dart';
import 'shopping_list_screen.dart';
import 'settings_screen.dart';

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() => _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(),
    const CookbookScreen(),
    const MealPlannerScreen(),
    const ShoppingListScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    final labels = isEn
        ? ["home", "search", "cookbook", "meal plan", "shopping"]
        : ["home", "suche", "kochbuch", "essensplan", "einkauf"];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: BrandColors.creamBg,
        title: Text(
          "hello, ${provider.profile.name.toLowerCase()}",
          style: BrandFonts.handwritten(fontSize: 24.0, color: BrandColors.coral),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: BrandColors.charcoalInk),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: DashedDivider(),
        ),
      ),
      body: PaperGrainBackground(
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: BrandColors.charcoalInk, width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: BrandColors.creamBg,
          selectedItemColor: BrandColors.coral,
          unselectedItemColor: BrandColors.charcoalInk.withOpacity(0.5),
          selectedLabelStyle: BrandFonts.mono(fontSize: 10.0, fontWeight: FontWeight.bold),
          unselectedLabelStyle: BrandFonts.mono(fontSize: 10.0),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.roofing_outlined),
              activeIcon: const Icon(Icons.roofing),
              label: labels[0],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search_outlined),
              activeIcon: const Icon(Icons.search),
              label: labels[1],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.bookmark_border_outlined),
              activeIcon: const Icon(Icons.bookmark),
              label: labels[2],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_today_outlined),
              activeIcon: const Icon(Icons.calendar_today),
              label: labels[3],
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_basket_outlined),
              activeIcon: const Icon(Icons.shopping_basket),
              label: labels[4],
            ),
          ],
        ),
      ),
    );
  }
}
