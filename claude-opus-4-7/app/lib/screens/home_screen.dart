import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/corpus.dart';
import '../data/history_store.dart';
import '../data/profile_store.dart';
import '../l10n/strings.dart';
import '../matching/matcher.dart';
import '../matching/ranker.dart';
import '../models/dish.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';
import '../widgets/polaroid_card.dart';
import '../widgets/striped_placeholder.dart';
import 'dish_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final corpus = context.watch<Corpus>();
    final profile = context.watch<ProfileStore>().profile;
    final history = context.watch<HistoryStore>();
    final l = L10n.of(context);

    final matcher = Matcher(
      ontology: corpus.ontology,
      dict: corpus.ingredientDict,
    );
    final ranker = Ranker(lastCookedAt: history.lastCookedAt);

    // For each dish, pick best variant given profile, ignore dishes with none.
    final dishHero = <(Dish, Recipe)>[];
    for (final dish in corpus.dishes) {
      final variants = corpus.variantsOf(dish.id);
      final visible = matcher.filter(variants, profile).toList();
      final best = ranker.pickBest(visible, profile);
      if (best != null) dishHero.add((dish, best));
    }

    final today = DateFormat('EEE · d MMM yyyy', l.lang).format(DateTime.now());

    // Featured = top-scoring across all visible recipes today.
    (Dish, Recipe)? featured;
    if (dishHero.isNotEmpty) {
      int bestScore = -0x7fffffff;
      for (final pair in dishHero) {
        final s = ranker.score(pair.$2, profile);
        if (s > bestScore) {
          bestScore = s;
          featured = pair;
        }
      }
    }

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Masthead(
                  title: 'morphcook',
                  edition: profile.name.isEmpty
                      ? l.t('app.tagline')
                      : l.tParams('home.hello',
                          {'name': profile.name.toLowerCase()}),
                  leftMeta: today,
                  rightMeta: profile.lang.toUpperCase(),
                ),
              ),
              if (featured != null)
                SliverToBoxAdapter(
                  child: _Featured(
                    dish: featured.$1,
                    recipe: featured.$2,
                    lang: l.lang,
                  ),
                ),
              SliverToBoxAdapter(
                child:
                    SectionHeader(label: l.t('home.cuisine'), caption: 'a tour'),
              ),
              ..._cuisineSections(context, dishHero, l),
              SliverToBoxAdapter(
                child: SectionHeader(
                    label: l.t('home.quick'), caption: 'in under 30'),
              ),
              SliverToBoxAdapter(
                child: _HorizontalDishRow(
                  pairs: dishHero
                      .where((p) => p.$2.timeMinutes <= 30)
                      .toList(),
                  lang: l.lang,
                ),
              ),
              SliverToBoxAdapter(
                child: SectionHeader(
                    label: l.t('home.weekend'),
                    caption: 'take your time'),
              ),
              SliverToBoxAdapter(
                child: _HorizontalDishRow(
                  pairs: dishHero
                      .where((p) =>
                          p.$2.effort != 'easy' && p.$2.timeMinutes >= 40)
                      .toList(),
                  lang: l.lang,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
              const SliverToBoxAdapter(child: AmpersandDivider()),
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _cuisineSections(BuildContext context,
      List<(Dish, Recipe)> dishHero, L10n l) sync* {
    final corpus = context.read<Corpus>();
    for (final cu in corpus.cuisines) {
      final inCuisine = dishHero
          .where((p) => cu.dishIds.contains(p.$1.id))
          .toList();
      if (inCuisine.isEmpty) continue;
      yield SliverToBoxAdapter(
        child: SectionHeader(
          label: cu.name[l.lang] ?? cu.name['en'] ?? cu.id,
          caption: '${inCuisine.length}',
        ),
      );
      yield SliverToBoxAdapter(
        child: _HorizontalDishRow(pairs: inCuisine, lang: l.lang),
      );
    }
  }
}

class _Featured extends StatelessWidget {
  final Dish dish;
  final Recipe recipe;
  final String lang;
  const _Featured(
      {required this.dish, required this.recipe, required this.lang});

  @override
  Widget build(BuildContext context) {
    final color = MorphColors.parseHex(dish.stripeColor);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DishDetailScreen(
            dishId: dish.id,
            initialRecipeId: recipe.id,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('— ${L10n(lang).t('home.featured').toLowerCase()} —',
                style: MorphType.smallCaps(size: 11)),
            const SizedBox(height: 10),
            StripedPlaceholder(
              stripeColor: color,
              caption: dish.capCaption.get(lang),
              height: 230,
              radius: BorderRadius.zero,
            ),
            const SizedBox(height: 14),
            Text(dish.name.get(lang).toLowerCase(),
                style: MorphType.display(size: 38)),
            const SizedBox(height: 6),
            Text(dish.heroText.get(lang),
                style: MorphType.body(size: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _MetaPill(
                    label:
                        '${recipe.timeMinutes} ${L10n(lang).t('dish.minutes')}'),
                _MetaPill(
                    label:
                        '${recipe.caloriesPerServing} ${L10n(lang).t('dish.kcal')}'),
                _MetaPill(label: recipe.effort),
                _MetaPill(label: recipe.variantTag.get(lang)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  const _MetaPill({required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: MorphColors.paper,
        border: Border.all(color: MorphColors.inkMuted, width: 0.6),
      ),
      child: Text(label.toUpperCase(),
          style: MorphType.smallCaps(size: 10)),
    );
  }
}

class _HorizontalDishRow extends StatelessWidget {
  final List<(Dish, Recipe)> pairs;
  final String lang;
  const _HorizontalDishRow({required this.pairs, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (pairs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: Text(L10n(lang).t('app.empty'),
            style: MorphType.body(size: 14, color: MorphColors.inkMuted)),
      );
    }
    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: pairs.length,
        itemBuilder: (ctx, i) {
          final dish = pairs[i].$1;
          final recipe = pairs[i].$2;
          final color = MorphColors.parseHex(dish.stripeColor);
          return PolaroidCard(
            width: 190,
            rotation: rotationFor(dish.id),
            image: StripedPlaceholder(
              stripeColor: color,
              caption: dish.capCaption.get(lang),
              dense: true,
            ),
            title: dish.name.get(lang),
            subtitle:
                '${recipe.variantTag.get(lang)} · ${recipe.timeMinutes} min',
            handwrittenNote: recipe.effort == 'easy' ? 'quick!' : null,
            onTap: () => Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => DishDetailScreen(
                  dishId: dish.id,
                  initialRecipeId: recipe.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
