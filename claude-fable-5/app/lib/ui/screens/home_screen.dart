import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
import '../widgets/recipe_cover.dart';
import 'dish_detail_screen.dart';
import 'shopping_list_screen.dart';

/// Newspaper-style home feed: masthead, featured dish, grid sections.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // dishId -> the user's best visible variant (null = no variant passes).
  Map<String, Recipe?> _best = {};
  bool _loaded = false;

  // Selected browse category; null shows the full sectioned feed.
  String? _category;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  Future<void> _recompute() async {
    final state = context.read<AppState>();
    final result = <String, Recipe?>{};
    for (final dish in state.corpus.dishes) {
      result[dish.id] = await state.bestVariant(dish.id);
    }
    if (!mounted) return;
    setState(() {
      _best = result;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;

    final visibleDishes =
        state.corpus.dishes.where((d) => _best[d.id] != null).toList()
          ..sort((a, b) => a.frequencyTier.compareTo(b.frequencyTier));

    Dish? featured;
    var bestScore = -1;
    for (final dish in visibleDishes) {
      final recipe = _best[dish.id];
      if (recipe == null) continue;
      final score = state.ranker.totalScore(
        recipe,
        state.profile,
        state.history,
      );
      if (score > bestScore) {
        bestScore = score;
        featured = dish;
      }
    }

    final showAll = _category == null;

    // Dishes bucketed per category in dishes.json order, each section
    // carrying its card-index offset so keys stay one running sequence
    // (the first visible card is always home-dish-card-0).
    final sections = <(DishCategory, List<Dish>, int)>[];
    var cardIndex = 0;
    for (final category in state.corpus.categories) {
      if (!showAll && _category != category.id) continue;
      final dishes = visibleDishes
          .where((d) => d.category == category.id)
          .toList();
      if (showAll) dishes.removeWhere((d) => d.id == featured?.id);
      if (showAll && dishes.isEmpty) continue;
      sections.add((category, dishes, cardIndex));
      cardIndex += dishes.length;
    }

    return SafeArea(
      child: RefreshIndicator(
        color: MorphTheme.of(context).colors.terracotta,
        onRefresh: _recompute,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _masthead(s, state),
            const SizedBox(height: 6),
            if (!_loaded) ...[
              const SkeletonBlock(height: 220),
              const SkeletonBlock(height: 140),
            ] else ...[
              _categoryChips(s, state),
              const SizedBox(height: 6),
              if (showAll && featured != null) ...[
                SectionHeader(title: s('featuredToday')),
                _featuredCard(featured, _best[featured.id]!, lang, state),
                const SizedBox(height: 12),
              ],
              for (final (category, dishes, offset) in sections) ...[
                SectionHeader(title: category.name.of(lang)),
                const SizedBox(height: 6),
                if (dishes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      s('categoryEmpty'),
                      textAlign: TextAlign.center,
                      style: MorphTheme.of(context).text.handAt(
                            18,
                            color: MorphTheme.of(context).colors.inkSoft,
                          ),
                    ),
                  )
                else
                  _dishGrid(dishes, offset, lang, state),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              _colophon(s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _categoryChips(S s, AppState state) {
    final lang = state.lang;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MonoChip(
              label: s('allCategories'),
              selected: _category == null,
              onTap: () => setState(() => _category = null),
            ),
          ),
          for (final category in state.corpus.categories)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: MonoChip(
                label: category.name.of(lang),
                selected: _category == category.id,
                onTap: () => setState(
                  () => _category = _category == category.id
                      ? null
                      : category.id,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dishGrid(List<Dish> dishes, int indexOffset, String lang,
      AppState state) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.78,
      ),
      itemCount: dishes.length,
      itemBuilder: (context, i) {
        final dish = dishes[i];
        final recipe = _best[dish.id]!;
        final globalIndex = indexOffset + i;
        // The card sells the dish; the variant that opens is the
        // profile's business (badge hints at it).
        return PolaroidCard(
          key: ValueKey('home-dish-card-$globalIndex'),
          stripe: _hex(dish.stripe),
          title: dish.name.of(lang),
          caption: dish.caption.of(lang),
          badge:
              state.profile.showVariantTags &&
                  recipe.variant.diet != 'classic'
              ? state.corpus.ontology.nameOf(
                  recipe.variant.diet,
                  lang,
                )
              : null,
          rotationSeed: globalIndex,
          photo: RecipeCover(
            recipeId: recipe.id,
            fallbackColor: _hex(dish.stripe),
            height: 110,
            semanticLabel: recipe.title.of(lang),
          ),
          onTap: () => _openDish(dish),
        );
      },
    );
  }

  Widget _masthead(S s, AppState state) {
    final name = state.profile.name;
    final morph = MorphTheme.of(context);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('vol. 1', style: morph.text.label(size: 10)),
            IconButton(
              icon: Icon(
                Icons.shopping_basket_outlined,
                size: 20,
                color: morph.colors.inkSoft,
              ),
              tooltip: s('shoppingList'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              ),
            ),
          ],
        ),
        Text('morphcook', style: morph.text.display.copyWith(fontSize: 44)),
        const SizedBox(height: 4),
        Text(s('tagline'), style: morph.text.handAt(19)),
        const SizedBox(height: 6),
        if (name.isNotEmpty)
          Text(
            morph.cased('${s('editionFor')} $name'),
            style: morph.text.label(size: 10),
          ),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _featuredCard(Dish dish, Recipe recipe, String lang, AppState state) {
    final morph = MorphTheme.of(context);
    return Semantics(
      button: true,
      label: dish.name.of(lang),
      child: GestureDetector(
        onTap: () => _openDish(dish),
        child: Container(
          decoration: BoxDecoration(
            color: morph.colors.card,
            border: Border.all(color: morph.colors.line),
            boxShadow: [
              BoxShadow(
                color: morph.colors.ink.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RecipeCover(
                recipeId: recipe.id,
                fallbackColor: _hex(dish.stripe),
                height: 150,
                fallbackCaption: dish.caption.of(lang),
                semanticLabel: recipe.title.of(lang),
              ),
              const SizedBox(height: 10),
              Text(
                morph.cased(dish.name.of(lang)),
                style: morph.text.display.copyWith(fontSize: 28),
              ),
              const SizedBox(height: 4),
              Text(
                dish.hero.of(lang),
                style: morph.text.mono.copyWith(
                  fontSize: 12,
                  color: morph.colors.inkSoft,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _meta('${recipe.timeMinutes} ${S(lang)('minutes')}'),
                  const SizedBox(width: 8),
                  _meta('${recipe.caloriesPerServing} kcal'),
                  const SizedBox(width: 8),
                  _meta(
                    state.corpus.ontology.nameOf(recipe.variant.effort, lang),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Newspaper imprint line at the foot of the feed — handwritten, quiet,
  /// taps through to the maker's site.
  Widget _colophon(S s) {
    return Column(
      children: [
        const DashedDivider(height: 1),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          link: true,
          child: GestureDetector(
            onTap: () => launchUrl(
              Uri.parse('https://www.the-morpheus.de/'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              s('supportMadeBy'),
              style: MorphTheme.of(context).text.handAt(18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(String text) {
    final morph = MorphTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: morph.colors.line),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(morph.cased(text), style: morph.text.label(size: 9)),
    );
  }

  void _openDish(Dish dish) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => DishDetailScreen(dishId: dish.id)),
        )
        .then((_) => _recompute());
  }
}

Color _hex(String hex) => Color(int.parse(hex.replaceFirst('#', '0xFF')));
