import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../matching/matching.dart';
import '../../matching/ranking.dart';
import '../../models/dish.dart';
import '../../models/recipe.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../util/time_context.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/polaroid_card.dart';
import '../../widgets/striped_placeholder.dart';
import '../../widgets/tag_chip.dart';
import '../dish/dish_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MultiListenableBuilder(
      listenables: [
        state.profileRepo,
        state.cookbookRepo,
        state.historyRepo,
      ],
      builder: (_) => _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);
    final profile = state.profileRepo.profile;
    final lang = profile.lang;
    final now = DateTime.now();
    final ctx = TimeContext.from(now);
    final rankingCtx = RankingContext.fromHistory(
      state.historyRepo
          .lastCookedByRecipe()
          .entries
          .map((e) => MapEntry(e.key, e.value)),
      now: now,
    );

    final dishes = state.recipeRepo.allDishes();
    final dishToBest = <Dish, Recipe>{};
    for (final d in dishes) {
      final candidates = d.variantRecipeIds
          .map((id) => state.recipeRepo.recipe(id))
          .whereType<Recipe>()
          .where((r) => isVisible(
                r,
                profile,
                ontology: state.ontologyRepo.ontology,
                ingredients: state.ingredientRepo.tree,
              ))
          .toList()
        ..sort((a, b) => rank(b, profile, rankingCtx).compareTo(rank(a, profile, rankingCtx)));
      if (candidates.isNotEmpty) dishToBest[d] = candidates.first;
    }

    final featured = _pickFeatured(dishToBest);
    final morning = _byAttribute(dishToBest, 'breakfast');
    final evening = _byAttribute(dishToBest, 'dinner');
    final quick = _byTime(dishToBest, maxMinutes: 30);
    final weekend = _byEffort(dishToBest, const ['medium', 'hard']);

    final issue = _issueLabel(now, lang);

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                sliver: SliverToBoxAdapter(
                  child: Masthead(
                    title: s.homeMasthead,
                    subtitle: '${s.tagline}.',
                    issueLabel: issue,
                  ),
                ),
              ),
              if (featured != null) ...[
                SliverToBoxAdapter(
                  child: _Featured(
                    dish: featured.key,
                    recipe: featured.value,
                    onTap: () => _open(context, featured.key, featured.value),
                  ),
                ),
              ],
              if (ctx.isMorning && morning.isNotEmpty)
                _SectionSliver(
                  eyebrow: s.forYourMorning,
                  title: '☀',
                  items: morning,
                ),
              if (ctx.isEvening && evening.isNotEmpty)
                _SectionSliver(
                  eyebrow: s.forYourEvening,
                  title: '🌙',
                  items: evening,
                ),
              if (ctx.isWeekend && weekend.isNotEmpty)
                _SectionSliver(
                  eyebrow: s.forYourWeekend,
                  title: '∞',
                  items: weekend,
                ),
              if (quick.isNotEmpty)
                _SectionSliver(
                  eyebrow: s.quickToday,
                  title: '— under 30 min —',
                  items: quick,
                ),
              _SectionSliver(
                eyebrow: s.freshIdeas,
                title: '· · ·',
                items: dishToBest.entries.toList(),
              ),
              if (dishToBest.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: HandwrittenNote(
                      text: s.neverShownNoMatch,
                      color: MCColors.inkSoft,
                      size: 22,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  MapEntry<Dish, Recipe>? _pickFeatured(Map<Dish, Recipe> m) {
    if (m.isEmpty) return null;
    final list = m.entries.toList();
    final idx = DateTime.now().day % list.length;
    return list[idx];
  }

  List<MapEntry<Dish, Recipe>> _byAttribute(Map<Dish, Recipe> m, String attr) {
    return m.entries.where((e) => e.value.attributes.contains(attr)).toList();
  }

  List<MapEntry<Dish, Recipe>> _byTime(Map<Dish, Recipe> m, {required int maxMinutes}) {
    return m.entries.where((e) => e.value.timeMinutes <= maxMinutes).toList();
  }

  List<MapEntry<Dish, Recipe>> _byEffort(Map<Dish, Recipe> m, List<String> efforts) {
    return m.entries.where((e) => efforts.contains(e.value.effort)).toList();
  }

  void _open(BuildContext context, Dish d, Recipe r) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DishDetailScreen(dishId: d.id, initialRecipeId: r.id),
    ));
  }

  String _issueLabel(DateTime now, String lang) {
    final fmt = lang == 'de' ? DateFormat('EEE d. MMM', 'de') : DateFormat('EEE, MMM d');
    try {
      final n = (now.year * 365 + now.month * 30 + now.day) % 999;
      final issueWord = lang == 'de' ? 'AUSGABE' : 'ISSUE';
      return '$issueWord ${n.toString().padLeft(3, '0')}  ·  ${fmt.format(now).toLowerCase()}';
    } catch (_) {
      return 'ISSUE ${now.day}';
    }
  }
}

class _Featured extends StatelessWidget {
  final Dish dish;
  final Recipe recipe;
  final VoidCallback onTap;
  const _Featured({required this.dish, required this.recipe, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final lang = AppScope.of(context).profileRepo.profile.lang;
    final stripe = _hex(dish.stripeColor);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.featuredToday.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 8),
            StripedPlaceholder(
              stripeColor: stripe,
              caption: dish.capCaption.resolve(lang),
              aspectRatio: 16 / 9,
            ),
            const SizedBox(height: 18),
            Text(
              dish.name.resolve(lang).toLowerCase(),
              style: MCTypography.display(size: 42),
            ),
            const SizedBox(height: 8),
            Text(
              dish.heroCaption.resolve(lang),
              style: MCTypography.italic(size: 17, color: MCColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TagChip(label: recipe.variantLabel.resolve(lang)),
                const SizedBox(width: 8),
                TagChip(label: '${recipe.timeMinutes} ${s.minutes}'),
                const SizedBox(width: 8),
                TagChip(label: recipe.effort),
                const SizedBox(width: 8),
                TagChip(label: '${recipe.caloriesPerServing} kcal'),
              ],
            ),
            const SizedBox(height: 14),
            const DashedRule(),
          ],
        ),
      ),
    );
  }

  Color _hex(String s) {
    final c = s.replaceFirst('#', '');
    final v = int.tryParse(c.length == 6 ? 'FF$c' : c, radix: 16);
    return v == null ? MCColors.stripeFallback : Color(v);
  }
}

class _SectionSliver extends StatelessWidget {
  final String eyebrow;
  final String title;
  final List<MapEntry<Dish, Recipe>> items;

  const _SectionSliver({
    required this.eyebrow,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    final lang = AppScope.of(context).profileRepo.profile.lang;
    return SliverList(
      delegate: SliverChildListDelegate.fixed([
        SectionHeader(eyebrow: eyebrow, title: title),
        SizedBox(
          height: 360,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final dish = items[i].key;
              final recipe = items[i].value;
              return PolaroidCard(
                title: dish.name.resolve(lang),
                subtitle: dish.heroCaption.resolve(lang),
                eyebrow: recipe.variantLabel.resolve(lang),
                handwritten: i == 0 ? null : null,
                stripeColor: _hex(dish.stripeColor),
                placeholderCaption: dish.capCaption.resolve(lang),
                rotationTurns: (i.isOdd ? 0.004 : -0.004),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DishDetailScreen(
                    dishId: dish.id,
                    initialRecipeId: recipe.id,
                  ),
                )),
              );
            },
          ),
        ),
      ]),
    );
  }

  Color _hex(String s) {
    final c = s.replaceFirst('#', '');
    final v = int.tryParse(c.length == 6 ? 'FF$c' : c, radix: 16);
    return v == null ? MCColors.stripeFallback : Color(v);
  }
}
