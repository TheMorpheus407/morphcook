import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/palette.dart';
import '../../core/model/dish.dart';
import '../../core/model/profile.dart';
import '../../core/model/recipe.dart';
import '../../navigation.dart';
import '../../state/app_state.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper.dart';
import '../../widgets/polaroid_card.dart';
import '../../widgets/stripe_plate.dart';
import '../search/search_screen.dart';

/// The home feed: newspaper masthead, tonight's lead story, quick-tonight
/// grid, ranked "for your table" grid, cuisine shelves, kitchen binder.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Cuisine shelves load their partitions in the background after the
    // first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppState>();
      for (final partition in appState.corpus.manifest.partitions) {
        if (partition.loadsAtLaunch) continue;
        await appState.corpus.ensurePartition(partition.id);
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final corpus = appState.corpus;
    final matcher = appState.matcher;
    final profile = appState.profile;

    // Best visible variant per dish (null when the partition isn't loaded
    // yet or nothing is visible).
    Recipe? bestOf(Dish dish) => matcher.pickBest(
          corpus.loadedRecipesOfPartition(dish.partitionId)
              .where((r) => r.dishId == dish.id)
              .toList(),
          profile,
        );

    final dishes = corpus.dishes;
    final ranked = matcher.rank(
      [
        for (final dish in dishes)
          for (final r in corpus
              .loadedRecipesOfPartition(dish.partitionId)
              .where((r) => r.dishId == dish.id))
            r,
      ],
      profile,
      lastCookedByRecipe: appState.lastCookedByRecipe,
    );
    final rankedDishIds = ranked.map((r) => r.dishId).toSet().toList();

    Dish? featured;
    if (ranked.isNotEmpty) {
      featured = corpus.dishById(ranked.first.dishId);
    }
    final quickDishes = <Dish>[];
    final tableDishes = <Dish>[];
    for (final dish in dishes) {
      final best = bestOf(dish);
      if (best == null) continue;
      if (best.timeMinutes <= 30 && quickDishes.length < 8) quickDishes.add(dish);
    }
    for (final id in rankedDishIds) {
      final dish = corpus.dishById(id);
      if (dish != null && dish != featured && tableDishes.length < 12) {
        tableDishes.add(dish);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Masthead(s: s),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: _SearchBox(s: s),
        ),
        if (featured != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel(s.homeLeadStory, color: Palette.coral),
          ),
          _FeatureCard(dish: featured, recipe: bestOf(featured), s: s),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(s.homeQuickTonight),
        ),
        if (quickDishes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: EmptyState(title: s.homeNoResults),
          )
        else
          _PolaroidGrid(dishes: quickDishes, bestOf: bestOf, s: s, profile: profile),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(s.homeForYourTable),
        ),
        _PolaroidGrid(dishes: tableDishes, bestOf: bestOf, s: s, profile: profile),
        for (final partition in corpus.manifest.partitions.where((p) => p.type == 'cuisine')) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel(s.homeCuisineShelf.replaceAll('{cuisine}', partition.id.replaceFirst('cuisine-', ''))),
          ),
          _CuisineShelf(partitionId: partition.id, bestOf: bestOf, s: s),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SectionLabel(s.homeKitchenBinder, color: Palette.inkFaint),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final dish in dishes)
                GestureDetector(
                  onTap: () => openDish(context, dish.id),
                  child: Text(
                    dish.name.resolve(s.lang),
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontStyle: FontStyle.italic,
                      fontSize: 16,
                      color: Palette.teal,
                      decoration: TextDecoration.underline,
                      decorationColor: Palette.line,
                      decorationThickness: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  final Strings s;

  const _SearchBox({required this.s});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Palette.paperDeep.withValues(alpha: 0.4),
            border: Border.all(color: Palette.ink, width: 1.4),
          ),
          child: Row(
            children: [
              Expanded(child: HandNote(s.homeSearchHint, size: 19, color: Palette.inkFaint)),
              Icon(Icons.search, size: 16, color: Palette.inkSoft),
            ],
          ),
        ),
      );
}

class _FeatureCard extends StatelessWidget {
  final Dish dish;
  final Recipe? recipe;
  final Strings s;

  const _FeatureCard({required this.dish, required this.recipe, required this.s});

  @override
  Widget build(BuildContext context) {
    final recipe = this.recipe;
    return GestureDetector(
        onTap: () => openDish(context, dish.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StripedPlate(
                color: _color(dish.stripeColor),
                caption: dish.capCaption.resolve(s.lang),
                height: 230,
                tiltDeg: -0.6,
              ),
              const SizedBox(height: 12),
              Text(dish.name.resolve(s.lang), style: TextStyle(
                fontFamily: 'Playfair Display',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                fontSize: 32,
                color: Palette.ink,
              )),
              const SizedBox(height: 4),
              Text(dish.hero.resolve(s.lang), style: TextStyle(
                fontFamily: 'Playfair Display',
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: Palette.inkSoft,
              )),
              const SizedBox(height: 8),
              if (recipe != null)
                Text(
                  '${s.homeWaysToMake.replaceAll('{n}', dish.variantIds.length.toString())} · ${s.effortLabel(recipe.effort)} · ${recipe.timeMinutes} ${s.commonMin} · ~${recipe.caloriesPerServing} ${s.commonKcal}',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 10.5,
                    color: Palette.inkFaint,
                  ),
                ),
            ],
          ),
        ),
      );
  }
}

class _PolaroidGrid extends StatelessWidget {
  final List<Dish> dishes;
  final Recipe? Function(Dish) bestOf;
  final Strings s;
  final UserProfile profile;

  const _PolaroidGrid({required this.dishes, required this.bestOf, required this.s, required this.profile});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = (width / 170).floor().clamp(2, 4);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: dishes.length,
              itemBuilder: (context, index) {
                final dish = dishes[index];
                final best = bestOf(dish);
                return PolaroidCard(
                  index: index,
                  stripeColor: _color(dish.stripeColor),
                  name: dish.name.resolve(s.lang),
                  subtitle: best?.subtitle.resolve(s.lang) ?? dish.hero.resolve(s.lang),
                  meta: best != null
                      ? '${best.timeMinutes} ${s.commonMin} · ~${best.caloriesPerServing} ${s.commonKcal} · ${s.effortLabel(best.effort)}'
                      : '',
                  tag: profile.showVariantTags && best != null ? s.dietLabel(best.diet) : null,
                  tagColor: _color(dish.stripeColor),
                  onTap: () => openDish(context, dish.id),
                );
              },
            );
          },
        ),
      );
}

class _CuisineShelf extends StatelessWidget {
  final String partitionId;
  final Recipe? Function(Dish) bestOf;
  final Strings s;

  const _CuisineShelf({required this.partitionId, required this.bestOf, required this.s});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dishes = appState.corpus.dishesInPartition(partitionId);
    if (dishes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: dishes.length,
        itemBuilder: (context, index) {
          final dish = dishes[index];
          final best = bestOf(dish);
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 14),
            child: PolaroidCard(
              index: index,
              stripeColor: _color(dish.stripeColor),
              name: dish.name.resolve(s.lang),
              subtitle: best?.subtitle.resolve(s.lang) ?? dish.hero.resolve(s.lang),
              meta: best != null ? '${best.timeMinutes} ${s.commonMin}' : '',
              onTap: () => openDish(context, dish.id),
            ),
          );
        },
      ),
    );
  }
}

Color _color(String hex) {
  final digits = hex.replaceFirst('#', '');
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return Palette.coral;
  return Color(digits.length == 6 ? 0xFF000000 | value : value);
}
