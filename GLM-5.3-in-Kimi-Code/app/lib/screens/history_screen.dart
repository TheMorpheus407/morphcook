/// Cooking history, time-based pagination (7 weeks/page), grouped by week.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/stores.dart';
import '../l10n.dart';
import '../logic/mealplan.dart';
import '../logic/pagination.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'dish_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late PaginationController<MapEntry<CookHistoryEntry, int>> _pager;

  @override
  void initState() {
    super.initState();
    _pager =
        PaginationController<MapEntry<CookHistoryEntry, int>>(
      policy: PaginationPolicy.history,
      fetchPage: (cursor) async {
        final app = context.read<AppState>();
        final history = app.history;
        if (history.isEmpty) return const [];
        // group by ISO week, count repeats, order newest first
        final weeks = <String, List<CookHistoryEntry>>{};
        for (final e in history) {
          weeks.putIfAbsent(weekKeyOf(e.cookedAt), () => []).add(e);
        }
        final weekKeys = weeks.keys.toList()
          ..sort((a, b) => b.compareTo(a)); // desc
        final startWeek = int.tryParse(cursor ?? '0') ?? 0;
        final pageWeeks =
            weekKeys.skip(startWeek).take(PaginationPolicy.history.pageSize);
        final rows = <MapEntry<CookHistoryEntry, int>>[];
        for (final wk in pageWeeks) {
          final entries = weeks[wk]!;
          // per-recipe count within the week (keep first occurrence order)
          final seen = <String, int>{};
          final order = <String>[];
          for (final e in entries) {
            if (!seen.containsKey(e.recipeId)) order.add(e.recipeId);
            seen[e.recipeId] = (seen[e.recipeId] ?? 0) + 1;
          }
          for (final rid in order) {
            final first =
                entries.firstWhere((e) => e.recipeId == rid);
            rows.add(MapEntry(first, seen[rid]!));
          }
        }
        return rows;
      },
    );
    _pager.refresh();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;

    return Scaffold(
      appBar: AppBar(title: Text(L.t(lang, 'hsTitle'))),
      body: PaperGrain(
        child: AnimatedBuilder(
          animation: _pager,
          builder: (context, _) {
            if (_pager.items.isEmpty) {
              return ListView(padding: const EdgeInsets.all(30), children: [
                const SizedBox(height: 40),
                HandNote(text: L.t(lang, 'hsEmpty')),
                const SizedBox(height: 12),
                Text(
                  L.t(lang, 'hsEmptyBody'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: AppTheme.display,
                      fontSize: 15,
                      height: 1.5,
                      color: AppTheme.inkSoft),
                ),
              ]);
            }
            // rebuild grouped headers
            final rows = _pager.items;
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              itemCount: rows.length + 1,
              itemBuilder: (context, i) {
                if (i == rows.length) {
                  if (_pager.status == PageStatus.loadingMore) {
                    return const Center(
                        child: Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.inkFaint)),
                    ));
                  }
                  return const SizedBox(height: 10);
                }
                if (_pager.shouldLoadMore(i)) _pager.loadMore();
                final row = rows[i];
                final recipe = app.recipe(row.key.recipeId);
                final weekOfThis = weekKeyOf(row.key.cookedAt);
                final showHeader = i == 0 ||
                    weekKeyOf(rows[i - 1].key.cookedAt) != weekOfThis;
                final dish = recipe == null ? null : app.dish(recipe.dishId);
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (showHeader) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Text(
                        L.f(lang, 'hsWeek', {
                          'date':
                              '${row.key.cookedAt.day}.${row.key.cookedAt.month}.'
                        }),
                        style: const TextStyle(
                            fontFamily: AppTheme.mono,
                            fontSize: 10,
                            letterSpacing: 1.8,
                            color: AppTheme.inkFaint),
                      ),
                    ),
                    const DashedRule(),
                    const SizedBox(height: 8),
                  ],
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: dish == null
                        ? null
                        : SizedBox(
                            width: 46,
                            height: 46,
                            child: StripedPlate(
                                color: dish.color, caption: '', height: 46),
                          ),
                    title: Text(
                      dish?.canonicalName.get(lang) ?? row.key.recipeId,
                      style: const TextStyle(
                          fontFamily: AppTheme.hand,
                          fontSize: 20,
                          color: AppTheme.ink),
                    ),
                    subtitle: recipe == null
                        ? null
                        : Text(
                            recipe.title.get(lang),
                            style: const TextStyle(
                                fontFamily: AppTheme.mono,
                                fontSize: 9.5,
                                color: AppTheme.inkFaint),
                          ),
                    trailing: Text(
                      row.value == 1
                          ? L.t(lang, 'hsNever')
                          : L.f(lang, 'hsTimes', {'n': '${row.value}'}),
                        style: const TextStyle(
                            fontFamily: AppTheme.mono,
                            fontSize: 10,
                            color: AppTheme.teal),
                      ),
                    onTap: dish == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => DishScreen(dishId: dish.id))),
                  ),
                ]);
              },
            );
          },
        ),
      ),
    );
  }
}
