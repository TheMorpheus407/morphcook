import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../widgets/recipe_card.dart';

/// Everything filed under one category, with the profile's preferred variant
/// of each dish. Dishes with no visible variant are listed at the bottom as
/// "hidden by your profile" rather than dropped.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    final dishes = state.repository.dishesInCategory(category);
    final visible = <(String, Recipe)>[];
    final hidden = <String>[];
    for (final dish in dishes) {
      final pick = state.preferredVariant(dish.id);
      if (pick == null) {
        hidden.add(dish.id);
      } else {
        visible.add((dish.id, pick));
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.category(category).toLowerCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            s.recipesCount(visible.length),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          for (final (_, recipe) in visible) ...[
            RecipeRow(recipe: recipe),
            DashedRule(color: colors.edge),
          ],
          if (hidden.isNotEmpty) ...[
            const SizedBox(height: 26),
            SectionHeader(s.dishHiddenByProfile),
            const SizedBox(height: 10),
            for (final dishId in hidden)
              Builder(
                builder: (context) {
                  final dish = state.repository.dish(dishId);
                  if (dish == null) return const SizedBox.shrink();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dish.name(s.lang),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      s.dishNothingVisibleHere,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: TextButton(
                      onPressed: () => openDish(context, dishId: dish.id),
                      child: Text(s.dishShowHidden),
                    ),
                  );
                },
              ),
          ],
          if (visible.isEmpty && hidden.isEmpty)
            EmptyNote(
              headline: s.searchEmptyTitle,
              body: s.homeNothingVisible,
              icon: Icons.inbox_outlined,
            ),
        ],
      ),
    );
  }
}
