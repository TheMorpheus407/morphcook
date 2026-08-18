import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/dish.dart';
import '../../core/models/recipe.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/striped_placeholder.dart';
import '../../core/util/dates.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import '../widgets/dish_card.dart';

/// The newspaper-style home feed: masthead, featured dish, grid sections.
class HomeFeed extends StatelessWidget {
  const HomeFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final now = DateTime.now();
    final ranked = state.feedDishes();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _Masthead(now: now)),
        if (ranked.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyFeed(),
          )
        else ...[
          SliverToBoxAdapter(
              child: _Featured(dish: ranked.first.key, recipe: ranked.first.value)),
          SliverToBoxAdapter(
            child: _Section(
              eyebrow: context.tr('home.section.forYou.eyebrow'),
              title: context.tr('home.section.forYou.title'),
              children: ranked.map((e) => DishCard(dish: e.key, recipe: e.value)).toList(),
            ),
          ),
          SliverToBoxAdapter(child: _QuickSection(ranked: ranked)),
          SliverToBoxAdapter(child: _BreakfastSection(ranked: ranked)),
          SliverToBoxAdapter(child: _CuisineSections(state: state)),
          SliverToBoxAdapter(child: _RecentSection(state: state, lang: lang)),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ],
    );
  }
}

String dishName(Dish dish, String lang) => dish.name[lang] ?? dish.name['en'] ?? dish.id;
String dishHero(Dish dish, String lang) => dish.hero[lang] ?? dish.hero['en'] ?? '';
String dishCap(Dish dish, String lang) => dish.cap[lang] ?? dish.cap['en'] ?? '';
class _Masthead extends StatelessWidget {
  const _Masthead({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final name = state.profile.name;
    final hour = now.hour;
    final greetingKey = name == null || name.isEmpty
        ? 'home.greeting.anon'
        : hour < 11
            ? 'home.greeting.morning'
            : hour < 18
                ? 'home.greeting.day'
                : 'home.greeting.evening';
    // A gentle "issue number": days since the edition epoch.
    final edition = '${now.difference(DateTime(2026, 1, 5)).inDays + 1}';

    return Stack(
      children: [
        Positioned(
          right: -40,
          top: 26,
          child: Opacity(
            opacity: 0.14,
            child: Text(
              '&',
              style: AppFonts.display(size: 190, color: AppColors.teal),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 54, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('home.edition', {'n': edition}),
                style: AppFonts.mono(size: 9, color: AppColors.inkSoft, letterSpacing: 1.6),
              ),
              const SizedBox(height: 2),
              Text(
                DateFmt.dateLine(now, lang),
                style: AppFonts.mono(size: 9, color: AppColors.inkSoft, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'morphcook',
                  style: AppFonts.display(size: 54, color: AppColors.ink, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  context.tr('home.tagline'),
                  style: AppFonts.mono(size: 10, color: AppColors.coral),
                ),
              ),
              const SizedBox(height: 10),
              const DoubleRule(),
              const SizedBox(height: 8),
              Text(
                context.tr(greetingKey, {'name': name ?? ''}),
                style: AppFonts.hand(size: 26, color: AppColors.teal),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('home.calmNote'),
                style: AppFonts.hand(size: 17, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  QuietLink(
                      label: ' ☾ ${context.tr('shop.title')}',
                      onTap: () => openShoppingList(context)),
                  QuietLink(
                      label: ' ? ${context.tr('common.viewFaq')}',
                      onTap: () => openFaq(context)),
                  QuietLink(
                      label: ' ✎ ${context.tr('hist.title')}',
                      onTap: () => openHistory(context)),
                ],
              ),
              const DashedRule(glyph: '&'),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }
}
class _Featured extends StatelessWidget {
  const _Featured({required this.dish, required this.recipe});

  final Dish dish;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('home.featured').toUpperCase(),
            style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Transform.rotate(
            angle: -0.015,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.ink.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(3, 5),
                  ),
                ],
              ),
              child: Material(
                color: AppColors.paperCard,
                child: InkWell(
                  onTap: () => openDish(context, dish.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StripedPlaceholder(
                        stripeColor: dish.stripeColor,
                        caption: dishCap(dish, lang),
                        aspect: 1.9,
                        seed: 5,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dishName(dish, lang),
                              style: AppFonts.display(size: 30, color: AppColors.ink),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dishHero(dish, lang),
                              style:
                                  AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                TagChip(
                                    label: state.corpus.ontology.attrLabel(recipe.diet, lang)),
                                TagChip(
                                    label: '${recipe.timeMinutes} ${context.trRead('common.min')}'),
                                TagChip(
                                    label: '~${recipe.cal} ${context.trRead('common.kcal')}'),
                                TagChip(
                                    label: context.tr(
                                        'home.variantsCount', {'n': '${dish.variants.length}'})),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '→ ${context.tr('home.open')}',
                              style: AppFonts.mono(
                                  size: 11, color: AppColors.teal, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
class _Section extends StatelessWidget {
  const _Section({required this.eyebrow, required this.title, required this.children});

  final String eyebrow;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(eyebrow: eyebrow, title: title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.72,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: children,
          ),
        ),
      ],
    );
  }
}

class _QuickSection extends StatelessWidget {
  const _QuickSection({required this.ranked});

  final List<MapEntry<Dish, Recipe>> ranked;

  @override
  Widget build(BuildContext context) {
    final quick = ranked.where((e) => e.value.timeMinutes <= 30).toList();
    if (quick.isEmpty) return const SizedBox.shrink();
    return _Section(
      eyebrow: context.tr('home.section.quick.eyebrow'),
      title: context.tr('home.section.quick.title'),
      children: quick.map((e) => DishCard(dish: e.key, recipe: e.value)).toList(),
    );
  }
}

class _BreakfastSection extends StatelessWidget {
  const _BreakfastSection({required this.ranked});

  final List<MapEntry<Dish, Recipe>> ranked;

  @override
  Widget build(BuildContext context) {
    final breakfast = ranked.where((e) => e.key.isBreakfast).toList();
    if (breakfast.isEmpty) return const SizedBox.shrink();
    return _Section(
      eyebrow: context.tr('home.section.breakfast.eyebrow'),
      title: context.tr('home.section.breakfast.title'),
      children: breakfast.map((e) => DishCard(dish: e.key, recipe: e.value)).toList(),
    );
  }
}

class _CuisineSections extends StatelessWidget {
  const _CuisineSections({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    for (final cuisine in ['italian', 'asian', 'middle-eastern', 'american']) {
      final entries = state.feedDishes(cuisine: cuisine);
      if (entries.isEmpty) continue;
      sections.add(_Section(
        eyebrow: 'cuisine',
        title: context.tr('cuisine.$cuisine'),
        children: entries.map((e) => DishCard(dish: e.key, recipe: e.value)).toList(),
      ));
    }
    return Column(children: sections);
  }
}
class _RecentSection extends StatelessWidget {
  const _RecentSection({required this.state, required this.lang});

  final AppState state;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final recent = state.historyNewestFirst.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          eyebrow: context.tr('home.section.recent.eyebrow'),
          title: context.tr('home.section.recent.title'),
          action: QuietLink(label: context.tr('home.viewAll'), onTap: () => openHistory(context)),
        ),
        for (final entry in recent)
          () {
            final recipe = state.recipeForHistory(entry);
            final dish = recipe == null ? null : state.corpus.dishes[recipe.dish];
            if (recipe == null || dish == null) return const SizedBox.shrink();
            return DishRow(
              title: state.localized(recipe.title),
              subtitle:
                  '${DateFmt.shortDate(entry.at, lang)} · ${recipe.timeMinutes} ${context.trRead('common.min')}',
              stripeColor: dish.stripeColor,
              onTap: () => openDish(context, dish.id),
            );
          }(),
      ],
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          context.tr('home.nothingYet'),
          textAlign: TextAlign.center,
          style: AppFonts.serif(size: 15, color: AppColors.inkSoft),
        ),
      ),
    );
  }
}
