import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/collections.dart';
import '../../domain/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../cook/cook_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/recipe_card.dart';
import 'category_screen.dart';

/// The front page. A masthead, one featured dish chosen by the ranker, then
/// grid sections. Nothing here is a feed — it is a newspaper that changes when
/// the day does.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final now = state.now;

    final featured = _featuredFor(state);
    final everyday = _sectionFor(state, 'core', limit: 6);
    final categories = state.repository.categories;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Masthead(
              title: 'morphcook',
              left: _greeting(s, state.profile.name, now),
              right: DateFormat.yMMMMEEEEd(s.lang).format(now),
              trailing: IconButton(
                icon: const Icon(Icons.tune),
                tooltip: s.settingsTitle,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(child: HandNote(s.tagline, size: 19)),
            const SizedBox(height: 24),

            if (state.cookProgress != null) ...[
              _ResumeCard(progress: state.cookProgress!),
              const SizedBox(height: 26),
            ],

            if (featured == null)
              _NothingVisible(s: s)
            else ...[
              Eyebrow(_featuredLabel(s, now)),
              const SizedBox(height: 12),
              FeatureCard(dish: featured.$1, recipe: featured.$2),
            ],

            const SizedBox(height: 34),
            SectionHeader(s.homeEveryday),
            const SizedBox(height: 14),
            _DishGrid(entries: everyday),

            const SizedBox(height: 34),
            SectionHeader(s.homeBrowse),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in categories)
                  InkChip(
                    label: s.category(id),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => CategoryScreen(category: id),
                      ),
                    ),
                  ),
              ],
            ),

            for (final partition in state.repository.manifest.partitions)
              if (partition.id != 'core' && partition.id != 'extended') ...[
                const SizedBox(height: 34),
                SectionHeader(partition.label(s.lang)),
                const SizedBox(height: 14),
                _DishGrid(entries: _sectionFor(state, partition.id, limit: 4)),
              ],

            const SizedBox(height: 34),
            SectionHeader(
              s.historyTitle,
              action: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HistoryScreen(),
                  ),
                ),
                child: Text(s.all),
              ),
            ),
            const SizedBox(height: 12),
            _RecentStrip(s: s),

            const SizedBox(height: 36),
            DashedRule(
              label: Text('✻', style: TextStyle(color: colors.inkFaint)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                s.corpusSummary(
                  state.repository.dishes.length,
                  state.repository.manifest.partitions
                      .where((p) => p.id == 'core' || p.id == 'extended')
                      .fold(0, (sum, p) => sum + p.recipeCount),
                  state.repository.manifest.corpusVersion,
                ),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _greeting(S s, String name, DateTime now) {
    if (now.hour < 11) return s.greetingMorning(name);
    if (now.hour >= 17) return s.greetingEvening(name);
    return s.greetingDay(name);
  }

  static String _featuredLabel(S s, DateTime now) =>
      now.hour < 11 ? s.homeFeaturedMorning : s.homeFeatured;

  /// Highest-ranked visible recipe across the resident corpus.
  static (Dish, Recipe)? _featuredFor(AppState state) {
    final candidates = <Recipe>[];
    for (final dish in state.repository.dishes) {
      final pick = state.preferredVariant(dish.id);
      if (pick != null) candidates.add(pick);
    }
    if (candidates.isEmpty) return null;
    final best = AppState.ranker.best(
      candidates,
      state.profile,
      now: state.now,
      lastCookedByRecipe: state.lastCookedByRecipe,
    );
    if (best == null) return null;
    final dish = state.repository.dish(best.dishId);
    return dish == null ? null : (dish, best);
  }

  static List<(Dish, Recipe)> _sectionFor(
    AppState state,
    String partitionId, {
    required int limit,
  }) {
    final out = <(Dish, Recipe)>[];
    for (final dish in state.repository.dishesInPartition(partitionId)) {
      final pick = state.preferredVariant(dish.id);
      if (pick != null) out.add((dish, pick));
      if (out.length >= limit) break;
    }
    return out;
  }
}

class _DishGrid extends StatelessWidget {
  const _DishGrid({required this.entries});

  final List<(Dish, Recipe)> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        S(context.watch<AppState>().lang).homeNothingVisible,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
        childAspectRatio: 0.66,
      ),
      itemBuilder: (context, i) {
        final (dish, recipe) = entries[i];
        return _GridTile(dish: dish, recipe: recipe);
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.dish, required this.recipe});

  final Dish dish;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = S(context.watch<AppState>().lang);
    final theme = Theme.of(context);
    final colors = context.colors;

    return Polaroid(
      seed: dish.id,
      padding: const EdgeInsets.all(8),
      onTap: () => openDish(context, dishId: dish.id, recipeId: recipe.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedPlate(
            color: dish.stripeColor,
            height: 96,
            seed: seedOf(dish.id),
            tight: true,
          ),
          const SizedBox(height: 10),
          Text(
            dish.name(s.lang).toLowerCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              recipe.title(s.lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          DashedRule(color: colors.edge),
          const SizedBox(height: 7),
          Row(
            children: [
              Flexible(
                child: Text(
                  s.minutes(recipe.timeMinutes),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MorphType.numeric(colors.inkFaint, size: 10),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.kcal(recipe.caloriesPerServing),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: MorphType.numeric(colors.inkFaint, size: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.progress});

  final CookProgress progress;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final recipe = state.repository.recipe(progress.recipeId);
    if (recipe == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.secondarySoft,
        border: Border.all(color: colors.secondary),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            color: colors.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(s.homeContinueCooking, color: colors.secondary),
                const SizedBox(height: 4),
                Text(
                  recipe.title(s.lang),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  s.cookStepOf(progress.stepIndex + 1, recipe.steps.length),
                  style: MorphType.numeric(colors.inkSoft, size: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CookScreen(recipeId: recipe.id, resume: true),
              ),
            ),
            child: Text(s.homeResume),
          ),
        ],
      ),
    );
  }
}

class _RecentStrip extends StatelessWidget {
  const _RecentStrip({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recent = state.history.take(4).toList();
    if (recent.isEmpty) {
      return Text(
        s.historyEmptyBody,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      children: [
        for (final entry in recent)
          Builder(
            builder: (context) {
              final recipe = state.repository.recipe(entry.recipeId);
              if (recipe == null) return const SizedBox.shrink();
              return Column(
                children: [
                  RecipeRow(
                    recipe: recipe,
                    subtitleOverride: DateFormat.yMMMd(
                      s.lang,
                    ).format(entry.cookedAt),
                  ),
                  DashedRule(color: context.colors.edge),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _NothingVisible extends StatelessWidget {
  const _NothingVisible({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) => EmptyNote(
    headline: s.homeNothingVisible,
    body: s.settingsAdaptation,
    icon: Icons.filter_alt_off_outlined,
    action: FilledButton(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
      child: Text(s.homeLoosen),
    ),
  );
}
