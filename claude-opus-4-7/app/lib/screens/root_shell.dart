import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'cookbook_screen.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'shopping_list_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _pages = <Widget>[
    const HomeScreen(),
    const CookbookScreen(),
    const SearchScreen(),
    const MealPlanScreen(),
    const ShoppingListScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: _PaperNavBar(
        index: _index,
        items: [
          (Icons.menu_book_outlined, l.t('nav.home')),
          (Icons.bookmark_outline, l.t('nav.cookbook')),
          (Icons.search, l.t('nav.search')),
          (Icons.calendar_view_week, l.t('nav.plan')),
          (Icons.shopping_basket_outlined, l.t('nav.shop')),
          (Icons.settings_outlined, l.t('nav.settings')),
        ],
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _PaperNavBar extends StatelessWidget {
  final int index;
  final List<(IconData, String)> items;
  final ValueChanged<int> onTap;
  const _PaperNavBar(
      {required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MorphColors.paper,
        border: Border(top: BorderSide(color: MorphColors.inkFaint)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (int i = 0; i < items.length; i++)
                InkResponse(
                  onTap: () => onTap(i),
                  radius: 30,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(items[i].$1,
                            size: 22,
                            color: index == i
                                ? MorphColors.ink
                                : MorphColors.inkMuted),
                        const SizedBox(height: 2),
                        Text(items[i].$2.toUpperCase(),
                            style: MorphType.smallCaps(
                                size: 8,
                                color: index == i
                                    ? MorphColors.ink
                                    : MorphColors.inkMuted)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 1.5,
                          width: index == i ? 22 : 0,
                          color: MorphColors.ink,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
