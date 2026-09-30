import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/paper_tabs.dart';
import 'history_list.dart';
import 'saved_list.dart';

/// Saved variants (offset pagination) and the cooking history (time-based
/// pagination, grouped by week).
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ContentWidth(
            child: Column(
              children: [
                TabHeader(
                  title: s('cookbook.title'),
                  note: s('cookbook.note'),
                  actions: [
                    PaperIconButton(
                      icon: Icons.settings_outlined,
                      tooltip: s('nav.settings'),
                      onPressed: () => openSettings(context),
                    ),
                  ],
                ),
                PaperTabs(
                  labels: [s('cookbook.tab.saved'), s('cookbook.tab.history')],
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ),
          Expanded(
            child: ContentWidth(
              child: IndexedStack(
                index: _tab,
                children: [
                  SavedList(onOpen: (context, recipe, dish) => openDish(context, dish.id, recipeId: recipe.id)),
                  const HistoryList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
