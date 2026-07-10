import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/pagination.dart';
import '../../models/collections.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
import '../widgets/recipe_row.dart';

/// The cookbook: saved variants (offset-paginated, 30/page) and the
/// cooking history (time-paginated by week).
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  PaginationController<Recipe>? _savedPager;
  PaginationController<(String, List<HistoryEntry>)>? _historyPager;
  int _savedCount = -1;
  int _historyCount = -1;
  bool _showHistory = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    // Rebuild pagers when the underlying collections change size.
    if (state.saved.length != _savedCount) {
      _savedCount = state.saved.length;
      _rebuildSavedPager(state);
    }
    if (state.history.length != _historyCount) {
      _historyCount = state.history.length;
      _rebuildHistoryPager(state);
    }
  }

  /// Offset-based pagination over saved recipes, newest first.
  void _rebuildSavedPager(AppState state) {
    final saved = state.saved.reversed.toList();
    final old = _savedPager;
    _savedPager = PaginationController<Recipe>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetch: (cursor, pageSize) async {
        final offset = cursor == null ? 0 : int.parse(cursor);
        final slice = saved.skip(offset).take(pageSize).toList();
        final recipes = <Recipe>[];
        for (final entry in slice) {
          final recipe = await state.corpus.recipeById(entry.recipeId);
          if (recipe != null) recipes.add(recipe);
        }
        final next = offset + slice.length;
        return Page(
          items: recipes,
          nextCursor: next < saved.length ? '$next' : null,
        );
      },
    )..loadMore();
    old?.dispose();
  }

  /// Time-based pagination: history grouped by week, 7 weeks per page.
  void _rebuildHistoryPager(AppState state) {
    final entries = state.history.toList()
      ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
    final byWeek = <String, List<HistoryEntry>>{};
    for (final e in entries) {
      byWeek.putIfAbsent(isoWeekKey(e.cookedAt), () => []).add(e);
    }
    final weeks = byWeek.entries.toList();
    final old = _historyPager;
    _historyPager = PaginationController<(String, List<HistoryEntry>)>(
      pageSize: 7,
      prefetchThreshold: 1,
      maxRendered: 50,
      fetch: (cursor, pageSize) async {
        final offset = cursor == null ? 0 : int.parse(cursor);
        final slice = weeks
            .skip(offset)
            .take(pageSize)
            .map((e) => (e.key, e.value))
            .toList();
        // Pull in partitions for recipes referenced by this page.
        for (final (_, entries) in slice) {
          for (final entry in entries) {
            await state.corpus.recipeById(entry.recipeId);
          }
        }
        final next = offset + slice.length;
        return Page(
          items: slice,
          nextCursor: next < weeks.length ? '$next' : null,
        );
      },
    )..loadMore();
    old?.dispose();
  }

  @override
  void dispose() {
    _savedPager?.dispose();
    _historyPager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final morph = MorphTheme.of(context);
    final state = context.watch<AppState>();
    final s = S(state.lang);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(s('yourCookbook'),
                style: morph.text.display.copyWith(fontSize: 30)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
            child: Text(s('cookbookHint'),
                style: morph.text.handAt(17, color: morph.colors.inkSoft)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                MonoChip(
                  label: s('saved'),
                  selected: !_showHistory,
                  onTap: () => setState(() => _showHistory = false),
                ),
                const SizedBox(width: 8),
                MonoChip(
                  label: s('history'),
                  selected: _showHistory,
                  onTap: () => setState(() => _showHistory = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
              child: _showHistory ? _historyList(state, s) : _savedList(s)),
        ],
      ),
    );
  }

  Widget _savedList(S s) {
    final pager = _savedPager;
    if (pager == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: pager,
      builder: (context, _) {
        if (pager.isEmpty) return _empty(s('cookbookEmpty'));
        final items = pager.items;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: items.length + (pager.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (pager.shouldLoadMore(index)) {
              scheduleMicrotask(pager.loadMore);
            }
            if (index >= items.length) return const SkeletonBlock();
            return RecipeRow(recipe: items[index], index: index);
          },
        );
      },
    );
  }

  Widget _historyList(AppState state, S s) {
    final morph = MorphTheme.of(context);
    final pager = _historyPager;
    if (pager == null) return const SizedBox.shrink();
    final lang = state.lang;
    return ListenableBuilder(
      listenable: pager,
      builder: (context, _) {
        if (pager.isEmpty) return _empty(s('historyEmpty'));
        final weeks = pager.items;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: weeks.length + (pager.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (pager.shouldLoadMore(index)) {
              scheduleMicrotask(pager.loadMore);
            }
            if (index >= weeks.length) return const SkeletonBlock();
            final (weekKey, entries) = weeks[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: '${s('week')} $weekKey'),
                for (final entry in entries)
                  Builder(builder: (context) {
                    final recipe =
                        state.corpus.loadedRecipeById(entry.recipeId);
                    if (recipe == null) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Text(
                            '${entry.cookedAt.day}.${entry.cookedAt.month}.',
                            style: morph.text.label(size: 10),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                                morph.cased(recipe.title.of(lang)),
                                style: morph.text.mono
                                    .copyWith(fontSize: 12.5)),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _empty(String text) {
    final morph = MorphTheme.of(context);
    return Center(
      child: Text(text,
          textAlign: TextAlign.center,
          style: morph.text.handAt(20, color: morph.colors.inkSoft)),
    );
  }
}
