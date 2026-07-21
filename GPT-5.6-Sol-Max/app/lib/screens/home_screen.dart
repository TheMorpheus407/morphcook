import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/localized_text.dart';
import '../models/recipe.dart';
import '../state/app_controller.dart';
import '../widgets/masthead.dart';
import '../widgets/recipe_card.dart';
import '../widgets/states.dart';
import '../widgets/stripe_placeholder.dart';
import 'recipe_detail_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final language = app.language;
    final recipes = app.visibleRecipes.take(50).toList();
    if (recipes.isEmpty) {
      return Column(
        children: [
          MorphMasthead(
            language: language,
            onSettings: () => _openSettings(context),
          ),
          Expanded(
            child: EmptyPageNote(
              icon: Icons.menu_book_outlined,
              title: Copy.text('no_recipes', language),
              action: OutlinedButton(
                onPressed: () => _openSettings(context),
                child: Text(
                  Copy.text('adjust_profile', language).toUpperCase(),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final featured = recipes.first;
    final featuredDish = app.content.dishById(featured.dishId)!;
    final weeknight = recipes
        .skip(1)
        .where((item) => item.timeMinutes <= 30)
        .take(4)
        .toList();
    final slow = recipes
        .skip(1)
        .where(
          (item) =>
              !weeknight.any((quick) => quick.id == item.id) &&
              (item.timeMinutes > 25 || item.effort != 'easy'),
        )
        .take(4)
        .toList();
    return CustomScrollView(
      key: const PageStorageKey('home-scroll'),
      slivers: [
        SliverToBoxAdapter(
          child: MorphMasthead(
            language: language,
            onSettings: () => _openSettings(context),
          ),
        ),
        SliverToBoxAdapter(
          child: EditorialSectionTitle(
            title: Copy.text('featured', language),
            note: Copy.text('for_you', language),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FeaturedStory(
              recipe: featured,
              language: language,
              color: Color(featuredDish.stripeColor),
              caption: featuredDish.caption.value(language),
              saved: app.savedIds.contains(featured.id),
              effortLabel: app.ontology.label(featured.effort, language),
              onSave: () => app.toggleSaved(featured.id),
              onTap: () =>
                  openRecipeDetail(context, featured.dishId, featured.id),
            ),
          ),
        ),
        if (weeknight.isNotEmpty)
          SliverToBoxAdapter(
            child: EditorialSectionTitle(
              title: Copy.text('weeknight', language),
            ),
          ),
        if (weeknight.isNotEmpty) _grid(context, app, weeknight),
        if (slow.isNotEmpty)
          SliverToBoxAdapter(
            child: EditorialSectionTitle(
              title: Copy.text('weekend', language),
              note: language == 'de' ? 'mit zeit' : 'take your time',
            ),
          ),
        if (slow.isNotEmpty) _grid(context, app, slow),
        const SliverToBoxAdapter(child: SizedBox(height: 34)),
      ],
    );
  }

  Widget _grid(BuildContext context, AppController app, List<Recipe> recipes) =>
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
        sliver: SliverGrid.builder(
          itemCount: recipes.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 13,
            childAspectRatio: .70,
          ),
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            final dish = app.content.dishById(recipe.dishId)!;
            return RecipeCard(
              recipe: recipe,
              dish: dish,
              language: app.language,
              dietLabel: app.ontology.label(recipe.diet, app.language),
              compact: true,
              rotation: index.isEven ? -.012 : .014,
              saved: app.savedIds.contains(recipe.id),
              onSave: () => app.toggleSaved(recipe.id),
              onTap: () => openRecipeDetail(context, recipe.dishId, recipe.id),
            );
          },
        ),
      );

  void _openSettings(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}

class _FeaturedStory extends StatelessWidget {
  const _FeaturedStory({
    required this.recipe,
    required this.language,
    required this.color,
    required this.caption,
    required this.saved,
    required this.effortLabel,
    required this.onSave,
    required this.onTap,
  });

  final Recipe recipe;
  final String language;
  final Color color;
  final String caption;
  final bool saved;
  final String effortLabel;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'recipe-art-${recipe.id}',
            child: StripePlaceholder(
              color: color,
              caption: caption,
              height: 224,
            ),
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title.value(language),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      recipe.subtitle.value(language),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      children: [
                        CardMeta(
                          icon: Icons.schedule,
                          text: '${recipe.timeMinutes} min',
                        ),
                        CardMeta(
                          icon: Icons.local_fire_department_outlined,
                          text: '${recipe.nutrition.calories} kcal',
                        ),
                        CardMeta(icon: Icons.restaurant, text: effortLabel),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSave,
                icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                color: saved ? BrandColors.coral : BrandColors.ink,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
