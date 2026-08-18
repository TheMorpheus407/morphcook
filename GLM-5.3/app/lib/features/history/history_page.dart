import 'package:flutter/material.dart' hide Page;
import 'package:provider/provider.dart';

import '../../core/models/user_data.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/paper.dart';
import '../../core/util/dates.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';

/// Cooking history ("the ledger"): time-based pagination grouped by ISO
/// week, 7 weeks per page, prefetch at 1 week, max 50 rendered items.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final PaginationController<HistoryEntry> _pager;
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>();
    _pager = PaginationController<HistoryEntry>(
      pageSize: 7, // 7 week-buckets per page (time-based pagination, SPEC)
      prefetchThreshold: 7,
      maxItems: 50,
      fetch: _fetchPage,
    );
    _pager.loadMore();
  }

  Future<Page<HistoryEntry>> _fetchPage(String? cursor) async {
    // Group history into week buckets from newest backwards; the cursor is
    // the number of week-buckets already served.
    final entries = _state.historyNewestFirst;
    final buckets = <String, List<HistoryEntry>>{};
    final order = <String>[];
    for (final entry in entries) {
      final key = IsoWeek.keyOf(entry.at);
      if (!buckets.containsKey(key)) {
        buckets[key] = [];
        order.add(key);
      }
      buckets[key]!.add(entry);
    }
    final served = int.tryParse(cursor ?? '0') ?? 0;
    final weekSlice = order.skip(served).take(7).toList();
    final items = <HistoryEntry>[];
    for (final week in weekSlice) {
      items.addAll(buckets[week]!);
    }
    final next = served + weekSlice.length;
    return Page(
      items: items,
      nextCursor: next < order.length ? '$next' : null,
    );
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    return PaperScaffold(
      seed: 71,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('morphcook', style: AppFonts.display(size: 20)),
      ),
      body: state.history.isEmpty
          ? Center(
              child: Text(context.tr('hist.empty'),
                  style: AppFonts.serif(size: 15, color: AppColors.inkSoft)),
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels >=
                    notification.metrics.maxScrollExtent - 200) {
                  _pager.loadMore();
                }
                return false;
              },
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
                itemCount: _pager.items.length,
                itemBuilder: (context, index) {
                  final entry = _pager.items[index];
                  final showHeader = index == 0 ||
                      IsoWeek.keyOf(entry.at) !=
                          IsoWeek.keyOf(_pager.items[index - 1].at);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showHeader)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
                          child: Text(
                            _weekTitle(entry, lang),
                            style: AppFonts.mono(
                                size: 10, color: AppColors.coral, letterSpacing: 1.4),
                          ),
                        ),
                      _historyRow(context, state, entry, lang),
                    ],
                  );
                },
              ),
            ),
    );
  }

  String _weekTitle(HistoryEntry entry, String lang) {
    final key = IsoWeek.keyOf(entry.at);
    if (key == IsoWeek.current()) return context.trRead('hist.thisWeek').toUpperCase();
    return IsoWeek.label(key, lang).toUpperCase();
  }

  Widget _historyRow(
      BuildContext context, AppState state, HistoryEntry entry, String lang) {
    final recipe = state.recipeForHistory(entry);
    final dish = recipe == null ? null : state.corpus.dishes[recipe.dish];
    if (recipe == null || dish == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () => openDish(context, dish.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        child: Row(
          children: [
            Container(width: 4, height: 32, color: dish.stripeColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.localized(recipe.title),
                style: AppFonts.serif(size: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(DateFmt.dateTime(entry.at, lang),
                    style: AppFonts.mono(size: 9, color: AppColors.inkSoft)),
                const SizedBox(height: 2),
                Text(
                  '${entry.servings}× ${context.trRead('common.servings')}',
                  style: AppFonts.mono(size: 9, color: AppColors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
