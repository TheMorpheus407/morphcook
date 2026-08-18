import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../models/dish.dart';
import '../state/app_state.dart';
import '../widgets/dish_tile.dart';
import '../widgets/recipe_card.dart';
import 'dish_detail.dart';
import 'shell.dart';

/// Home feed: newspaper masthead, featured dish, grid sections.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final corpus = context.corpus;
    final store = context.store;
    final ranker = context.ranker;
    final matcher = context.matcher;
    final profile = store.profile;

    final now = DateTime.now();
    final ranked = ranker.rank(
      corpus.allRecipes,
      profile,
      matcher,
      now: now,
      lastCookedAt: store.lastCookedAt,
    );

    final featured = ranked.isNotEmpty ? ranked.first : null;
    final featuredDish =
        featured != null ? corpus.dish(featured.dishId) : null;

    final quick = ranked
        .where((r) => r.timeMinutes <= 30 && r.effort == 'easy')
        .take(6)
        .toList();
    final weekend = ranked
        .where((r) => r.effort == 'medium' || r.effort == 'hard')
        .take(6)
        .toList();
    final forYou = ranked.take(8).toList();

    return PaperBackground(
      seed: 3,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Masthead(
                  subtitle: context.t('mastheadSubtitle'),
                  trailing: IconButton(
                    onPressed: () => openSettings(context),
                    icon: const Icon(Icons.settings_outlined,
                        size: 20, color: MC.inkSoft),
                    tooltip: context.t('tabSettings'),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                child: Text(
                  profile.name.isEmpty
                      ? context.t('homeGreeting')
                      : '${context.t('homeGreeting')}, ${profile.name}',
                  style: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 24,
                    color: MC.coralDeep,
                  ),
                ),
              ),
            ),
            if (featured != null && featuredDish != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: FeaturedHero(
                    dish: featuredDish,
                    recipe: featured,
                    onTap: () => openDish(context, featuredDish.id),
                  ),
                ),
              ),
            if (forYou.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SectionHeader(
                    title: context.t('homeForYou'),
                    annotation: context.t('mastheadSubtitle'),
                  ),
                ),
              ),
            if (forYou.isNotEmpty)
              SliverToBoxAdapter(
                child: DishRow(
                  children: [
                    for (final r in forYou)
                      RecipeCard(
                        recipe: r,
                        rotation: _rotation(r.id),
                        onTap: () => openDish(context, r.dishId),
                      ),
                  ],
                ),
              ),
            if (quick.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SectionHeader(
                    title: context.t('homeQuick'),
                    annotation: '≤ 30 min',
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    mainAxisExtent: 330,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (c, i) => RecipeCard(
                      recipe: quick[i],
                      rotation: _rotation(quick[i].id),
                      onTap: () => openDish(context, quick[i].dishId),
                    ),
                    childCount: quick.length,
                  ),
                ),
              ),
            ],
            if (weekend.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: SectionHeader(
                    title: context.t('homeWeekend'),
                    annotation: context.t('tag.weekend-project'),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: DishRow(
                  children: [
                    for (final r in weekend)
                      RecipeCard(
                        recipe: r,
                        rotation: _rotation(r.id),
                        onTap: () => openDish(context, r.dishId),
                      ),
                  ],
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: SectionHeader(
                  title: context.t('homeDiscover'),
                  annotation: 'italian · asian · middle-eastern',
                ),
              ),
            ),
            ..._cuisineRows(context, corpus),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: DashedOrnament()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _cuisineRows(BuildContext context, dynamic corpus) {
    const partitions = [
      'cuisine-italian',
      'cuisine-asian',
      'cuisine-middle-eastern',
    ];
    return [
      for (final p in partitions)
        SliverToBoxAdapter(
          child: _CuisineSection(
            partitionId: p,
            onOpen: (dish) => openDish(context, dish.id),
          ),
        ),
    ];
  }

  double _rotation(String id) {
    final code = id.codeUnits.fold<int>(0, (a, b) => a + b);
    const rot = [-1.1, 0.8, 1.2, -0.7, 0.4];
    return rot[code % rot.length];
  }
}

void openDish(BuildContext context, String dishId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => DishDetailScreen(dishId: dishId)),
  );
}

/// A cuisine discovery section with lazy partition loading.
class _CuisineSection extends StatefulWidget {
  const _CuisineSection({required this.partitionId, required this.onOpen});

  final String partitionId;
  final void Function(Dish) onOpen;

  @override
  State<_CuisineSection> createState() => _CuisineSectionState();
}

class _CuisineSectionState extends State<_CuisineSection> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final corpus = context.corpus;
    final dishes = corpus.dishesOfPartition(widget.partitionId);

    if (dishes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfNeeded());
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: MC.coral,
              ),
            ),
            const SizedBox(width: 10),
            Text(context.t('loading'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              widget.partitionId.replaceFirst('cuisine-', ''),
              style: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 19,
                color: MC.inkSoft,
              ),
            ),
          ),
          DishRow(
            children: [
              for (final dish in dishes)
                DishTile(
                  dish: dish,
                  variantCount: dish.variantRecipeIds.length,
                  onTap: () => widget.onOpen(dish),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadIfNeeded() async {
    if (_loading) return;
    _loading = true;
    final corpus = context.corpus;
    await corpus.ensureDishesOfPartition(widget.partitionId);
    if (mounted) setState(() {});
  }
}
