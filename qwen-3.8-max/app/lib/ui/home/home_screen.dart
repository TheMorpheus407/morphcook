import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../data/models.dart';
import '../../domain/ranking.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../dish/dish_screen.dart';
import '../widgets.dart';

/// Home feed: newspaper-style masthead, featured dish, grid sections.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    // Prefetch the long-tail partition once the first frame has settled,
    // then the cuisine views that power the discovery sections.
    _idleTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final corpus = context.read<CorpusRepository>();
      await corpus.prefetchIdlePartitions();
      for (final p in corpus.manifest.partitions) {
        if (p.id.startsWith('cuisine-')) {
          await corpus.loadPartition(p.id);
        }
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  void _openDish(Dish dish, {String? recipeId}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DishScreen(dishId: dish.id, initialRecipeId: recipeId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;
    final profile = app.profile;

    final ctx = RankingContext(
      now: DateTime.now(),
      lastCooked: library.lastCookedMap(),
    );

    final ranked = rankDishes(
      dishes: corpus.dishes,
      allVariants: (dish) => corpus.recipesForDish(dish.id),
      profile: profile,
      ctx: ctx,
      ontology: corpus.ontology,
      dictionary: corpus.ingredients,
    );

    final featured = ranked.isNotEmpty ? ranked.first : null;
    final rest = ranked.length > 1 ? ranked.sublist(1) : <({Dish dish, Recipe recipe, int score})>[];

    final weeknight = rest
        .where((r) => r.recipe.effort == 'easy' && r.recipe.timeMinutes <= 30)
        .take(6)
        .toList();
    final comfort = rest
        .where((r) => r.recipe.attributes.contains('comfort'))
        .take(6)
        .toList();
    final breakfast = rest
        .where((r) => r.recipe.mealSlots.contains('breakfast'))
        .take(4)
        .toList();

    final cuisineSections = <({String title, String partition, List<({Dish dish, Recipe recipe, int score})> items})>[];
    for (final (partition, key) in [
      ('cuisine-italian', 'cuisineItalian'),
      ('cuisine-asian', 'cuisineAsian'),
      ('cuisine-middle-eastern', 'cuisineMiddleEastern'),
    ]) {
      if (!corpus.isPartitionLoaded(partition)) continue;
      final dishIds = {
        for (final d in corpus.dishes)
          if (d.secondaryPartitions.contains(partition)) d.id
      };
      final items = rest.where((r) => dishIds.contains(r.dish.id)).take(4).toList();
      if (items.isNotEmpty) {
        cuisineSections.add((title: s.get(key), partition: partition, items: items));
      }
    }

    final dateLine = DateFormat(lang == AppLang.de ? 'EEEE, d. MMMM yyyy' : 'EEEE, MMMM d, yyyy')
        .format(DateTime.now());

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(dateLine, style: Type.label())),
                      Text('№ 1', style: Type.label(color: Paper.inkFaint)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('MorphCook',
                        style: Type.displayBold(size: 40)),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(s.get('tagline'),
                        style: Type.hand(size: 17)),
                  ),
                  const SizedBox(height: 8),
                  const DashedLine(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${profile.name} · ${s.get('forYou')}',
                          style: Type.label(color: Paper.inkFaint)),
                    ],
                  ),
                  const DashedLine(),
                ],
              ),
            ),
          ),
          if (featured != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.get('featured').toUpperCase(),
                        style: Type.label(color: Paper.coral)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _openDish(featured.dish,
                          recipeId: featured.recipe.id),
                      child: StripedPlaceholder(
                        colorHex: featured.dish.stripeColor,
                        height: 190,
                        caption: tx(featured.dish.capCaption, lang),
                        rotation: -0.006,
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _openDish(featured.dish,
                          recipeId: featured.recipe.id),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx(featured.recipe.title, lang),
                              style: Type.displayBold(size: 26)),
                          const SizedBox(height: 6),
                          Text(tx(featured.dish.hero, lang),
                              style: Type.mono(
                                  size: 12, color: Paper.inkSoft)),
                          const SizedBox(height: 6),
                          MetaLine(recipe: featured.recipe),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (weeknight.isNotEmpty)
            _RecipeStrip(
              title: s.get('weeknight'),
              items: weeknight,
              onOpen: _openDish,
            ),
          if (breakfast.isNotEmpty)
            _RecipeStrip(
              title: s.get('breakfast'),
              items: breakfast,
              onOpen: _openDish,
            ),
          if (comfort.isNotEmpty)
            _RecipeStrip(
              title: s.get('comfort'),
              items: comfort,
              onOpen: _openDish,
            ),
          for (final section in cuisineSections)
            _RecipeStrip(
              title: section.title,
              items: section.items,
              onOpen: _openDish,
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }
}

class _RecipeStrip extends StatelessWidget {
  final String title;
  final List<({Dish dish, Recipe recipe, int score})> items;
  final void Function(Dish dish, {String? recipeId}) onOpen;

  const _RecipeStrip({
    required this.title,
    required this.items,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryModel>();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 0, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: SectionHeader(text: title),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final rotation =
                      (index.isEven ? -1 : 1) * (0.008 + (index % 3) * 0.004);
                  return SizedBox(
                    width: 170,
                    child: RecipeCard(
                      recipe: item.recipe,
                      rotation: rotation,
                      saved: library.isSaved(item.recipe.id),
                      onTap: () =>
                          onOpen(item.dish, recipeId: item.recipe.id),
                    ),
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
