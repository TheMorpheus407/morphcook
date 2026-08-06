import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/week.dart';
import '../../data/corpus_repository.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../dish/dish_screen.dart';
import '../widgets.dart';

/// Cooking history, time-based pagination: grouped by week, the newest
/// 7 weeks load first, one more week prefetches near the end, and never
/// more than 50 entries render.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _initialWeeks = 7;
  static const _prefetchWeeks = 1;
  static const _maxRendered = 50;

  int _weeksShown = _initialWeeks;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final s = app.strings;

    final entries = library.historyEntries();
    final now = DateTime.now();
    final cutoff = mondayOf(now).subtract(Duration(days: 7 * (_weeksShown - 1)));

    final visible = entries.where((e) => !e.at.isBefore(cutoff)).toList();
    final rendered = visible.take(_maxRendered).toList();
    final hasMore = visible.length > rendered.length ||
        entries.length > visible.length;

    // Group by ISO week, newest first.
    final groups = <String, List<({String recipeId, DateTime at})>>{};
    for (final e in rendered) {
      groups.putIfAbsent(isoWeekKey(e.at), () => []).add(e);
    }
    final weekKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return PaperGrain(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text('←',
                          style: Type.mono(size: 16, color: Paper.inkSoft)),
                    ),
                    const SizedBox(width: 14),
                    Text(s.get('history'),
                        style: Type.displayBold(size: 26)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: DashedLine(),
              ),
              Expanded(
                child: rendered.isEmpty
                    ? EmptyNote(title: s.get('empty'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: weekKeys.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= weekKeys.length) {
                            // Prefetch threshold: one week from the end.
                            if (_weeksShown < 52) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() =>
                                      _weeksShown += _prefetchWeeks);
                                }
                              });
                            }
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(s.get('loading'),
                                  style: Type.mono(
                                      size: 10, color: Paper.inkFaint)),
                            );
                          }
                          final week = weekKeys[index];
                          final items = groups[week]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 10, bottom: 4),
                                child: Text('${s.get('week')} $week',
                                    style: Type.label(color: Paper.coral)),
                              ),
                              for (final entry in items)
                                _HistoryRow(
                                  recipeId: entry.recipeId,
                                  at: entry.at,
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String recipeId;
  final DateTime at;
  const _HistoryRow({required this.recipeId, required this.at});

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<CorpusRepository>();
    final lang = context.watch<AppModel>().lang;
    final recipe = corpus.recipe(recipeId);
    final dish = recipe == null ? null : corpus.dish(recipe.dishId);

    return GestureDetector(
      onTap: recipe == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DishScreen(
                  dishId: recipe.dishId,
                  initialRecipeId: recipe.id,
                ),
              )),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Paper.white,
          border: Border.all(color: Paper.rule),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 30,
              color: StripedPlaceholder.parseHex(
                  dish?.stripeColor ?? '#C2703F'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe == null ? recipeId : tx(recipe.title, lang),
                      style: Type.mono(size: 12)),
                  Text(
                    '${at.day}.${at.month}.${at.year} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                    style: Type.mono(size: 9.5, color: Paper.inkFaint),
                  ),
                ],
              ),
            ),
            Text('→', style: Type.mono(size: 12, color: Paper.inkSoft)),
          ],
        ),
      ),
    );
  }
}
