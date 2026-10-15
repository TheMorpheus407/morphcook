import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/history_entry.dart';
import '../models/recipe.dart';
import '../services/matching_engine.dart';
import '../services/pagination_controller.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'dish_detail_screen.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  int _activeTab = 0; // 0: Saved Variants (Cookbook), 1: Cooking History
  late PaginationController<Recipe> _savedPagination;
  late PaginationController<CookHistoryEntry> _historyPagination;

  @override
  void initState() {
    super.initState();
    _savedPagination = PaginationController<Recipe>.cookbook(
      fetcher: _fetchSavedPage,
    );
    _historyPagination = PaginationController<CookHistoryEntry>.history(
      fetcher: _fetchHistoryPage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savedPagination.refresh();
      _historyPagination.refresh();
    });
  }

  @override
  void dispose() {
    _savedPagination.dispose();
    _historyPagination.dispose();
    super.dispose();
  }

  Future<PaginatedPageResult<Recipe>> _fetchSavedPage({
    required int pageIndex,
    required int offset,
    required int pageSize,
    String? cursor,
  }) async {
    final appState = context.read<MorphCookAppState>();
    await appState.corpus.ensureAllPartitionsLoaded();
    final allSaved = appState.savedRecipes;
    if (offset >= allSaved.length) {
      return const PaginatedPageResult(items: [], hasMore: false);
    }
    final end = (offset + pageSize).clamp(0, allSaved.length);
    return PaginatedPageResult(
      items: allSaved.sublist(offset, end),
      hasMore: end < allSaved.length,
    );
  }

  Future<PaginatedPageResult<CookHistoryEntry>> _fetchHistoryPage({
    required int pageIndex,
    required int offset,
    required int pageSize,
    String? cursor,
  }) async {
    final appState = context.read<MorphCookAppState>();
    await appState.corpus.ensureAllPartitionsLoaded();
    final allHistory = appState.history;
    // Time-based pagination: 7 weeks per page (or up to 50 items)
    final chunkSize = pageSize * 5;
    if (offset >= allHistory.length) {
      return const PaginatedPageResult(items: [], hasMore: false);
    }
    final end = (offset + chunkSize).clamp(0, allHistory.length);
    return PaginatedPageResult(
      items: allHistory.sublist(offset, end),
      hasMore: end < allHistory.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';

    return PaperGrainBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDe ? 'mein persönliches kochbuch' : 'my saved cookbook',
                  style: NostalgicTheme.serifDisplay(fontSize: 26),
                ),
                const SizedBox(height: 4),
                Text(
                  isDe
                      ? 'Du speicherst immer deine spezifische Rezept-Variante — deinen Döner, deine Alfredo.'
                      : 'You save your specific recipe variant—your Döner, your Alfredo.',
                  style: NostalgicTheme.handwritten(
                    fontSize: 18,
                    color: NostalgicPalette.fadedInk,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      key: const ValueKey('cookbook_tab_saved'),
                      selected: _activeTab == 0,
                      label: Text(
                        isDe
                            ? 'Gespeicherte Varianten (${appState.savedRecipeIds.length})'
                            : 'Saved Variants (${appState.savedRecipeIds.length})',
                      ),
                      onSelected: (_) {
                        setState(() => _activeTab = 0);
                        _savedPagination.refresh();
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      key: const ValueKey('cookbook_tab_history'),
                      selected: _activeTab == 1,
                      label: Text(
                        isDe
                            ? 'Koch-Tagebuch (${appState.history.length})'
                            : 'Cooking History (${appState.history.length})',
                      ),
                      onSelected: (_) {
                        setState(() => _activeTab = 1);
                        _historyPagination.refresh();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: DashedRule(),
          ),
          Expanded(
            child: _activeTab == 0
                ? _buildSavedList(appState, lang, isDe)
                : _buildHistoryList(appState, lang, isDe),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedList(MorphCookAppState appState, String lang, bool isDe) {
    final saved = appState.savedRecipes;
    if (saved.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isDe
                ? 'Noch keine Variante gespeichert. Tippe auf das Lesezeichen bei einem Gericht, um genau deine Variante zu sichern.'
                : 'No saved variants yet. Tap the bookmark on any dish to save your exact variant.',
            textAlign: TextAlign.center,
            style: NostalgicTheme.serifBody(
              fontSize: 15.5,
              color: NostalgicPalette.fadedInk,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: saved.length,
      itemBuilder: (context, index) {
        if (_savedPagination.shouldLoadMore(index)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _savedPagination.loadMore();
          });
        }
        final recipe = saved[index];
        final dish = appState.corpus.dishById(recipe.dishId);
        return Container(
          key: ValueKey('saved_variant_${recipe.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: NostalgicPalette.cardStock,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: NostalgicPalette.mutedRule),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            title: Text(
              recipe.title.resolve(lang),
              style: NostalgicTheme.serifDisplay(fontSize: 18.5),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'ID: ${recipe.id}  ·  ${recipe.dietDimension}  ·  ${recipe.effort}  ·  ~${recipe.caloriesPerServing} kcal',
                style: NostalgicTheme.mono(
                  fontSize: 11,
                  color: NostalgicPalette.terracotta,
                ),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.bookmark_remove_outlined,
                color: NostalgicPalette.terracotta,
              ),
              onPressed: () => appState.toggleSaveRecipe(recipe.id),
            ),
            onTap: () {
              if (dish != null) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DishDetailScreen(
                      dish: dish,
                      initialRecipe: recipe,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(MorphCookAppState appState, String lang, bool isDe) {
    final history = appState.history;
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            isDe
                ? 'Dein Koch-Tagebuch ist noch leer. Schließe ein Rezept im Kochmodus ab!'
                : 'Your cooking history is empty. Finish a recipe in Cook Mode to stamp it here!',
            textAlign: TextAlign.center,
            style: NostalgicTheme.serifBody(
              fontSize: 15.5,
              color: NostalgicPalette.fadedInk,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      itemCount: history.length,
      itemBuilder: (context, index) {
        if (_historyPagination.shouldLoadMore(index)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _historyPagination.loadMore();
          });
        }
        final entry = history[index];
        final recipe = appState.corpus.recipeById(entry.recipeId);
        final dish = appState.corpus.dishById(entry.dishId);
        final weekHeader = MorphCookAppState.isoWeekKey(entry.cookedAt);
        final prevHeader = index > 0
            ? MorphCookAppState.isoWeekKey(history[index - 1].cookedAt)
            : null;
        final showHeader = weekHeader != prevHeader;
        final stalenessBonus = MatchingEngine.calculateStalenessBonus(
          entry.cookedAt,
          appState.now,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: DashedRule(label: 'week $weekHeader'),
              ),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: NostalgicPalette.cardStock,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: NostalgicPalette.mutedRule),
              ),
              child: ListTile(
                title: Text(
                  recipe?.title.resolve(lang) ?? entry.recipeId,
                  style: NostalgicTheme.serifDisplay(fontSize: 17.5),
                ),
                subtitle: Text(
                  '${entry.cookedAt.toIso8601String().split("T").first}  ·  ${entry.servingsCooked} ${isDe ? "Portionen" : "servings"}'
                  '${stalenessBonus > 0 ? (isDe ? "  ·  +50 Wiederentdeckungs-Bonus" : "  ·  +50 rediscovery boost") : ""}',
                  style: NostalgicTheme.mono(
                    fontSize: 11,
                    color: stalenessBonus > 0
                        ? NostalgicPalette.sage
                        : NostalgicPalette.fadedInk,
                  ),
                ),
                onTap: () {
                  if (dish != null && recipe != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DishDetailScreen(
                          dish: dish,
                          initialRecipe: recipe,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
