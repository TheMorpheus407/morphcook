import 'package:flutter/material.dart';

import '../../domain/models/dish.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import 'morph_components.dart';

class RecipePickerSheet extends StatefulWidget {
  const RecipePickerSheet({
    required this.recipes,
    required this.dishesById,
    required this.profile,
    required this.savedRecipeIds,
    super.key,
  });

  final List<Recipe> recipes;
  final Map<String, Dish> dishesById;
  final UserProfile profile;
  final Set<String> savedRecipeIds;

  @override
  State<RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<RecipePickerSheet> {
  final _query = TextEditingController();
  var _cookbookOnly = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Recipe> get _results {
    final query = _query.text.trim().toLowerCase();
    final results = widget.recipes.where((recipe) {
      if (_cookbookOnly && !widget.savedRecipeIds.contains(recipe.id)) {
        return false;
      }
      if (query.isEmpty) return true;
      final dish = widget.dishesById[recipe.dishId];
      final corpus = [
        recipe.name.resolve(widget.profile.languageCode),
        recipe.name.resolve('en'),
        dish?.name.resolve(widget.profile.languageCode) ?? '',
        ...recipe.tags,
        ...recipe.cuisineTags,
        ...recipe.ingredientIds,
      ].join(' ').toLowerCase();
      return query.split(RegExp(r'\s+')).every(corpus.contains);
    }).toList();
    results.sort((a, b) {
      final aSaved = widget.savedRecipeIds.contains(a.id);
      final bSaved = widget.savedRecipeIds.contains(b.id);
      if (aSaved != bSaved) return aSaved ? -1 : 1;
      return a.name
          .resolve(widget.profile.languageCode)
          .compareTo(b.name.resolve(widget.profile.languageCode));
    });
    return results.take(50).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings('plan.emptySlot'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _query,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.strings('search.hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  MorphTag(
                    label: context.strings('nav.cookbook'),
                    icon: Icons.bookmark_outline_rounded,
                    selected: _cookbookOnly,
                    onSelected: (value) =>
                        setState(() => _cookbookOnly = value),
                  ),
                ],
              ),
            ),
            const DashedRule(),
            Expanded(
              child: results.isEmpty
                  ? MorphEmptyState(
                      title: context.strings('common.noResults'),
                      message: context.strings('search.hint'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final recipe = results[index];
                        final saved = widget.savedRecipeIds.contains(recipe.id);
                        return ListTile(
                          minTileHeight: 64,
                          leading: CircleAvatar(
                            backgroundColor: context.morph.teal.withValues(
                              alpha: .15,
                            ),
                            child: Icon(
                              saved ? Icons.bookmark : Icons.restaurant_menu,
                              color: context.morph.teal,
                            ),
                          ),
                          title: Text(
                            recipe.name.resolve(widget.profile.languageCode),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(
                            '${context.strings.format('common.recipeMeta', {'minutes': recipe.timeMinutes, 'calories': recipe.caloriesPerServing})} · ${context.strings.option('diet', recipe.diet)}',
                          ),
                          trailing: const Icon(
                            Icons.add_circle_outline_rounded,
                          ),
                          onTap: () => Navigator.pop(context, recipe),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
