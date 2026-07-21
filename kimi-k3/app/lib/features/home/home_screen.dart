import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/engine/matching.dart';
import '../../core/l10n.dart';
import '../../core/models/dish.dart';
import '../../core/models/local_text.dart';
import '../../core/models/profile.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/polaroid_card.dart';
import '../../shared/widgets/striped_image.dart';

/// A dish paired with its best visible variant for the current profile.
class _DishEntry {
  final Dish dish;
  final Recipe best;
  const _DishEntry(this.dish, this.best);
}

/// The newspaper-style home feed: masthead, today's dish, ranked sections.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _partitionRequested = false;
  final Set<String> _dateLocalesReady = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_partitionRequested) {
      _partitionRequested = true;
      // Load extended recipes in the background for completeness; the
      // featured pick below always comes from the core partition.
      unawaited(context.read<CorpusRepository>().ensurePartition('extended'));
    }
    _ensureDateLocale(context.read<ProfileStore>().profile.lang);
  }

  /// intl needs per-locale date symbols; load them lazily per profile lang.
  void _ensureDateLocale(String lang) {
    if (_dateLocalesReady.contains(lang)) return;
    initializeDateFormatting(lang)
        .then((_) {
          if (!mounted) return;
          setState(() => _dateLocalesReady.add(lang));
        })
        .catchError((_) {});
  }

  String _dateLine(String lang, DateTime now) {
    try {
      return DateFormat('EEEE, d MMMM y', lang).format(now).toLowerCase();
    } catch (_) {
      return DateFormat('EEEE, d MMMM y').format(now).toLowerCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final profile = context.watch<ProfileStore>().profile;
    final lang = profile.lang;
    _ensureDateLocale(lang);

    final corpus = context.read<CorpusRepository>();
    final matching = context.read<MatchingEngine>();
    final lastCooked = context.read<LocalStore>().lastCookedAtByRecipe;
    final now = DateTime.now();

    final reduceMotion =
        profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);

    // Every dish with at least one visible variant, paired with its best.
    final byDish = <String, _DishEntry>{};
    for (final dish in corpus.dishes) {
      final best = matching.bestVariant(dish, corpus.variantsOf(dish), profile);
      if (best != null) byDish[dish.id] = _DishEntry(dish, best);
    }

    // Rank all visible variants once; sections slice this ordering.
    final ranked = matching.rankVisible(
      corpus.dishes.expand((d) => corpus.variantsOf(d)),
      profile,
      now: now,
      lastCookedAtByRecipe: lastCooked,
    );

    // Featured: top-ranked variant among core-partition dishes only.
    _DishEntry? featured;
    for (final recipe in ranked) {
      final dish = corpus.dishById(recipe.dishId);
      if (dish == null || dish.partitionId != 'core') continue;
      featured = byDish[dish.id];
      break;
    }

    List<_DishEntry> take(bool Function(Recipe) test, {int max = 8}) {
      final seen = <String>{};
      final out = <_DishEntry>[];
      for (final recipe in ranked) {
        if (!test(recipe)) continue;
        if (!seen.add(recipe.dishId)) continue;
        final entry = byDish[recipe.dishId];
        if (entry == null) continue;
        out.add(entry);
        if (out.length >= max) break;
      }
      return out;
    }

    final tonight = take((r) => r.mealTypes.contains('dinner'));
    final slowSunday = take((r) => r.effort == 'hard');
    final quickKind = take((r) => r.effort == 'easy' && r.timeMinutes <= 30);

    Widget animate(Widget child, int delayMs) {
      if (reduceMotion) return child;
      return child
          .animate(delay: Duration(milliseconds: delayMs))
          .fadeIn(duration: 420.ms, curve: Curves.easeOut)
          .slideY(begin: 0.04, end: 0, duration: 420.ms, curve: Curves.easeOut);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            animate(
              _Masthead(dateLine: _dateLine(lang, now), profile: profile),
              0,
            ),
            const SizedBox(height: 10),
            animate(const DashedRule(), 60),
            const SizedBox(height: 8),
            animate(
              Transform.rotate(
                angle: -0.03,
                child: Text(
                  s.t('home.note'),
                  style: AppText.handwritten(size: 21),
                ),
              ),
              100,
            ),
            const SizedBox(height: 18),
            if (byDish.isEmpty)
              animate(const _EmptyState(), 140)
            else ...[
              if (featured != null) ...[
                animate(SectionRule(label: s.t('home.todays_dish')), 140),
                const SizedBox(height: 14),
                animate(
                  _FeaturedCard(entry: featured, lang: lang, profile: profile),
                  200,
                ),
                const SizedBox(height: 26),
              ],
              if (tonight.isNotEmpty) ...[
                animate(SectionRule(label: s.t('home.tonight')), 260),
                const SizedBox(height: 12),
                animate(
                  _DishRail(entries: tonight, lang: lang, profile: profile),
                  320,
                ),
                const SizedBox(height: 24),
              ],
              if (slowSunday.isNotEmpty) ...[
                animate(SectionRule(label: s.t('home.slow_sunday')), 340),
                const SizedBox(height: 12),
                animate(
                  _DishRail(entries: slowSunday, lang: lang, profile: profile),
                  400,
                ),
                const SizedBox(height: 24),
              ],
              if (quickKind.isNotEmpty) ...[
                animate(SectionRule(label: s.t('home.quick_kind')), 420),
                const SizedBox(height: 12),
                animate(
                  _DishRail(entries: quickKind, lang: lang, profile: profile),
                  480,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Word-mark, localized date + name line, and calm ink-outline actions.
class _Masthead extends StatelessWidget {
  final String dateLine;
  final UserProfile profile;

  const _Masthead({required this.dateLine, required this.profile});

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final name = profile.name.trim();
    final meta = name.isEmpty
        ? dateLine
        : '$dateLine  ·  ${s.t('home.for_prefix')} ${name.toLowerCase()}';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MorphCook', style: AppText.masthead()),
              const SizedBox(height: 6),
              Text(meta, style: AppText.monoLabel(size: 11)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _OutlineIconButton(
          icon: Icons.settings_outlined,
          tooltip: s.t('home.settings'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
        ),
        const SizedBox(width: 8),
        _OutlineIconButton(
          icon: Icons.question_mark_rounded,
          tooltip: s.t('home.help'),
          onTap: () => Navigator.pushNamed(context, AppRoutes.faq),
        ),
      ],
    );
  }
}

class _OutlineIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _OutlineIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.ink, width: 1.1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: 18, color: AppColors.ink),
          ),
        ),
      ),
    );
  }
}

/// Mono meta line: `35 min • 520 kcal • easy`.
String _metaLine(AppStrings s, Recipe r) =>
    '${r.timeMinutes} ${s.t('common.minutes')} • '
    '${r.caloriesPerServing} ${s.t('common.kcal')} • '
    '${s.t('effort.${r.effort}')}';

/// Small mono chip with the best variant's lattice coordinates.
class _VariantChip extends StatelessWidget {
  final Recipe recipe;

  const _VariantChip({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.paperDark,
        border: Border.all(color: AppColors.inkSoft, width: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${s.t('diet.${recipe.diet}')} · ${s.t('effort.${recipe.effort}')} '
        '· ~${recipe.caloriesPerServing}',
        style: AppText.monoLabel(size: 9, color: AppColors.ink),
      ),
    );
  }
}

void _openDish(BuildContext context, String dishId) =>
    Navigator.pushNamed(context, AppRoutes.dish, arguments: dishId);

/// Large polaroid for "today's dish".
class _FeaturedCard extends StatelessWidget {
  final _DishEntry entry;
  final String lang;
  final UserProfile profile;

  const _FeaturedCard({
    required this.entry,
    required this.lang,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final dish = entry.dish;
    return PolaroidCard(
      rotation: -0.02,
      padding: const EdgeInsets.all(14),
      onTap: () => _openDish(context, dish.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StripedImage(
            stripeColor: dish.stripeColor,
            caption: localize(dish.capCaption, lang),
            height: 200,
          ),
          const SizedBox(height: 12),
          Text(localize(dish.name, lang), style: AppText.headline(size: 26)),
          const SizedBox(height: 6),
          Text(
            localize(dish.heroText, lang),
            style: AppText.body(size: 14, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _metaLine(s, entry.best),
                  style: AppText.monoLabel(size: 11),
                ),
              ),
              if (profile.showVariantTags) _VariantChip(recipe: entry.best),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal rail of small polaroid dish cards.
class _DishRail extends StatelessWidget {
  final List<_DishEntry> entries;
  final String lang;
  final UserProfile profile;

  const _DishRail({
    required this.entries,
    required this.lang,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return SizedBox(
      height: profile.showVariantTags ? 222 : 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _SmallDishCard(
            entry: entry,
            lang: lang,
            profile: profile,
            metaLine: _metaLine(s, entry.best),
            rotation: index.isEven ? -0.015 : 0.015,
          );
        },
      ),
    );
  }
}

class _SmallDishCard extends StatelessWidget {
  final _DishEntry entry;
  final String lang;
  final UserProfile profile;
  final String metaLine;
  final double rotation;

  const _SmallDishCard({
    required this.entry,
    required this.lang,
    required this.profile,
    required this.metaLine,
    required this.rotation,
  });

  @override
  Widget build(BuildContext context) {
    final dish = entry.dish;
    return PolaroidCard(
      rotation: rotation,
      padding: const EdgeInsets.all(8),
      onTap: () => _openDish(context, dish.id),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StripedImage(
              stripeColor: dish.stripeColor,
              height: 90,
              showCaption: false,
            ),
            const SizedBox(height: 8),
            Text(
              localize(dish.name, lang),
              style: AppText.headline(size: 15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              metaLine,
              style: AppText.monoLabel(size: 9),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (profile.showVariantTags) ...[
              const SizedBox(height: 6),
              _VariantChip(recipe: entry.best),
            ],
          ],
        ),
      ),
    );
  }
}

/// Calm note shown when no dish survives the profile filters.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Transform.rotate(
            angle: -0.02,
            child: Text(
              s.t('home.empty_note'),
              style: AppText.handwritten(size: 26, color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            s.t('home.empty_hint'),
            style: AppText.monoLabel(size: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
