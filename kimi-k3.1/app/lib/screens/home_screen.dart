import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../services/recipe_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';
import '../widgets/recipe_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenDish,
    required this.onSearch,
    required this.onSettings,
    required this.onFaq,
  });
  final void Function(Dish dish, String? recipeId) onOpenDish;
  final VoidCallback onSearch;
  final VoidCallback onSettings;
  final VoidCallback onFaq;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final choices = app.repository.homeChoices(
      app.profile,
      now: app.clock(),
      lastCooked: app.lastCooked,
    );
    final hour = app.clock().hour;
    final greeting = hour < 12
        ? 'good_morning'
        : hour < 18
        ? 'good_afternoon'
        : 'good_evening';
    return Scaffold(
      body: Paper(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const PageStorageKey('home-feed'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(21, 13, 15, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'morphcook.',
                              style: Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(fontSize: 36),
                            ),
                          ),
                          IconButton(
                            onPressed: onSearch,
                            icon: const Icon(Icons.search),
                            tooltip: context.l10n.t('search'),
                          ),
                          IconButton(
                            onPressed: onSettings,
                            icon: const Icon(Icons.tune),
                            tooltip: context.l10n.t('settings_title'),
                          ),
                        ],
                      ),
                      const DashedRule(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.t('home_kicker'),
                              style: Theme.of(
                                context,
                              ).textTheme.labelMedium?.copyWith(fontSize: 8),
                            ),
                          ),
                          Text(
                            DateFormat(
                              'd MMM y',
                              context.lang,
                            ).format(app.clock()),
                            style: Theme.of(
                              context,
                            ).textTheme.labelMedium?.copyWith(fontSize: 8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Text(
                        app.profile.name.isEmpty
                            ? context.l10n.t('home_greeting_plain', {
                                'greeting': context.l10n.t(greeting),
                              })
                            : context.l10n.t('home_greeting', {
                                'greeting': context.l10n.t(greeting),
                                'name': app.profile.name,
                              }),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.handwritten
                            .copyWith(color: AppColors.coral, fontSize: 29),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (choices.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: context.l10n.t('home_empty_title'),
                    body: context.l10n.t('home_empty_body'),
                    action: OutlinedButton(
                      onPressed: onSettings,
                      child: Text(context.l10n.t('open_settings')),
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 23),
                  sliver: SliverToBoxAdapter(
                    child: _FeaturedChoice(
                      choice: choices.first,
                      onTap: () => onOpenDish(
                        choices.first.dish,
                        choices.first.recipe.id,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(22, 34, 22, 18),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeading(
                      context.l10n.t('fresh_from_kitchen'),
                      kicker: context.l10n.t('quiet_weeknight'),
                      trailing: TextButton(
                        onPressed: onFaq,
                        child: Text(context.l10n.t('why_recipes')),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width > 680
                          ? 3
                          : 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 21,
                      childAspectRatio: MediaQuery.sizeOf(context).width > 680
                          ? 0.82
                          : 0.69,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final choice = choices[index + 1];
                      return RecipeCard(
                        dish: choice.dish,
                        recipe: choice.recipe,
                        compact: true,
                        turns: index.isEven ? -0.005 : 0.006,
                        showDiet: app.profile.showVariantTags,
                        onTap: () => onOpenDish(choice.dish, choice.recipe.id),
                      );
                    }, childCount: choices.length - 1),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 35, 24, 28),
                    child: Column(
                      children: [
                        const DashedRule(),
                        Text(
                          context.l10n.t('tagline'),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.handwritten,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.t('offline_credit'),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedChoice extends StatelessWidget {
  const _FeaturedChoice({required this.choice, required this.onTap});
  final DishChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final dish = choice.dish;
    final recipe = choice.recipe;
    return Polaroid(
      turns: -0.004,
      padding: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              DishArtwork(
                caption: dish.capCaption.of(locale),
                stripeColor: dish.stripeColor,
                height: 224,
              ),
              Positioned(
                top: 18,
                right: 10,
                child: Transform.rotate(
                  angle: 0.08,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    color: AppColors.coral,
                    child: Text(
                      context.l10n.t('featured').toUpperCase(),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.paperLight,
                        fontSize: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 15, 7, 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title.of(locale),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  dish.heroText.of(locale),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${recipe.timeMinutes} min  ·  ${recipe.caloriesPerServing} kcal  ·  ${recipe.effort}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    PrimaryButton(
                      label: context.l10n.t('cook_this'),
                      onPressed: onTap,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
