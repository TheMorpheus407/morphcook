import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models.dart';
import '../../core/pagination.dart';
import '../../core/shopping.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dish_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryWeek {
  final DateTime monday;
  final List<CookingRecord> records;
  _HistoryWeek(this.monday, this.records);
}

class _HistoryScreenState extends State<HistoryScreen> {
  PaginationController<_HistoryWeek>? pages;
  int count = -1;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    pages ??= PaginationController(
      type: PaginationType.time,
      pageSize: 7,
      prefetchThreshold: 1,
      loader: (cursor, limit) async {
        final grouped = <DateTime, List<CookingRecord>>{};
        final history = [...state.history]
          ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
        for (final record in history) {
          grouped.putIfAbsent(mondayOf(record.cookedAt), () => []).add(record);
        }
        final weeks = grouped.entries
            .map((e) => _HistoryWeek(e.key, e.value))
            .toList();
        final page = offsetPage(weeks, cursor, limit);
        await state.repository.loadRecipeIds(
          page.items.expand((w) => w.records.map((r) => r.recipeId)),
        );
        return page;
      },
    );
    if (count != state.history.length) {
      count = state.history.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) pages!.refresh();
      });
    }
  }

  @override
  void dispose() {
    pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return PaperScaffold(
      appBar: KitchenAppBar(title: t(context, 'history')),
      body: Column(
        children: [
          PageHeading(
            title: t(context, 'history'),
            subtitle: t(context, 'historySubtitle'),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: pages!,
              builder: (context, _) {
                if (pages!.items.isEmpty &&
                    !pages!.loading &&
                    !pages!.hasMore) {
                  return EmptyPaper(
                    title: t(context, 'history'),
                    body: t(context, 'emptyHistory'),
                    icon: Icons.history,
                  );
                }
                // Flatten week sections so a busy week still disposes off-screen rows.
                final rows = <Object>[];
                for (final week in pages!.items) {
                  rows.add(week.monday);
                  rows.addAll(week.records);
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  cacheExtent: 100,
                  addAutomaticKeepAlives: false,
                  itemBuilder: (context, index) {
                    if (index > rows.length) return null;
                    if (index == rows.length) {
                      if (pages!.loading) return const RecipeSkeleton();
                      if (pages!.error != null || pages!.hasMore) {
                        return TextButton(
                          onPressed: pages!.loadMore,
                          child: Text(t(context, 'loadMore')),
                        );
                      }
                      return const SizedBox(height: 24);
                    }
                    if (index >= rows.length - 10 &&
                        pages!.shouldLoadMore(pages!.items.length - 1)) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => pages!.loadMore(),
                      );
                    }
                    final row = rows[index];
                    if (row is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 12),
                        child: Text(
                          DateFormat(
                            'd MMM yyyy',
                            state.profile.lang,
                          ).format(row),
                          style: hand(25),
                        ),
                      );
                    }
                    final record = row as CookingRecord;
                    final recipe = state.repository.recipes[record.recipeId];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        recipe == null
                            ? t(context, 'archivedRecipe')
                            : textFor(context, recipe.title),
                        style: serif(18, italic: true),
                      ),
                      subtitle: Text(
                        '${DateFormat('EEE d MMM', state.profile.lang).format(record.cookedAt)} · ${t(context, 'servings', {'count': record.servings})}',
                        style: mono(10),
                      ),
                      trailing: recipe == null
                          ? null
                          : const Icon(Icons.arrow_forward, size: 18),
                      onTap: recipe == null
                          ? null
                          : () => openRecipe(context, recipe),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
