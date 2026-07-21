import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/copy.dart';
import '../state/app_controller.dart';
import '../widgets/recipe_card.dart';
import '../widgets/states.dart';
import 'recipe_detail_screen.dart';
import 'search_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  var _limit = 30;
  var _requestedContent = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_requestedContent) {
      _requestedContent = true;
      context.read<AppController>().ensureAllContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final all = app.savedRecipes;
    final recipes = all.take(_limit.clamp(0, 50)).toList();
    return Column(
      children: [
        ScreenHeader(title: Copy.text('cookbook', lang)),
        Expanded(
          child: app.loadingCorpus && all.isEmpty
              ? const EditorialSkeleton(rows: 4)
              : all.isEmpty
              ? EmptyPageNote(
                  icon: Icons.bookmark_add_outlined,
                  title: Copy.text('saved_empty', lang),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.extentAfter < 650 &&
                        _limit < all.length &&
                        _limit < 50) {
                      setState(() => _limit = (_limit + 30).clamp(0, 50));
                    }
                    return false;
                  },
                  child: ListView.builder(
                    key: const PageStorageKey('cookbook-list'),
                    padding: const EdgeInsets.all(16),
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final dish = app.content.dishById(recipe.dishId)!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 17),
                        child: RecipeCard(
                          recipe: recipe,
                          dish: dish,
                          language: lang,
                          dietLabel: app.ontology.label(recipe.diet, lang),
                          compact: true,
                          saved: true,
                          onSave: () => app.toggleSaved(recipe.id),
                          onTap: () => openRecipeDetail(
                            context,
                            recipe.dishId,
                            recipe.id,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
