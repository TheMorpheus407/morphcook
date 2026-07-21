import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/dish.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';
import '../widgets/striped_placeholder.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.profile,
    required this.recipes,
    required this.outsideTargetRecipes,
    required this.dishesById,
    required this.isSaved,
    required this.onOpenRecipe,
    required this.onToggleSaved,
    required this.onBrowseAll,
    required this.onAdjustProfile,
    required this.onOpenShopping,
    super.key,
    this.shoppingCount = 0,
    this.onRefresh,
  });

  final UserProfile profile;
  final List<Recipe> recipes;
  final List<Recipe> outsideTargetRecipes;
  final Map<String, Dish> dishesById;
  final bool Function(String recipeId) isSaved;
  final ValueChanged<Recipe> onOpenRecipe;
  final Future<void> Function(Recipe recipe) onToggleSaved;
  final VoidCallback onBrowseAll;
  final VoidCallback onAdjustProfile;
  final VoidCallback onOpenShopping;
  final int shoppingCount;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final featured = recipes.isEmpty ? null : recipes.first;
    final quick = recipes
        .skip(1)
        .where((recipe) => recipe.timeMinutes <= 35)
        .take(6)
        .toList();
    final featuredAndQuickIds = <String>{
      if (featured != null) featured.id,
      for (final recipe in quick) recipe.id,
    };
    final rediscover = recipes
        .where((recipe) => !featuredAndQuickIds.contains(recipe.id))
        .take(6)
        .toList();
    final content = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: NewspaperMasthead(
            subtitle: strings.format('home.greeting', {
              'name': profile.name.isEmpty
                  ? strings('common.you')
                  : profile.name,
            }),
            trailing: _ShoppingButton(
              count: shoppingCount,
              onPressed: onOpenShopping,
            ),
          ),
        ),
        if (featured != null)
          SliverToBoxAdapter(
            child: ResponsivePaperPage(
              grain: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    title: strings('home.featured'),
                    kicker: _dayLine(profile.languageCode),
                  ),
                  _FeaturedCard(
                    recipe: featured,
                    dish: dishesById[featured.dishId],
                    language: profile.languageCode,
                    saved: isSaved(featured.id),
                    onTap: () => onOpenRecipe(featured),
                    onSave: () => onToggleSaved(featured),
                  ),
                ],
              ),
            ),
          ),
        if (quick.isNotEmpty)
          SliverToBoxAdapter(
            child: ResponsivePaperPage(
              grain: false,
              child: SectionHeading(
                title: strings('home.weeknight'),
                kicker: strings('home.weeknightKicker'),
                trailing: TextButton(
                  onPressed: onBrowseAll,
                  child: Text(strings('home.browseAll')),
                ),
              ),
            ),
          ),
        if (quick.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.crossAxisExtent >= 760 ? 3 : 2;
                final textScale =
                    MediaQuery.textScalerOf(context).scale(14) / 14;
                final baseAspect = count == 3 ? .82 : .69;
                return SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _RecipeCard(
                      recipe: quick[index],
                      dish: dishesById[quick[index].dishId],
                      language: profile.languageCode,
                      saved: isSaved(quick[index].id),
                      angle: index.isEven ? -.016 : .014,
                      onOpen: () => onOpenRecipe(quick[index]),
                      onSave: () => onToggleSaved(quick[index]),
                    ),
                    childCount: quick.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 18,
                    childAspectRatio:
                        baseAspect / (1 + (textScale.clamp(1, 2) - 1) * .28),
                  ),
                );
              },
            ),
          ),
        if (rediscover.isNotEmpty)
          SliverToBoxAdapter(
            child: ResponsivePaperPage(
              grain: false,
              child: SectionHeading(
                title: strings('home.rediscover'),
                kicker: strings('home.rediscoverKicker'),
              ),
            ),
          ),
        if (rediscover.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 255,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                scrollDirection: Axis.horizontal,
                itemCount: rediscover.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) => SizedBox(
                  width: 190,
                  child: _RecipeCard(
                    recipe: rediscover[index],
                    dish: dishesById[rediscover[index].dishId],
                    language: profile.languageCode,
                    saved: isSaved(rediscover[index].id),
                    angle: index.isEven ? .012 : -.012,
                    compact: true,
                    onOpen: () => onOpenRecipe(rediscover[index]),
                    onSave: () => onToggleSaved(rediscover[index]),
                  ),
                ),
              ),
            ),
          ),
        if (outsideTargetRecipes.isNotEmpty)
          SliverToBoxAdapter(
            child: ResponsivePaperPage(
              grain: false,
              child: SectionHeading(
                title: strings('home.outsideTarget'),
                kicker: strings('home.outsideTargetKicker'),
              ),
            ),
          ),
        if (outsideTargetRecipes.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 255,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
                scrollDirection: Axis.horizontal,
                itemCount: outsideTargetRecipes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final recipe = outsideTargetRecipes[index];
                  return SizedBox(
                    width: 190,
                    child: _RecipeCard(
                      recipe: recipe,
                      dish: dishesById[recipe.dishId],
                      language: profile.languageCode,
                      saved: isSaved(recipe.id),
                      angle: index.isEven ? -.012 : .012,
                      compact: true,
                      onOpen: () => onOpenRecipe(recipe),
                    ),
                  );
                },
              ),
            ),
          ),
        if (recipes.isEmpty && outsideTargetRecipes.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: MorphEmptyState(
              icon: Icons.tune_rounded,
              title: strings('home.noMatchesTitle'),
              message: strings('home.noMatchesBody'),
              action: onAdjustProfile,
              actionLabel: strings('home.adjustProfile'),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
    return PaperSurface(
      child: SafeArea(
        bottom: false,
        child: onRefresh == null
            ? content
            : RefreshIndicator(onRefresh: onRefresh!, child: content),
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.recipe,
    required this.dish,
    required this.language,
    required this.saved,
    required this.onTap,
    required this.onSave,
  });

  final Recipe recipe;
  final Dish? dish;
  final String language;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(dish?.stripeColor, context.morph.coral);
    return Semantics(
      button: true,
      label: recipe.name.resolve(language),
      child: Material(
        color: context.morph.paper,
        elevation: 2,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onTap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 650;
              final image = Hero(
                tag: 'dish-${recipe.dishId}',
                child: StripedPlaceholder(
                  caption:
                      dish?.caption.resolve(language) ??
                      recipe.name.resolve(language),
                  color: color,
                  height: wide ? 270 : 225,
                ),
              );
              final copy = Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TapeLabel(
                      text:
                          dish?.heroText.resolve(language) ??
                          context.strings('home.todayPick'),
                      angle: .018,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      recipe.name.resolve(language),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.description.resolve(language),
                      maxLines: wide ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Text(
                          context.strings.format('common.recipeMeta', {
                            'minutes': recipe.timeMinutes,
                            'calories': recipe.caloriesPerServing,
                          }).toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: onSave,
                          tooltip: saved
                              ? context.strings('common.removeFromCookbook')
                              : context.strings('common.saveToCookbook'),
                          icon: Icon(
                            saved ? Icons.bookmark : Icons.bookmark_border,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
              if (wide) {
                return SizedBox(
                  height: 310,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: image),
                      Expanded(flex: 5, child: copy),
                    ],
                  ),
                );
              }
              return Column(children: [image, copy]);
            },
          ),
        ),
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.dish,
    required this.language,
    required this.saved,
    required this.onOpen,
    required this.angle,
    this.compact = false,
    this.onSave,
  });

  final Recipe recipe;
  final Dish? dish;
  final String language;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback? onSave;
  final double angle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PolaroidRecipeCard(
      title: recipe.name.resolve(language),
      caption:
          dish?.caption.resolve(language) ??
          context.strings.option('diet', recipe.diet),
      color: _parseColor(dish?.stripeColor, context.morph.teal),
      meta: context.strings.format('common.recipeMeta', {
        'minutes': recipe.timeMinutes,
        'calories': recipe.caloriesPerServing,
      }),
      angle: angle,
      compact: compact,
      saved: saved,
      onTap: onOpen,
      onSave: onSave,
    );
  }
}

class _ShoppingButton extends StatelessWidget {
  const _ShoppingButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? '99+' : '$count'),
      child: IconButton(
        onPressed: onPressed,
        tooltip: context.strings('shopping.title'),
        icon: const Icon(Icons.shopping_basket_outlined),
      ),
    );
  }
}

String _dayLine(String language) {
  return DateFormat.EEEE(language).format(DateTime.now());
}

Color _parseColor(String? value, Color fallback) {
  if (value == null) return fallback;
  final cleaned = value.replaceFirst('#', '');
  final parsed = int.tryParse(cleaned, radix: 16);
  if (parsed == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | parsed : parsed);
}
