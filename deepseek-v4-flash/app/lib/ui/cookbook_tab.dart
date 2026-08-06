import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../models/models.dart';
import 'dish_detail.dart';
import 'home_feed.dart';
import 'widgets.dart';

String _dishName(Dish dish, String lang) =>
    dish.canonicalName[lang]?.toString() ??
    dish.canonicalName['en']?.toString() ??
    dish.id;

String _recipeTitle(Recipe recipe, String lang) =>
    recipe.title[lang]?.toString() ??
    recipe.title['en']?.toString() ??
    recipe.id;

class CookbookTab extends StatefulWidget {
  const CookbookTab({super.key});

  @override
  State<CookbookTab> createState() => _CookbookTabState();
}

class _CookbookTabState extends State<CookbookTab> {
  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return ListenableBuilder(
      listenable: svc.state,
      builder: (context, _) {
        final saved = svc.state.savedEntries;
        final history = svc.state.history;
        return SingleChildScrollView(
          child: Center(
            child: ZinePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title: t(L10n.tSavedRecipes)),
                  if (saved.isEmpty)
                    _savedEmpty(context, t)
                  else
                    _savedList(context, svc, saved, lang, t),
                  SectionHeader(
                    title: t(L10n.tCookingHistory),
                    trailing: history.isEmpty
                        ? null
                        : TextButton(
                            onPressed: () => svc.state.clearHistory(),
                            child: Text(t(L10n.tClearHistory),
                                style: AppText.mono(context, size: 10)),
                          ),
                  ),
                  if (history.isEmpty)
                    _historyEmpty(context, t)
                  else
                    _historyList(context, svc, history, lang, t),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _savedEmpty(BuildContext context, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            t(L10n.tCookbookEmpty),
            textAlign: TextAlign.center,
            style: AppText.mono(context, size: 11, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const BrowsePage()),
            ),
            icon: const Icon(Icons.menu_book_outlined, size: 16),
            label: Text(t(L10n.tBrowseAll),
                style: AppText.mono(context, size: 11)),
          ),
        ],
      ),
    );
  }

  Widget _historyEmpty(BuildContext context, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text(
        t(L10n.tHistoryEmpty),
        textAlign: TextAlign.center,
        style: AppText.mono(context, size: 11, color: AppColors.inkSoft),
      ),
    );
  }

  Widget _savedList(
      BuildContext context,
      Services svc,
      List<SavedEntry> saved,
      String lang,
      String Function(String) t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          for (var i = 0; i < saved.length; i++)
            _savedRow(context, svc, saved[i], i, lang, t),
        ],
      ),
    );
  }

  Widget _savedRow(
      BuildContext context,
      Services svc,
      SavedEntry entry,
      int i,
      String lang,
      String Function(String) t) {
    final recipe = svc.corpus.recipeById(entry.recipeId);
    final dish = recipe == null ? null : svc.corpus.dishById(recipe.dishId);
    final delta = DateTime.now().difference(entry.savedAt).inDays;
    return ZebraRow(
      index: i,
      onTap: recipe == null || dish == null
          ? null
          : () => _open(context, dish, recipe),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _savedTitle(svc, recipe, dish, lang),
                  style: AppText.serif(context, size: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  t(L10n.tSavedOn).replaceFirst('{d}', '$delta'),
                  style: AppText.mono(context,
                      size: 10, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t(L10n.tSave),
            onPressed: () => svc.state.toggleSaved(entry.recipeId),
            icon: const Icon(Icons.favorite, size: 18),
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }

  String _savedTitle(Services svc, Recipe? recipe, Dish? dish, String lang) {
    if (dish != null) return _dishName(dish, lang);
    if (recipe != null) return _recipeTitle(recipe, lang);
    return '…';
  }

  Widget _historyList(
      BuildContext context,
      Services svc,
      List<HistoryEntry> history,
      String lang,
      String Function(String) t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          for (var i = 0; i < history.length; i++)
            _historyRow(context, svc, history[i], i, lang, t),
        ],
      ),
    );
  }

  Widget _historyRow(
      BuildContext context,
      Services svc,
      HistoryEntry entry,
      int i,
      String lang,
      String Function(String) t) {
    final recipe = svc.corpus.recipeById(entry.recipeId);
    final dish = recipe == null ? null : svc.corpus.dishById(recipe.dishId);
    final days = DateTime.now().difference(entry.at).inDays;
    return ZebraRow(
      index: i,
      onTap: recipe == null || dish == null
          ? null
          : () => _open(context, dish, recipe),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _savedTitle(svc, recipe, dish, lang),
                  style: AppText.serif(context, size: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  '${t(L10n.tCooked)} · $days ${t(L10n.tDaysAgo)}',
                  style: AppText.mono(context,
                      size: 10, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppColors.inkFaint),
        ],
      ),
    );
  }

  void _open(BuildContext context, Dish dish, Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DishDetailPage(dish: dish, initialRecipe: recipe),
      ),
    );
  }
}
