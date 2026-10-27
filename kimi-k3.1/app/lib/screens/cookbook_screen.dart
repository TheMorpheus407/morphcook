import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../models/user_data.dart';
import '../services/pagination.dart';
import '../state/app_state.dart';
import '../widgets/paper_widgets.dart';
import '../widgets/recipe_card.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({
    super.key,
    required this.onOpenRecipe,
    required this.onHistory,
  });
  final void Function(Dish dish, Recipe recipe) onOpenRecipe;
  final VoidCallback onHistory;

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  late final AppState app;
  late final PaginationController<Recipe> pages;
  String savedSignature = '';

  @override
  void initState() {
    super.initState();
    app = context.read<AppState>();
    savedSignature = signature;
    pages = PaginationController<Recipe>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      useOffset: true,
      loader: loadPage,
    )..addListener(listener);
    app.addListener(onAppChanged);
    pages.loadMore();
  }

  String get signature =>
      app.snapshot.saved.map((item) => item.recipeId).join('|');

  Future<PaginationPage<Recipe>> loadPage(String? cursor, int offset) async {
    final sorted = [...app.snapshot.saved]
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    final end = (offset + 30).clamp(0, sorted.length);
    final ids = offset >= sorted.length
        ? <String>[]
        : sorted.sublist(offset, end).map((item) => item.recipeId);
    final recipes = <Recipe>[];
    for (final id in ids) {
      await app.repository.ensureRecipe(id);
      final recipe = app.repository.recipes[id];
      if (recipe != null) recipes.add(recipe);
    }
    return PaginationPage(items: recipes, offset: offset);
  }

  void onAppChanged() {
    if (savedSignature == signature) return;
    savedSignature = signature;
    pages.refresh();
  }

  void listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    app.removeListener(onAppChanged);
    pages
      ..removeListener(listener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      body: Paper(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 14, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SectionHeading(
                        context.l10n.t('cookbook_title'),
                        kicker: context.l10n.t('nav_cookbook').toUpperCase(),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onHistory,
                      icon: const Icon(Icons.history),
                      tooltip: context.l10n.t('history'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: !pages.initialized && pages.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: LoadingList(),
                      )
                    : pages.error != null &&
                          pages.items.isEmpty &&
                          !pages.isLoading
                    ? EmptyState(
                        title: context.l10n.t('list_error'),
                        body: context.l10n.t('cookbook_empty_body'),
                        action: OutlinedButton(
                          onPressed: pages.loadMore,
                          child: Text(context.l10n.t('retry')),
                        ),
                      )
                    : pages.items.isEmpty && !pages.isLoading
                    ? EmptyState(
                        title: context.l10n.t('cookbook_empty'),
                        body: context.l10n.t('cookbook_empty_body'),
                      )
                    : RefreshIndicator(
                        onRefresh: pages.refresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                          itemCount:
                              pages.items.length +
                              (pages.hasMore || pages.isLoading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= pages.items.length) {
                              Future.microtask(pages.loadMore);
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                  ),
                                ),
                              );
                            }
                            if (pages.shouldLoadMore(index)) {
                              Future.microtask(pages.loadMore);
                            }
                            final recipe = pages.items[index];
                            final dish = app.repository.dishes[recipe.dishId]!;
                            return RecipeListTile(
                              dish: dish,
                              recipe: recipe,
                              onTap: () => widget.onOpenRecipe(dish, recipe),
                              trailing: IconButton(
                                onPressed: () => app.toggleSaved(recipe.id),
                                icon: const Icon(Icons.bookmark),
                                tooltip: context.l10n.t('saved_variant'),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.onOpenRecipe});
  final void Function(Dish dish, Recipe recipe) onOpenRecipe;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final AppState app;
  late final HistoryPaginationController<HistoryEntry> pages;
  final Set<DateTime> loadedStarts = {};
  bool preparing = true;

  @override
  void initState() {
    super.initState();
    app = context.read<AppState>();
    pages = HistoryPaginationController<HistoryEntry>(loader: loadWeeks)
      ..addListener(listener);
    prepare();
  }

  Future<void> prepare() async {
    for (final entry in app.snapshot.history) {
      await app.repository.ensureRecipe(entry.recipeId);
    }
    if (!mounted) return;
    setState(() => preparing = false);
    pages.loadMore();
  }

  List<HistoryWeek<HistoryEntry>> loadWeeks(DateTime before, int count) {
    final candidates = <DateTime, List<HistoryEntry>>{};
    final cutoff = mondayForWeek(before);
    for (final entry in app.snapshot.history) {
      final start = mondayForWeek(entry.cookedAt.toLocal());
      if (start.isAfter(cutoff) || loadedStarts.contains(start)) continue;
      candidates.putIfAbsent(start, () => []).add(entry);
    }
    final starts = candidates.keys.toList()..sort((a, b) => b.compareTo(a));
    final result = starts.take(count).map((start) {
      loadedStarts.add(start);
      final entries = candidates[start]!
        ..sort((a, b) => b.cookedAt.compareTo(a.cookedAt));
      return HistoryWeek(start: start, items: entries);
    }).toList();
    return result;
  }

  void listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    pages
      ..removeListener(listener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = <Object>[
      for (final week in pages.weeks) ...[week.start, ...week.items],
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('history'))),
      body: Paper(
        child: preparing
            ? const LoadingList()
            : entries.isEmpty
            ? EmptyState(
                title: context.l10n.t('history_empty'),
                body: context.l10n.t('cook_complete_body'),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: entries.length + (pages.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= entries.length) {
                    Future.microtask(pages.loadMore);
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    );
                  }
                  var weekIndex = 0;
                  var cursor = 0;
                  for (final week in pages.weeks) {
                    if (index <= cursor + week.items.length) {
                      break;
                    }
                    cursor += week.items.length + 1;
                    weekIndex++;
                  }
                  if (pages.shouldLoadMore(weekIndex)) {
                    Future.microtask(pages.loadMore);
                  }
                  final item = entries[index];
                  if (item is DateTime) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 9),
                      child: SectionHeading(
                        DateFormat('MMMM y', context.lang).format(item),
                        kicker: DateFormat('d MMMM', context.lang).format(item),
                      ),
                    );
                  }
                  final history = item as HistoryEntry;
                  final recipe = app.repository.recipes[history.recipeId];
                  if (recipe == null) return const SizedBox.shrink();
                  return RecipeListTile(
                    dish: app.repository.dishes[recipe.dishId]!,
                    recipe: recipe,
                    subtitle: context.l10n.t('cooked_on', {
                      'date': DateFormat.yMMMd(
                        context.lang,
                      ).add_Hm().format(history.cookedAt.toLocal()),
                    }),
                    onTap: () => widget.onOpenRecipe(
                      app.repository.dishes[recipe.dishId]!,
                      recipe,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
