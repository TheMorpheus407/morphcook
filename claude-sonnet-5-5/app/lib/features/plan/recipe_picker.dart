import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/paper_tabs.dart';
import '../cookbook/saved_list.dart';
import '../search/search_panel.dart';

/// Choose a recipe for a meal-plan slot: from the cookbook or from search.
/// Pops with the chosen recipe id.
class RecipePickerScreen extends StatefulWidget {
  const RecipePickerScreen({super.key, required this.slotLabel});

  /// Where the recipe will go, for the heading ("monday dinner").
  final String slotLabel;

  @override
  State<RecipePickerScreen> createState() => _RecipePickerScreenState();
}

class _RecipePickerScreenState extends State<RecipePickerScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return PaperScaffold(
      body: SafeArea(
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Transform.translate(
                    offset: const Offset(-12, 0),
                    child: PaperIconButton(
                      icon: Icons.close,
                      tooltip: s('common.close'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(child: MonoLabel(widget.slotLabel)),
                ],
              ),
              TabHeader(title: s('plan.picker.title'), note: s('plan.picker.note')),
              PaperTabs(
                labels: [s('cookbook.tab.saved'), s('nav.search')],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    SavedList(
                      showUnsave: false,
                      emptyAction: () => setState(() => _tab = 1),
                      onOpen: (context, recipe, dish) => Navigator.of(context).pop(recipe.id),
                    ),
                    SearchPanel(
                      listenToNavRequests: false,
                      onOpen: (context, hit) => Navigator.of(context).pop(hit.entry.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
