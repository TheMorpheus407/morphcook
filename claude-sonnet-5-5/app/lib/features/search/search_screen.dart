import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper_controls.dart';
import 'search_panel.dart';

/// The search tab.
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabHeader(
              title: s('search.title'),
              note: s('search.note'),
              actions: [
                PaperIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: s('nav.settings'),
                  onPressed: () => openSettings(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SearchPanel(onOpen: (context, hit) => openDish(context, hit.dish.id, recipeId: hit.entry.id)),
            ),
          ],
        ),
      ),
    );
  }
}
