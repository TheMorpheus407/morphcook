import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../i18n/strings.dart';
import '../theme.dart';
import '../widgets/paper.dart';
import 'cookbook_screen.dart';
import 'home_screen.dart';
import 'meal_plan_screen.dart';
import 'search_screen.dart';
import 'shopping_list_screen.dart';

/// Which bottom tab is showing; lets screens send the reader elsewhere.
class ShellTab extends ValueNotifier<int> {
  ShellTab() : super(0);
  static const today = 0, search = 1, cookbook = 2, plan = 3, list = 4;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _tab = ShellTab();

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return ChangeNotifierProvider.value(
      value: _tab,
      child: ValueListenableBuilder<int>(
        valueListenable: _tab,
        builder: (context, index, _) => Scaffold(
          body: PaperBackground(
            child: IndexedStack(
              index: index,
              children: const [HomeScreen(), SearchScreen(), CookbookScreen(), MealPlanScreen(), ShoppingListScreen()],
            ),
          ),
          bottomNavigationBar: _BottomBar(
            index: index,
            onTap: (i) => _tab.value = i,
            labels: [tr('nav.today'), tr('nav.search'), tr('nav.cookbook'), tr('nav.plan'), tr('nav.list')],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap, required this.labels});
  final int index;
  final ValueChanged<int> onTap;
  final List<String> labels;

  static const _icons = [
    Icons.wb_sunny_outlined,
    Icons.search,
    Icons.menu_book_outlined,
    Icons.calendar_view_week_outlined,
    Icons.checklist_rtl_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: MC.paper,
        border: Border(top: BorderSide(color: MC.rule)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    selected: i == index,
                    button: true,
                    label: labels[i],
                    child: InkWell(
                      key: Key('tab-$i'),
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_icons[i], size: 21, color: i == index ? MC.ink : MC.inkFaint),
                          const SizedBox(height: 3),
                          Text(
                            labels[i],
                            style: MT.mono(
                              10,
                              color: i == index ? MC.ink : MC.inkFaint,
                              weight: i == index ? FontWeight.w700 : FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                          ),
                          const SizedBox(height: 3),
                          AnimatedContainer(
                            duration: motion(context, const Duration(milliseconds: 200)),
                            width: i == index ? 18 : 0,
                            height: 2,
                            color: MC.coral,
                          ),
                        ],
                      ),
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
