import 'package:flutter/material.dart';
import '../state/app_state.dart';
import 'theme.dart';
import 'widgets.dart';
import 'screens/cookbook_screen.dart';
import 'screens/home_screen.dart';
import 'screens/meal_plan_screen.dart';
import 'screens/search_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/shopping_screen.dart';

class KitchenShell extends StatefulWidget {
  const KitchenShell({super.key});
  @override
  State<KitchenShell> createState() => _KitchenShellState();
}

class _KitchenShellState extends State<KitchenShell> {
  int index = 0;
  final visited = <int>{0};
  void select(int value) {
    setState(() {
      index = value;
      visited.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const keys = ['home', 'search', 'cookbook', 'plan', 'shopping'];
    const icons = [
      Icons.home_outlined,
      Icons.search,
      Icons.bookmark_border,
      Icons.calendar_today_outlined,
      Icons.shopping_bag_outlined,
    ];
    final pages = [
      HomeScreen(discover: () => select(1)),
      const SearchScreen(),
      CookbookScreen(discover: () => select(1)),
      const MealPlanScreen(),
      const ShoppingScreen(),
    ];
    return PaperScaffold(
      appBar: KitchenAppBar(
        actions: [
          IconButton(
            tooltip: t(context, 'settings'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.tune, size: 22),
          ),
        ],
      ),
      body: Column(
        children: [
          if (state.storageError != null)
            Material(
              color: KitchenColors.coral.withValues(alpha: .15),
              child: InkWell(
                onTap: () => state.persist().catchError((Object _) {}),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(t(context, 'storageError'), style: mono(10)),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: index,
              children: pages.indexed
                  .map(
                    (entry) => visited.contains(entry.$1)
                        ? entry.$2
                        : const SizedBox.shrink(),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ColoredBox(
        color: KitchenColors.paper,
        child: SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: KitchenColors.line)),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Row(
                children: [
                  for (var i = 0; i < keys.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: index == i,
                        button: true,
                        child: InkWell(
                          onTap: () => select(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icons[i],
                                  color: index == i
                                      ? KitchenColors.teal
                                      : KitchenColors.muted,
                                  size: 23,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  t(context, keys[i]),
                                  style: mono(
                                    9,
                                    color: index == i
                                        ? KitchenColors.teal
                                        : KitchenColors.muted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  width: 13,
                                  height: 2,
                                  color: index == i
                                      ? KitchenColors.teal
                                      : Colors.transparent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
