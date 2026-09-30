import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cook_screen.dart';
import 'dish_screen.dart';
import 'help_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback discover;
  const HomeScreen({super.key, required this.discover});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final recipes = state.homeRecipes;
    final quick = recipes.where((r) => r.timeMinutes <= 30).take(4).toList();
    final comfort = recipes
        .where((r) => r.tags.contains('cozy'))
        .take(4)
        .toList();
    final feature = recipes.firstOrNull;
    final resume = state.repository.recipes[state.cookProgress?['recipe_id']];
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 23, 22, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(t(context, 'daily'), style: mono(9, spacing: 1.8)),
            ),
            Text(
              DateFormat(
                'dd MMM yyyy',
                state.profile.lang,
              ).format(DateTime.now()).toUpperCase(),
              style: mono(9),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 15),
        Center(
          child: Text(t(context, 'brand'), style: serif(52, italic: true)),
        ),
        const SizedBox(height: 6),
        Center(child: Text(t(context, 'tagline'), style: hand(23))),
        const SizedBox(height: 18),
        const Divider(height: 1),
        const SizedBox(height: 6),
        Center(child: Text(t(context, 'volume'), style: mono(8, spacing: 1.4))),
        const SizedBox(height: 29),
        Text(
          t(context, 'hello', {
            'name': state.profile.name.isEmpty
                ? t(context, 'helloFallback')
                : state.profile.name,
          }),
          style: hand(27),
        ),
        const SizedBox(height: 10),
        Text(t(context, 'homeTitle'), style: serif(38, italic: true)),
        const SizedBox(height: 12),
        Text(t(context, 'homeSubtitle'), style: mono(11)),
        const SizedBox(height: 22),
        if (resume != null) ...[
          NoteCard(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CookScreen(recipe: resume),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    size: 30,
                    color: KitchenColors.teal,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t(context, 'resumeTitle'), style: hand(23)),
                        Text(textFor(context, resume.title), style: mono(10)),
                        const SizedBox(height: 5),
                        Text(
                          t(context, 'continueCooking'),
                          style: mono(11, color: KitchenColors.teal),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, size: 17),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (feature != null) _Featured(recipe: feature),
        if (feature == null)
          EmptyPaper(
            title: t(context, 'noDishVersion'),
            body: t(context, 'noDishVersionBody'),
            action: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              ),
              child: Text(t(context, 'profile')),
            ),
          ),
        if (quick.isNotEmpty) ...[
          const SizedBox(height: 30),
          SectionHeading(
            title: t(context, 'quickTitle'),
            subtitle: t(context, 'quickSubtitle'),
          ),
          RecipeGrid(
            recipes: quick,
            onOpen: (recipe) => openRecipe(context, recipe),
          ),
        ],
        if (comfort.isNotEmpty) ...[
          const SizedBox(height: 30),
          SectionHeading(
            title: t(context, 'comfortTitle'),
            subtitle: t(context, 'comfortSubtitle'),
          ),
          RecipeGrid(
            recipes: comfort,
            onOpen: (recipe) => openRecipe(context, recipe),
          ),
        ],
        const SizedBox(height: 26),
        OutlinedButton.icon(
          onPressed: discover,
          icon: const Icon(Icons.search, size: 18),
          label: Text(t(context, 'browse')),
        ),
        const SizedBox(height: 22),
        Center(child: Text(t(context, 'tagline'), style: hand(23))),
        Center(
          child: TextButton(
            onPressed: () => openHelp(context, 'matching'),
            child: Text(t(context, 'profileHelp')),
          ),
        ),
      ],
    );
  }
}

class _Featured extends StatelessWidget {
  final Recipe recipe;
  const _Featured({required this.recipe});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final dish = state.repository.dishes[recipe.dishId]!;
    return Material(
      color: KitchenColors.card,
      child: InkWell(
        onTap: () => openRecipe(context, recipe),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: KitchenColors.line),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  RecipeArt(dish: dish, height: 205),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      color: KitchenColors.card,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        t(context, 'featured'),
                        style: mono(9, color: KitchenColors.teal, spacing: .7),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      tooltip: t(
                        context,
                        state.saved.containsKey(recipe.id) ? 'saved' : 'save',
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: KitchenColors.card.withValues(
                          alpha: .9,
                        ),
                      ),
                      onPressed: () => state.toggleSaved(recipe.id),
                      icon: Icon(
                        state.saved.containsKey(recipe.id)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: KitchenColors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(textFor(context, dish.caption), style: hand(22)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textFor(context, dish.name).toLowerCase(),
                      style: serif(31, italic: true),
                    ),
                    const SizedBox(height: 8),
                    Text(textFor(context, recipe.description), style: mono(11)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(
                          t(context, 'minutes', {'count': recipe.timeMinutes}),
                          style: mono(10, color: KitchenColors.teal),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          t(context, 'kcal', {
                            'count': recipe.calories.round(),
                          }),
                          style: mono(10),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: KitchenColors.teal,
                        ),
                      ],
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
