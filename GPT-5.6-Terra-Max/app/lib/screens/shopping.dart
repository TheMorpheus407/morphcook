import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../copy.dart';
import '../models.dart';
import '../services.dart';
import '../theme.dart';
import '../widgets.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _checked = <String>{};

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final lines = ShoppingAggregator.aggregate(
      state.shoppingRecipes,
      state.repository.ingredientIndex,
    );
    final groups = ShoppingAggregator.byAisle(lines);
    return PaperScaffold(
      body: Column(
        children: [
          Masthead(
            compact: true,
            leading: const OverlayBackButton(),
            trailing: [
              IconButton(
                tooltip: Copybook.t('addToList', state.lang),
                onPressed: () => _pickRecipes(context),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    Copybook.t('shoppingList', state.lang),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
                Text(
                  '${lines.length}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          if (state.shoppingRecipes.isNotEmpty)
            SizedBox(
              height: 70,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 3, 20, 8),
                scrollDirection: Axis.horizontal,
                itemCount: state.shoppingRecipes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  final recipe = state.shoppingRecipes[index];
                  return InputChip(
                    label: Text(recipe.titleFor(state.lang)),
                    onDeleted: () => state.toggleShoppingRecipe(recipe.id),
                    avatar: CircleAvatar(
                      backgroundColor: stripeColor(recipe.stripeColor),
                      radius: 8,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: lines.isEmpty
                ? EmptyNote(
                    message: Copybook.t('emptyShopping', state.lang),
                    icon: Icons.shopping_basket_outlined,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 25),
                    children: groups.entries
                        .expand(
                          (entry) => [
                            SectionTitle(
                              children: _aisle(entry.key, state.lang),
                            ),
                            ...entry.value.map(
                              (line) => _ShoppingLineTile(
                                line: line,
                                checked: _checked.contains(line.ingredient?.id),
                                onChanged: (_) => setState(() {
                                  final id = line.ingredient?.id ?? '';
                                  if (!_checked.add(id)) _checked.remove(id);
                                }),
                              ),
                            ),
                          ],
                        )
                        .toList(),
                  ),
          ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
              child: InkButton(
                expanded: true,
                label: Copybook.t('finishShop', state.lang),
                icon: Icons.check,
                onPressed: () async {
                  await state.completeShoppingTrip();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(Copybook.t('done', state.lang))),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickRecipes(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MorphColors.paper,
      builder: (_) => const _ShoppingRecipePicker(),
    );
  }
}

class _ShoppingLineTile extends StatelessWidget {
  const _ShoppingLineTile({
    required this.line,
    required this.checked,
    required this.onChanged,
  });
  final ShoppingLine line;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeColor: MorphColors.teal,
      value: checked,
      onChanged: onChanged,
      title: Text(
        line.ingredient?.nameFor(state.lang) ?? 'unknown ingredient',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          decoration: checked ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: line.optional
          ? Text(
              state.lang == 'de' ? 'optional' : 'optional',
              style: Theme.of(context).textTheme.labelMedium,
            )
          : null,
      secondary: Text(
        line.amountLabel(),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }
}

class _ShoppingRecipePicker extends StatefulWidget {
  const _ShoppingRecipePicker();

  @override
  State<_ShoppingRecipePicker> createState() => _ShoppingRecipePickerState();
}

class _ShoppingRecipePickerState extends State<_ShoppingRecipePicker> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final query = _search.text.toLowerCase();
    final recipes =
        [
              ...state.savedRecipes,
              ...state.rankedVisibleRecipes().where(
                (recipe) => !state.savedRecipeIds.contains(recipe.id),
              ),
            ]
            .where(
              (recipe) =>
                  query.isEmpty ||
                  recipe.titleFor(state.lang).toLowerCase().contains(query),
            )
            .take(50)
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Copybook.t('addToList', state.lang),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  final selected = state.shoppingRecipeIds.contains(recipe.id);
                  return CheckboxListTile(
                    title: Text(recipe.titleFor(state.lang)),
                    subtitle: Text(
                      '${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal',
                    ),
                    value: selected,
                    onChanged: (_) => state.toggleShoppingRecipe(recipe.id),
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

String _aisle(String aisle, String lang) {
  const map = {
    'produce': {'en': 'produce', 'de': 'obst & gemüse'},
    'fridge': {'en': 'fridge', 'de': 'kühlregal'},
    'pantry': {'en': 'pantry', 'de': 'vorrat'},
    'spices': {'en': 'spices', 'de': 'gewürze'},
    'meat': {'en': 'meat', 'de': 'fleisch'},
    'bakery': {'en': 'bakery', 'de': 'bäckerei'},
  };
  return localize(map[aisle] ?? {'en': aisle, 'de': aisle}, lang);
}
