/// Newspaper home feed: masthead, featured dish, grid sections, search entry.
///
/// The feed NEVER hides the cookbook: fully profile-matching variants lead,
/// and when nothing matches a dish exactly the closest diet-compatible
/// variant is shown, flagged "outside your rules" (same fallback rule as
/// search and the meal picker — a restrictive profile must not blank the
/// front page).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'dish_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final corpus = app.corpus!;

    // one entry per dish: its representative recipe + match flag
    final shown = <({Dish dish, Recipe rep, bool matches})>[];
    for (final d in corpus.dishes.values) {
      final rep = app.defaultRecipeFor(d.id);
      if (rep == null) continue;
      shown.add((dish: d, rep: rep, matches: app.match(rep).visible));
    }

    if (shown.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Masthead(lang: lang, name: app.profile.name),
          const SizedBox(height: 40),
          HandNote(text: L.t(lang, 'empty')),
        ],
      );
    }

    final hour = DateTime.now().hour;
    int boost(Dish d) {
      if (hour >= 5 && hour < 11 && d.mealType == 'breakfast') return 2;
      if (hour >= 17 && hour < 21 && d.mealType != 'breakfast') return 1;
      return 0;
    }

    shown.sort((a, b) {
      final c = boost(b.dish).compareTo(boost(a.dish));
      if (c != 0) return c;
      // fully-matching dishes before flagged fallbacks
      final m = (a.matches ? 0 : 1).compareTo(b.matches ? 0 : 1);
      if (m != 0) return m;
      return a.dish.frequencyTier.compareTo(b.dish.frequencyTier);
    });

    final featured = shown.first;
    final anyFlagged = shown.any((e) => !e.matches);
    final quick = shown.where((e) => e.rep.timeMinutes <= 30).take(4).toList();
    final forYou = shown.take(6).toList();

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Masthead(lang: lang, name: app.profile.name),
              const SizedBox(height: 22),
              _SearchBarRow(lang: lang),
              if (anyFlagged) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration:
                      BoxDecoration(border: Border.all(color: AppTheme.mustard)),
                  child: Row(children: [
                    const Icon(Icons.filter_alt_outlined,
                        size: 15, color: AppTheme.mustard),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        L.t(lang, 'hmOutsideNote'),
                        style: const TextStyle(
                            fontFamily: AppTheme.mono,
                            fontSize: 10,
                            height: 1.5,
                            color: AppTheme.inkSoft),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 26),
            ]),
          ),
        ),
        // featured
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                L.t(lang, 'hmFeatured').toUpperCase(),
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.coral),
              ),
              const SizedBox(height: 12),
              _FeatureBlock(
                lang: lang,
                dish: featured.dish,
                recipe: featured.rep,
                variantCount: app.variantsOf(featured.dish.id).length,
                flagged: !featured.matches,
              ),
              const SizedBox(height: 34),
            ]),
          ),
        ),
        // quick section
        if (quick.isNotEmpty)
          _Section(
            lang: lang,
            title: L.t(lang, 'hmQuick'),
            children: [
              for (var i = 0; i < quick.length; i++)
                _GridCard(
                  lang: lang,
                  app: app,
                  entry: quick[i],
                  rotation: i.isEven ? -0.8 : 0.9,
                ),
            ],
          ),
        // for you section
        _Section(
          lang: lang,
          title: L.t(lang, 'hmForYou'),
          children: [
            for (var i = 0; i < forYou.length; i++)
              _GridCard(
                lang: lang,
                app: app,
                entry: forYou[i],
                rotation: i.isEven ? 0.7 : -0.9,
              ),
          ],
        ),
        // binder footer
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              RuleLabel(label: L.t(lang, 'hmBinder')),
              const SizedBox(height: 14),
              Wrap(spacing: 18, runSpacing: 18, children: [
                for (final d in corpus.dishes.values)
                  GestureDetector(
                    onTap: () => _openDish(context, d.id),
                    child: Text(
                      d.canonicalName.get(lang),
                      style: const TextStyle(
                          fontFamily: AppTheme.display,
                          fontStyle: FontStyle.italic,
                          fontSize: 17,
                          color: AppTheme.teal,
                          decoration: TextDecoration.underline,
                          decorationColor: AppTheme.line,
                          decorationThickness: 2),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

  void _openDish(BuildContext context, String dishId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DishScreen(dishId: dishId)),
    );
  }
}

class _SearchBarRow extends StatelessWidget {
  final Lang lang;
  const _SearchBarRow({required this.lang});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const SearchScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.ink, width: 1.4),
          color: AppTheme.paperDeep.withValues(alpha: 0.4),
        ),
        child: Row(children: [
          const Icon(Icons.search, size: 18, color: AppTheme.inkSoft),
          const SizedBox(width: 10),
          Text(
            L.t(lang, 'scHint'),
            style: const TextStyle(
                fontFamily: AppTheme.hand, fontSize: 18, color: AppTheme.inkFaint),
          ),
        ]),
      ),
    );
  }
}

class _FeatureBlock extends StatelessWidget {
  final Lang lang;
  final Dish dish;
  final Recipe recipe;
  final int variantCount;
  final bool flagged;
  const _FeatureBlock({
    required this.lang,
    required this.dish,
    required this.recipe,
    required this.variantCount,
    required this.flagged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DishScreen(dishId: dish.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StripedPlate(
          color: dish.color,
          caption: dish.capCaption.get(lang),
          height: 240,
          rotation: -0.6,
        ),
        const SizedBox(height: 14),
        Text(
          dish.canonicalName.get(lang),
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 6),
        Text(
          dish.hero.get(lang),
          style: const TextStyle(
              fontFamily: AppTheme.display,
              fontStyle: FontStyle.italic,
              fontSize: 16,
              height: 1.4,
              color: AppTheme.inkSoft),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Text(
              L.f(lang, 'hmVariants', {'n': variantCount.toString()}),
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 10.5,
                  letterSpacing: 1.2,
                  color: AppTheme.teal,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (flagged)
            Text(
              '⚑ ${L.t(lang, 'hmFlagged')}',
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 9.5,
                  letterSpacing: 1,
                  color: AppTheme.mustard,
                  fontWeight: FontWeight.w700),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
          '${recipe.effort} · ${recipe.timeMinutes} ${L.t(lang, 'minutes')} · ~${recipe.caloriesPerServing} ${L.t(lang, 'kcal')}',
          style: const TextStyle(
              fontFamily: AppTheme.mono, fontSize: 10.5, color: AppTheme.inkFaint),
        ),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final Lang lang;
  final String title;
  final List<Widget> children;
  const _Section({required this.lang, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 34),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Text(
            title.toUpperCase(),
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 10,
                letterSpacing: 2.4,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink),
          ),
          const SizedBox(height: 4),
          const DashedRule(),
          const SizedBox(height: 18),
          Wrap(spacing: 14, runSpacing: 22, children: children),
        ]),
      ),
    );
  }
}

class _GridCard extends StatelessWidget {
  final Lang lang;
  final AppState app;
  final ({Dish dish, Recipe rep, bool matches}) entry;
  final double rotation;
  const _GridCard({
    required this.lang,
    required this.app,
    required this.entry,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    final dietLabel =
        app.ontology.dietLabels[entry.rep.diet]?.label.get(lang) ?? entry.rep.diet;
    return SizedBox(
      width: 152,
      child: PolaroidCard(
        stripeColor: entry.dish.color,
        title: entry.dish.canonicalName.get(lang),
        subtitle: entry.rep.subtitle.get(lang),
        meta:
            '${entry.rep.timeMinutes} ${L.t(lang, 'minutes')} · ~${entry.rep.caloriesPerServing} ${L.t(lang, 'kcal')}',
        tag: app.profile.showVariantTags ? dietLabel : null,
        flagText: entry.matches ? null : L.t(lang, 'hmFlagged'),
        rotation: rotation,
        plateHeight: 110,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => DishScreen(dishId: entry.dish.id))),
      ),
    );
  }
}
