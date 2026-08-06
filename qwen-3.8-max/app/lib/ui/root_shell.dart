import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/corpus_repository.dart';
import '../state/app_model.dart';
import '../state/library_model.dart';
import 'cookbook/cookbook_screen.dart';
import 'home/home_screen.dart';
import 'onboarding/onboarding_flow.dart';
import 'plan/plan_screen.dart';
import 'search/search_screen.dart';
import 'settings/settings_screen.dart';
import 'shopping/shopping_screen.dart';

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final corpus = context.read<CorpusRepository>();
    if (!corpus.ready) {
      return const Scaffold(
        body: Center(child: Text('…', style: TextStyle(color: Paper.inkSoft))),
      );
    }
    if (!app.onboardingDone) {
      return const OnboardingFlow();
    }
    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  static const _screens = [
    HomeScreen(),
    SearchScreen(),
    CookbookScreen(),
    PlanScreen(),
    ShoppingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final library = context.watch<LibraryModel>();
    final shoppingCount =
        library.shoppingItems().where((i) => !i.checked).length;

    return PaperGrain(
      child: Scaffold(
        body: IndexedStack(index: _tab, children: _screens),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Paper.card,
            border: Border(top: BorderSide(color: Paper.rule)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _TabButton(
                    label: s.get('home'),
                    icon: Icons.home_outlined,
                    selected: _tab == 0,
                    onTap: () => setState(() => _tab = 0),
                  ),
                  _TabButton(
                    label: s.get('search'),
                    icon: Icons.search_outlined,
                    selected: _tab == 1,
                    onTap: () => setState(() => _tab = 1),
                  ),
                  _TabButton(
                    label: s.get('cookbook'),
                    icon: Icons.book_outlined,
                    selected: _tab == 2,
                    onTap: () => setState(() => _tab = 2),
                  ),
                  _TabButton(
                    label: s.get('plan'),
                    icon: Icons.calendar_month_outlined,
                    selected: _tab == 3,
                    onTap: () => setState(() => _tab = 3),
                  ),
                  _TabButton(
                    label: s.get('shopping'),
                    icon: Icons.shopping_basket_outlined,
                    selected: _tab == 4,
                    badge: shoppingCount,
                    onTap: () => setState(() => _tab = 4),
                  ),
                  _TabButton(
                    label: s.get('settings'),
                    icon: Icons.settings_outlined,
                    selected: false,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon,
                    size: 21,
                    color: selected ? Paper.coral : Paper.inkSoft),
                if (badge > 0)
                  Positioned(
                    right: -7,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: const BoxDecoration(
                        color: Paper.coral,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: Type.mono(size: 8, color: Paper.white),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Type.label(
                color: selected ? Paper.coral : Paper.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
