import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import 'widgets.dart';

const _monthsEn = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun',
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
const _monthsDe = [
  'jan', 'feb', 'mär', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'dez',
];

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(L10n.tInsights),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: svc.state,
        builder: (context, _) {
          final events = svc.state.shoppingEvents;
          if (events.isEmpty) {
            return _empty(context, t);
          }
          return SingleChildScrollView(
            child: Center(
              child: ZinePage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _varietySection(context, svc, events, lang, t),
                    _uniqueSection(context, svc, events, lang, t),
                    _seasonalSection(context, events, lang, t),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, String Function(String) t) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ZinePage(
          child: Column(
            children: [
              Text(
                t(L10n.tInsightsEmpty),
                textAlign: TextAlign.center,
                style: AppText.serif(context, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                t(L10n.tCookMore),
                textAlign: TextAlign.center,
                style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _varietySection(BuildContext context, Services svc,
      List<Map<String, dynamic>> events, String lang,
      String Function(String) t) {
    final unique = svc.state.uniqueIngredients(svc.corpus.recipeById);
    final distinctRecipes = events
        .map((e) => e['recipe_id'] as String)
        .toSet()
        .length;
    final aisleCounts = <String, int>{};
    for (final id in unique) {
      final node = svc.corpus.ingredientsById[id];
      final aisle = node?.aisle ?? id;
      aisleCounts[aisle] = (aisleCounts[aisle] ?? 0) + 1;
    }
    final top = aisleCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(10).toList();
    final maxCount = shown.isEmpty ? 1 : shown.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: t(L10n.tVariety),
          trailing: Text(
            '${unique.length}',
            style: AppText.serif(context, size: 24, weight: FontWeight.w800),
          ),
        ),
        Text(
          t(L10n.tVarietyLine)
              .replaceFirst('{a}', '${unique.length}')
              .replaceFirst('{b}', '$distinctRecipes'),
          style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < shown.length; i++)
          ZebraRow(
            index: i,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    svc.corpus.labelOf(shown[i].key, lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.mono(context, size: 9),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 10,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width:
                          (shown[i].value / maxCount) * 130,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${shown[i].value}',
                  style: AppText.mono(context, size: 9, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        const DottedDivider(),
      ],
    );
  }

  Widget _uniqueSection(BuildContext context, Services svc,
      List<Map<String, dynamic>> events, String lang,
      String Function(String) t) {
    final perRecipe = <String, int>{};
    for (final e in events) {
      final rid = e['recipe_id'] as String;
      perRecipe[rid] = (perRecipe[rid] ?? 0) + 1;
    }
    final top = perRecipe.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tUniqueAdded)),
        for (var i = 0; i < shown.length; i++)
          ZebraRow(
            index: i,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _recipeName(svc, shown[i].key, lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serif(context, size: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${shown[i].value}×',
                  style: AppText.mono(context, size: 11, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        const DottedDivider(),
      ],
    );
  }

  String _recipeName(Services svc, String recipeId, String lang) {
    final recipe = svc.corpus.recipeById(recipeId);
    if (recipe == null) return recipeId;
    final dish = svc.corpus.dishById(recipe.dishId);
    if (dish != null) {
      return dish.canonicalName[lang]?.toString() ??
          dish.canonicalName['en']?.toString() ??
          dish.id;
    }
    return recipe.title[lang]?.toString() ??
        recipe.title['en']?.toString() ??
        recipeId;
  }

  Widget _seasonalSection(BuildContext context,
      List<Map<String, dynamic>> events, String lang,
      String Function(String) t) {
    final now = DateTime.now();
    final current = now.year * 12 + (now.month - 1);
    final counts = <int, int>{};
    for (final e in events) {
      final dt =
          DateTime.tryParse(e['at'] as String? ?? '') ?? now;
      final idx = dt.year * 12 + (dt.month - 1);
      counts[idx] = (counts[idx] ?? 0) + 1;
    }
    final labels = lang == 'de' ? _monthsDe : _monthsEn;
    final months = <(String, int)>[];
    var maxCount = 1;
    for (var i = 11; i >= 0; i--) {
      final idx = current - i;
      final count = counts[idx] ?? 0;
      if (count > maxCount) maxCount = count;
      months.add((labels[idx % 12], count));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tSeasonal)),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (label, count) in months)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('$count',
                          style: AppText.mono(
                              context, size: 8, color: AppColors.inkFaint)),
                      const SizedBox(height: 2),
                      Container(
                        height: (count / maxCount * 80).clamp(3, 80),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(
                              alpha: 0.35 + (count / maxCount) * 0.55),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label,
                          style: AppText.mono(context,
                              size: 8, color: AppColors.inkSoft)),
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
