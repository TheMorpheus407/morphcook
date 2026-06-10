import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/context_ext.dart';
import '../../logic/ranking.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/recipe_card.dart';

/// The kitchen: a newspaper-style masthead, one featured dish chosen for the
/// moment, then sections by time of day, then the whole shelf. Filters and
/// ranking respond live to the profile and cooking history.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    return ListenableBuilder(
      listenable: Listenable.merge([scope.services.profile, scope.services.history]),
      builder: (context, _) {
        final profile = scope.services.profile.profile;
        final matcher = scope.matcherFor(profile);
        final ranker = scope.rankerFor(profile);

        // Best visible variant per dish.
        final picks = <Dish, Recipe>{};
        for (final dish in scope.corpus.dishes) {
          final variants = scope.corpus.variantsOf(dish.id);
          final visible = variants.where(matcher.isVisible).toList();
          final best = ranker.bestVariant(visible);
          if (best != null) picks[dish] = best;
        }

        final ranked = picks.entries.toList()
          ..sort((a, b) => ranker.score(b.value).compareTo(ranker.score(a.value)));

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Masthead()),
            if (ranked.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: HandNote(context.tr('home.nothing_matches'), size: 22),
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: _Featured(dish: ranked.first.key, recipe: ranked.first.value),
              ),
              ..._mealSection(context, 'breakfast', 'home.sections.breakfast', picks, ranker),
              ..._mealSection(context, 'lunch', 'home.sections.lunch', picks, ranker),
              ..._mealSection(context, 'dinner', 'home.sections.dinner', picks, ranker),
              SliverToBoxAdapter(child: _SectionHeader(context.tr('home.all_dishes'))),
              _Grid(entries: ranked),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _mealSection(
    BuildContext context,
    String mealType,
    String titleKey,
    Map<Dish, Recipe> picks,
    Ranker ranker,
  ) {
    final entries = picks.entries.where((e) => e.value.mealType == mealType).toList()
      ..sort((a, b) => ranker.score(b.value).compareTo(ranker.score(a.value)));
    if (entries.isEmpty) return const [];
    return [
      SliverToBoxAdapter(child: _SectionHeader(context.tr(titleKey))),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, i) => SizedBox(
              width: 200,
              child: RecipeCard(
                recipe: entries[i].value,
                dish: entries[i].key,
                rotation: i.isEven ? -0.015 : 0.015,
              ),
            ),
            separatorBuilder: (_, _) => const SizedBox(width: 14),
          ),
        ),
      ),
    ];
  }
}

class _Masthead extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final date = DateFormat.yMMMMEEEEd(context.lang.code).format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DashedRule(withAmpersand: true),
          const SizedBox(height: 8),
          Text(
            context.tr('app.name').toLowerCase(),
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 44,
              color: AppColors.ink,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr('app.tagline'),
            style: const TextStyle(
                fontFamily: Fonts.hand, fontSize: 20, color: AppColors.clay),
          ),
          const SizedBox(height: 8),
          Text(date.toLowerCase(),
              style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          DashedRule(),
        ],
      ),
    );
  }
}

class _Featured extends StatelessWidget {
  const _Featured({required this.dish, required this.recipe});
  final Dish dish;
  final Recipe recipe;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(context.tr('home.featured'), color: AppColors.terracotta),
          const SizedBox(height: 8),
          RecipeCard(recipe: recipe, dish: dish, rotation: -0.008),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: Fonts.display,
                  fontStyle: FontStyle.italic,
                  fontSize: 26,
                  color: AppColors.ink)),
          const SizedBox(width: 12),
          const Expanded(child: DashedRule()),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.entries});
  final List<MapEntry<Dish, Recipe>> entries;
  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 18,
          crossAxisSpacing: 14,
          childAspectRatio: 0.66,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) => RecipeCard(
            recipe: entries[i].value,
            dish: entries[i].key,
            rotation: i.isEven ? -0.02 : 0.018,
          ),
          childCount: entries.length,
        ),
      ),
    );
  }
}
