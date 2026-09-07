import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/week.dart';
import '../../data/models/history_entry.dart';
import '../../domain/pagination.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../widgets/dish_card.dart';

/// What you actually cooked, seven weeks at a time with week headers.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  PaginationController<HistoryEntry, DateTime>? _controller;
  int _lastCount = -1;
  final Set<String> _loading = {};

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _ensureController(AppController app) {
    if (_controller != null && _lastCount == app.history.length) return;
    _lastCount = app.history.length;
    _controller?.dispose();
    final c = PaginationController<HistoryEntry, DateTime>(
      pageSize: 7,
      prefetchThreshold: 3,
      maxRendered: 50,
      loader: (cursor, weeks) async => timePage(app.history, (e) => e.cookedAt, cursor, weeks, now: app.now),
    );
    _controller = c;
    c.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => c.loadMore());
  }

  /// Flat list: week header rows interleaved with entries.
  List<Object> _rows(List<HistoryEntry> entries) {
    final out = <Object>[];
    String? current;
    for (final e in entries) {
      final key = weekKeyOf(e.cookedAt);
      if (key != current) {
        current = key;
        out.add(key);
      }
      out.add(e);
    }
    return out;
  }

  String _weekTitle(BuildContext context, AppController app, String key) {
    final s = context.s;
    final now = app.now();
    if (key == weekKeyOf(now)) return s('history.thisWeek');
    if (key == shiftWeekKey(weekKeyOf(now), -1)) return s('history.lastWeek');
    final monday = mondayOfWeekKey(key);
    return '${s('history.week', {'n': '${isoWeekNumber(monday)}'})} · ${s.shortDate(monday)}';
  }

  void _ensureRecipe(AppController app, String id) {
    if (app.recipeIfLoaded(id) != null || _loading.contains(id)) return;
    _loading.add(id);
    app.recipe(id).whenComplete(() {
      _loading.remove(id);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    _ensureController(app);
    final controller = _controller!;

    return Scaffold(
      appBar: AppBar(title: Text(s('history.title'))),
      body: app.history.isEmpty
          ? EmptyState(title: s('history.empty.title'), note: s('history.empty.note'), icon: Icons.history)
          : Builder(builder: (context) {
              final rows = _rows(controller.items);
              final entryIndexOf = <int, int>{};
              var n = 0;
              for (var i = 0; i < rows.length; i++) {
                if (rows[i] is HistoryEntry) entryIndexOf[i] = n++;
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: null,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: MonoLabel(s('history.kicker')),
                    );
                  }
                  final i = index - 1;
                  if (i < rows.length) {
                    final row = rows[i];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_weekTitle(context, app, row), style: AppText.title(size: 18, italic: true)),
                            const SizedBox(height: 6),
                            const DashedRule(),
                          ],
                        ),
                      );
                    }
                    final e = row as HistoryEntry;
                    final entryIdx = entryIndexOf[i] ?? 0;
                    if (controller.shouldLoadMore(entryIdx)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
                    }
                    final r = app.recipeIfLoaded(e.recipeId);
                    final d = r == null ? app.dish(e.dishId) : app.dish(r.dishId);
                    if (r == null || d == null) {
                      _ensureRecipe(app, e.recipeId);
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        child: Row(children: [SkeletonBox(height: 54, width: 54), SizedBox(width: 14), Expanded(child: SkeletonBox(height: 15))]),
                      );
                    }
                    return RecipeRowTile(
                      recipe: r,
                      dish: d,
                      subtitle: '${s('history.cooked', {'n': '${app.timesCooked(e.recipeId)}'})} · ${s.shortDate(e.cookedAt)} · ${s.servings(e.servings)}',
                      onTap: () => Routes.openDish(context, d.id, recipeId: r.id),
                    );
                  }
                  if (i == rows.length) {
                    if (controller.isLoading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        child: SkeletonBox(height: 15),
                      );
                    }
                    if (controller.capReached) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: MonoLabel('${s('history.olderNote')} · ${s('search.cap', {'n': '${controller.maxRendered}'})}', color: Palette.inkFaint),
                      );
                    }
                    return null;
                  }
                  return null;
                },
              );
            }),
    );
  }
}
