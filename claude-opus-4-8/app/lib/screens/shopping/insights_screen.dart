import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/paper_background.dart';

/// Quiet analytics drawn from what you've actually cooked and what's on your
/// list right now: how varied your pantry is, what you reach for most, and how
/// your cooking spreads across the months.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final history = scope.services.history;
    final shopping = scope.services.shopping;
    final corpus = scope.corpus;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.paper.withValues(alpha: 0.9),
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          context.tr('insights.title'),
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            fontSize: 24,
            color: AppColors.ink,
          ),
        ),
      ),
      body: PaperBackground(
        child: ListenableBuilder(
          listenable: Listenable.merge([history, shopping]),
          builder: (context, _) {
            final historyEntries = history.entries();
            final selections = shopping.selections();

            if (historyEntries.isEmpty && selections.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: HandNote(context.tr('insights.empty'), size: 22),
                ),
              );
            }

            // Recipes that count toward the analytics: every cooked recipe plus
            // everything currently on the list.
            final contributing = <Recipe>[];
            for (final e in historyEntries) {
              final r = corpus.recipe(e.recipeId);
              if (r != null) contributing.add(r);
            }
            for (final s in selections) {
              final r = corpus.recipe(s.recipeId);
              if (r != null) contributing.add(r);
            }

            // Variety: unique ingredient ids.
            final uniqueIngredients = <String>{};
            for (final r in contributing) {
              uniqueIngredients.addAll(r.ingredientIds);
            }

            // Frequency of each ingredient id.
            final freq = <String, int>{};
            for (final r in contributing) {
              for (final id in r.ingredientIds) {
                freq[id] = (freq[id] ?? 0) + 1;
              }
            }
            final topIngredients = freq.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final top = topIngredients.take(8).toList();

            // A representative localized name per ingredient id: scan recipes
            // for a RecipeIngredient carrying it, else fall back to the dict.
            LocalizedText? nameFor(String id) {
              for (final r in contributing) {
                for (final ing in r.ingredients) {
                  if (ing.ingredientId == id) return ing.name;
                }
              }
              return corpus.ingredients.node(id)?.label;
            }

            // Seasonal: cooked counts per (year, month).
            final monthly = <DateTime, int>{};
            for (final e in historyEntries) {
              final key = DateTime(e.cookedAt.year, e.cookedAt.month);
              monthly[key] = (monthly[key] ?? 0) + 1;
            }
            final months = monthly.keys.toList()..sort((a, b) => a.compareTo(b));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              children: [
                _VarietyBlock(count: uniqueIngredients.length),
                const SizedBox(height: 20),
                DashedRule(withAmpersand: true),
                const SizedBox(height: 16),
                if (top.isNotEmpty) ...[
                  MonoLabel(context.tr('insights.top'), color: AppColors.terracotta),
                  const SizedBox(height: 12),
                  for (final entry in top)
                    _BarRow(
                      label: _resolveName(context, nameFor(entry.key), entry.key),
                      value: entry.value,
                      max: top.first.value,
                      color: AppColors.terracotta,
                    ),
                  const SizedBox(height: 20),
                  DashedRule(),
                  const SizedBox(height: 16),
                ],
                if (months.isNotEmpty) ...[
                  MonoLabel(context.tr('insights.seasonal'), color: AppColors.sage),
                  const SizedBox(height: 12),
                  for (final m in months)
                    _BarRow(
                      label: _monthLabel(context, m),
                      value: monthly[m]!,
                      max: monthly.values.reduce((a, b) => a > b ? a : b),
                      color: AppColors.sage,
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _resolveName(BuildContext context, LocalizedText? name, String fallbackId) {
    if (name != null) return context.loc(name);
    return fallbackId;
  }

  String _monthLabel(BuildContext context, DateTime m) {
    final code = context.lang.code;
    final month = DateFormat.MMM(code).format(m);
    return '${month.toLowerCase()} ${m.year}';
  }
}

class _VarietyBlock extends StatelessWidget {
  const _VarietyBlock({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(context.tr('insights.variety'), color: AppColors.terracotta),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 72,
                color: AppColors.ink,
                height: 1.0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('insights.variety_sub'),
                style: const TextStyle(
                  fontFamily: Fonts.hand,
                  fontSize: 22,
                  color: AppColors.clay,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });
  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$value',
                style: const TextStyle(
                  fontFamily: Fonts.mono,
                  fontSize: 12,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 6,
                    width: constraints.maxWidth,
                    decoration: BoxDecoration(
                      color: AppColors.inkFaint.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Container(
                    height: 6,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
