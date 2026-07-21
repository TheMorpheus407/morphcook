import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/corpus_repository.dart';
import '../../core/engine/shopping.dart';
import '../../core/l10n.dart';
import '../../core/models/local_text.dart';
import '../../core/storage/local_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import 'shopping_screen.dart' show reduceMotionOf;

/// Shopping insights: gentle analytics over the ingredient-add events stored
/// in [LocalStore.shoppingEvents].
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  /// Localized lowercase month abbreviations (intl), with an English
  /// fallback when locale data is unavailable.
  List<String> _monthAbbrevs(String lang) {
    try {
      final fmt = DateFormat.MMM(lang);
      return List.generate(
        12,
        (i) => fmt.format(DateTime(2024, i + 1)).toLowerCase(),
      );
    } catch (_) {
      return const [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec',
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final store = context.watch<LocalStore>();
    final corpus = context.read<CorpusRepository>();
    final reduceMotion = reduceMotionOf(context);
    final insights = ShoppingInsights([
      for (final e in store.shoppingEvents)
        (ingredientId: e.ingredientId, at: e.at),
    ]);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 20, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: AppColors.inkSoft,
                      size: 22,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Text(
                    s.t('insights.title'),
                    style: AppText.masthead(size: 28),
                  ),
                ],
              ),
            ),
            Expanded(
              child: insights.events.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          s.t('insights.empty'),
                          style: AppText.handwritten(
                            size: 24,
                            color: AppColors.inkSoft,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      builder: (context, v, child) =>
                          Opacity(opacity: v, child: child),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          _varietySection(s, insights),
                          const SizedBox(height: 28),
                          _mostLovedSection(
                            s,
                            insights,
                            corpus,
                            s.lang,
                            reduceMotion,
                          ),
                          const SizedBox(height: 28),
                          _seasonsSection(s, insights, s.lang, reduceMotion),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _varietySection(AppStrings s, ShoppingInsights insights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('insights.variety')),
        const SizedBox(height: 12),
        Text(
          '${insights.varietyScore}',
          style: AppText.masthead(size: 72, color: AppColors.teal),
        ),
        Text(
          s.t('insights.variety.caption'),
          style: AppText.handwritten(size: 19),
        ),
      ],
    );
  }

  Widget _mostLovedSection(
    AppStrings s,
    ShoppingInsights insights,
    CorpusRepository corpus,
    String lang,
    bool reduceMotion,
  ) {
    final top = insights.topIngredients(limit: 8);
    if (top.isEmpty) return const SizedBox.shrink();
    final maxCount = top.first.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('insights.mostLoved')),
        const SizedBox(height: 14),
        for (final entry in top)
          _lovedRow(
            _ingredientName(corpus, entry.key, lang),
            entry.value,
            entry.value / maxCount,
            reduceMotion,
          ),
      ],
    );
  }

  String _ingredientName(CorpusRepository corpus, String id, String lang) {
    final node = corpus.ingredientDictionary.byId(id);
    if (node == null) return id;
    final name = localize(node.name, lang);
    return name.isEmpty ? id : name.toLowerCase();
  }

  Widget _lovedRow(String name, int count, double fraction, bool reduceMotion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: AppText.headline(size: 16))),
              Text(
                '×$count',
                style: AppText.monoLabel(size: 11, color: AppColors.teal),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: fraction.clamp(0.04, 1.0).toDouble()),
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              alignment: Alignment.centerLeft,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _seasonsSection(
    AppStrings s,
    ShoppingInsights insights,
    String lang,
    bool reduceMotion,
  ) {
    final months = _monthAbbrevs(lang);
    final counts = insights.byMonth();
    final maxCount = counts.values.fold(0, math.max);
    final currentMonth = DateTime.now().month;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionRule(label: s.t('insights.seasons')),
        const SizedBox(height: 16),
        SizedBox(
          height: 92,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var m = 1; m <= 12; m++)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: maxCount == 0 ? 0 : (counts[m] ?? 0) / maxCount,
                        ),
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => Container(
                          height: 2 + v * 58,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: m == currentMonth
                                ? AppColors.coral
                                : AppColors.teal,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        months[m - 1],
                        style: AppText.monoLabel(
                          size: 8,
                          color: m == currentMonth
                              ? AppColors.coral
                              : AppColors.inkSoft,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const DashedRule(),
      ],
    );
  }
}
