import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../l10n/strings.dart';
import '../../services/insights_service.dart';
import '../../state/app_state.dart';
import '../faq/faq_screen.dart';

/// Variety score, most-added ingredients, and a month-by-month breakdown.
/// Descriptive, never a grade — a quiet month is a fine way to eat.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final insights = state.insights;

    if (insights.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.insightsTitle.toLowerCase())),
        body: EmptyNote(
          headline: s.insightsEmptyTitle,
          body: s.insightsEmptyBody,
          icon: Icons.insights_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.insightsTitle.toLowerCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
        children: [
          Polaroid(
            seed: 'insights',
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(s.insightsVariety),
                const SizedBox(height: 6),
                Text(
                  '${insights.varietyScore}',
                  style: MorphType.numeric(
                    colors.accent,
                    size: 52,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.insightsVarietyNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (insights.firstAddedAt != null) ...[
                  const SizedBox(height: 6),
                  HandNote(
                    s.insightsSince(
                      DateFormat.yMMMM(s.lang).format(insights.firstAddedAt!),
                    ),
                    size: 19,
                  ),
                ],
                const SizedBox(height: 16),
                DashedRule(color: colors.edge),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatPair(
                      label: s.insightsTotal,
                      value: '${insights.totalAdditions}',
                    ),
                    StatPair(
                      label: s.insightsRepeat,
                      value: insights.repeatRate.toStringAsFixed(1),
                      tone: colors.secondary,
                    ),
                    StatPair(
                      label: s.insightsSeasonal,
                      value: '${insights.byMonth.length}',
                      tone: colors.mustard,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          SectionHeader(s.insightsTop),
          const SizedBox(height: 14),
          _FrequencyBars(entries: insights.topIngredients, lang: s.lang),
          const SizedBox(height: 30),
          SectionHeader(s.insightsSeasonal),
          const SizedBox(height: 14),
          _MonthChart(buckets: insights.byMonth, lang: s.lang),
          const SizedBox(height: 30),
          SectionHeader(s.insightsAisles),
          const SizedBox(height: 14),
          _AisleSpread(spread: insights.aisleSpread, lang: s.lang),
          const SizedBox(height: 26),
          FaqLink(anchor: 'insights', label: s.helpLinkLabel),
        ],
      ),
    );
  }
}

class _FrequencyBars extends StatelessWidget {
  const _FrequencyBars({required this.entries, required this.lang});

  final List<IngredientFrequency> entries;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final max = entries.isEmpty
        ? 1
        : entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label(lang),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${entry.count}×',
                      style: MorphType.numeric(colors.inkSoft, size: 11.5),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(height: 6, color: colors.paperSunk),
                      Container(
                        height: 6,
                        width: constraints.maxWidth * (entry.count / max),
                        color: colors.accent,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthChart extends StatelessWidget {
  const _MonthChart({required this.buckets, required this.lang});

  final List<MonthBucket> buckets;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (buckets.isEmpty) return const SizedBox.shrink();
    final max = buckets.map((b) => b.total).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final bucket in buckets)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${bucket.total}',
                      style: MorphType.numeric(colors.inkSoft, size: 10),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 26,
                      height: (100 * bucket.total / max)
                          .clamp(4, 100)
                          .toDouble(),
                      decoration: BoxDecoration(
                        color: colors.secondary.withValues(alpha: 0.5),
                        border: Border.all(color: colors.secondary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat.MMM(
                        lang,
                      ).format(DateTime(bucket.year, bucket.month)),
                      style: MorphType.numeric(colors.inkFaint, size: 9.5),
                    ),
                    Text(
                      '${bucket.uniqueIngredients}',
                      style: MorphType.numeric(colors.inkFaint, size: 9),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AisleSpread extends StatelessWidget {
  const _AisleSpread({required this.spread, required this.lang});

  final Map<String, int> spread;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final entries = spread.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in entries)
          InkChip(
            label:
                '${state.repository.ingredients.aisleLabel(entry.key)(lang)}  ${entry.value}',
            dense: true,
            tone: colors.mustard,
          ),
      ],
    );
  }
}
