import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
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

    final visibleDishes = state.corpus.dishes
        .where((d) => _best[d.id] != null)
        .toList()
      ..sort((a, b) => a.frequencyTier.compareTo(b.frequencyTier));

    Dish? featured;
    var bestScore = -1;
    for (final dish in visibleDishes) {
      final recipe = _best[dish.id];
      if (recipe == null) continue;
      final score =
          state.ranker.totalScore(recipe, state.profile, state.history);
      if (score > bestScore) {
        bestScore = score;
        featured = dish;
      }
    }

    final gridDishes =
        visibleDishes.where((d) => d.id != featured?.id).toList();

    return SafeArea(
      child: RefreshIndicator(
        color: MorphColors.terracotta,
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
              if (featured != null) ...[
                SectionHeader(title: s('featuredToday')),
                _featuredCard(featured, _best[featured.id]!, lang, state),
              ],
              const SizedBox(height: 12),
              SectionHeader(title: s('fromTheKitchen')),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.78,
                ),
                itemCount: gridDishes.length,
                itemBuilder: (context, i) {
                  final dish = gridDishes[i];
                  final recipe = _best[dish.id]!;
                  // The card sells the dish; the variant that opens is the
                  // profile's business (badge hints at it).
                  return PolaroidCard(
                    stripe: _hex(dish.stripe),
                    title: dish.name.of(lang),
                    caption: dish.caption.of(lang),
                    badge: state.profile.showVariantTags &&
                            recipe.variant.diet != 'classic'
                        ? state.corpus.ontology
                            .nameOf(recipe.variant.diet, lang)
                        : null,
                    rotationSeed: i,
                    onTap: () => _openDish(dish),
                  );
                },
              ),
              const SizedBox(height: 20),
              _colophon(s),
            ],
          ],
        ),
      ),
    );
  }

  Widget _masthead(S s, AppState state) {
    final name = state.profile.name;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('vol. 1', style: MorphText.label(size: 10)),
            IconButton(
              icon: const Icon(Icons.shopping_basket_outlined,
                  size: 20, color: MorphColors.inkSoft),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ShoppingListScreen())),
            ),
          ],
        ),
        Text('morphcook', style: MorphText.display.copyWith(fontSize: 44)),
        const SizedBox(height: 4),
        Text(s('tagline'), style: MorphText.hand.copyWith(fontSize: 19)),
        const SizedBox(height: 6),
        if (name.isNotEmpty)
          Text('${s('editionFor')} $name'.toLowerCase(),
              style: MorphText.label(size: 10)),
        const SizedBox(height: 2),
      ],
    );
  }

  Widget _featuredCard(
      Dish dish, Recipe recipe, String lang, AppState state) {
    return GestureDetector(
      onTap: () => _openDish(dish),
      child: Container(
        decoration: BoxDecoration(
          color: MorphColors.card,
          border: Border.all(color: MorphColors.line),
          boxShadow: [
            BoxShadow(
              color: MorphColors.ink.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripedPlaceholder(
              color: _hex(dish.stripe),
              height: 150,
              caption: dish.caption.of(lang),
            ),
            const SizedBox(height: 10),
            Text(dish.name.of(lang).toLowerCase(),
                style: MorphText.display.copyWith(fontSize: 28)),
            const SizedBox(height: 4),
            Text(dish.hero.of(lang),
                style: MorphText.mono
                    .copyWith(fontSize: 12, color: MorphColors.inkSoft)),
            const SizedBox(height: 8),
            Row(
              children: [
                _meta('${recipe.timeMinutes} ${S(lang)('minutes')}'),
                const SizedBox(width: 8),
                _meta('${recipe.caloriesPerServing} kcal'),
                const SizedBox(width: 8),
                _meta(state.corpus.ontology
                    .nameOf(recipe.variant.effort, lang)),
              ],
            ),
          ],
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
        GestureDetector(
          onTap: () => launchUrl(Uri.parse('https://www.the-morpheus.de/'),
              mode: LaunchMode.externalApplication),
          child: Text(s('supportMadeBy'),
              style: MorphText.hand.copyWith(fontSize: 18)),
        ),
      ],
    );
  }

  Widget _meta(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            border: Border.all(color: MorphColors.line),
            borderRadius: BorderRadius.circular(2)),
        child: Text(text.toLowerCase(), style: MorphText.label(size: 9)),
      );

  void _openDish(Dish dish) {
    Navigator.of(context)
        .push(MaterialPageRoute(
            builder: (_) => DishDetailScreen(dishId: dish.id)))
        .then((_) => _recompute());
  }
}

Color _hex(String hex) =>
    Color(int.parse(hex.replaceFirst('#', '0xFF')));
