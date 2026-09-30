import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n/app_strings.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import '../features/cookbook/cookbook_screen.dart';
import '../features/home/home_screen.dart';
import '../features/plan/plan_screen.dart';
import '../features/search/search_screen.dart';
import '../features/shopping/shopping_screen.dart';
import '../widgets/paper.dart';
import 'nav_requests.dart';

/// The five tabs: today, search, cookbook, plan and the shopping list.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;
  NavRequests? _nav;

  @override
  void initState() {
    super.initState();
    _nav = context.read<NavRequests>()..addListener(_onNavRequest);
  }

  @override
  void dispose() {
    _nav?.removeListener(_onNavRequest);
    super.dispose();
  }

  /// Other screens can ask for a tab ("view list", "more italian dishes").
  void _onNavRequest() {
    final tab = _nav?.consumeTab();
    if (tab != null && tab != _index && mounted) setState(() => _index = tab);
  }

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('nav.today', Icons.menu_book_outlined, Icons.menu_book),
    _Tab('nav.search', Icons.search, Icons.search),
    _Tab('nav.cookbook', Icons.bookmark_border, Icons.bookmark),
    _Tab('nav.plan', Icons.calendar_view_week_outlined, Icons.calendar_view_week),
    _Tab('nav.list', Icons.shopping_basket_outlined, Icons.shopping_basket),
  ];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Scaffold(
      backgroundColor: Palette.paper,
      body: PaperBackground(
        child: IndexedStack(
          index: _index,
          children: [
            HomeScreen(onOpenTab: (i) => setState(() => _index = i)),
            const SearchScreen(),
            const CookbookScreen(),
            const PlanScreen(),
            const ShoppingScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(color: Palette.paperLight),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DashedRule(color: Palette.rule),
              Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _NavItem(
                        label: s(_tabs[i].labelKey),
                        icon: _index == i ? _tabs[i].activeIcon : _tabs[i].icon,
                        selected: _index == i,
                        onTap: () => setState(() => _index = i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.labelKey, this.icon, this.activeIcon);
  final String labelKey;
  final IconData icon;
  final IconData activeIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.icon, required this.selected, required this.onTap});

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Palette.coralDeep : Palette.inkSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        child: SizedBox(
          height: 62,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 3),
              // Five labels share the width of a phone, so they follow the system
              // text size only up to a point (like Material's own navigation bar)
              // and shrink to their slot rather than wrap.
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: AppText.label(size: 9.5, color: color, weight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 16 : 0,
                height: 2,
                color: Palette.coral,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
