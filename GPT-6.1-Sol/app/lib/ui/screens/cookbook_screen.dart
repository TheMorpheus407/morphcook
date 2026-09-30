import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/pagination.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dish_screen.dart';
import 'history_screen.dart';

class CookbookScreen extends StatefulWidget {
  final VoidCallback discover;
  const CookbookScreen({super.key, required this.discover});
  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  PaginationController<Recipe>? pages;
  final selected = <String>{};
  bool selecting = false;
  String? fingerprint;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    pages ??= PaginationController(
      pageSize: 30,
      type: PaginationType.offset,
      loader: (cursor, limit) async =>
          offsetPage(state.savedRecipes, cursor, limit),
    );
    final current = jsonEncode(state.saved);
    if (current != fingerprint) {
      fingerprint = current;
      selected.removeWhere((id) => !state.saved.containsKey(id));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pages!.refresh();
      });
    }
  }

  @override
  void dispose() {
    pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Column(
      children: [
        PageHeading(
          title: t(context, 'cookbookTitle'),
          subtitle: t(context, 'cookbookSubtitle'),
          trailing: IconButton(
            tooltip: t(context, 'history'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
            icon: const Icon(Icons.history, color: KitchenColors.teal),
          ),
        ),
        if (state.saved.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Text(
                  t(context, selecting ? 'selected' : 'results', {
                    'count': selecting ? selected.length : state.saved.length,
                  }),
                  style: mono(10),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    selecting = !selecting;
                    selected.clear();
                  }),
                  child: Text(t(context, selecting ? 'done' : 'selectRecipes')),
                ),
              ],
            ),
          ),
        Expanded(
          child: PagedRecipes(
            controller: pages!,
            selectionMode: selecting,
            selectedIds: selected,
            onOpen: (recipe) {
              if (selecting) {
                if (!state.isVisible(recipe)) {
                  toast(context, 'savedMismatch');
                  return;
                }
                setState(
                  () => selected.add(recipe.id)
                      ? null
                      : selected.remove(recipe.id),
                );
              } else {
                openRecipe(context, recipe);
              }
            },
            empty: EmptyPaper(
              title: t(context, 'emptyCookbook'),
              body: t(context, 'emptyCookbookBody'),
              action: FilledButton(
                onPressed: widget.discover,
                child: Text(t(context, 'browse')),
              ),
            ),
          ),
        ),
        if (selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        state.addShopping(
                          selected.map(
                            (id) => RecipeSelection(
                              state.repository.recipes[id]!,
                              state.repository.recipes[id]!.servings,
                            ),
                          ),
                        );
                        toast(context, 'addedShopping');
                        setState(() {
                          selecting = false;
                          selected.clear();
                        });
                      },
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: Text(t(context, 'addSelected')),
              ),
            ),
          ),
      ],
    );
  }
}
