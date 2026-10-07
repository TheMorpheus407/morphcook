import 'package:flutter/material.dart' hide Typography, Page;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/meal_plan.dart';
import '../../core/model/recipe.dart';
import '../../core/model/shopping.dart';
import '../../core/pagination.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../navigation.dart';
import '../../state/app_state.dart';
import '../../state/storage.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/paginated_list.dart';
import '../../widgets/paper.dart';
import '../../widgets/stripe_plate.dart';

/// The cookbook: saved variants (you save *your* Döner — a specific recipe
/// id, not a dish) and cooking history.
///
/// Pagination: saved is offset-based (30/page), history is time-based
/// (7-week windows).
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(
            children: [
              for (final (i, label) in [(0, s.cbSaved), (1, s.cbHistory)])
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => setState(() => _tab = i),
                    child: Column(
                      children: [
                        Text(label.toUpperCase(),
                            style: Typography.mono(11,
                                weight: _tab == i ? FontWeight.w700 : FontWeight.w400,
                                letterSpacing: 2,
                                color: _tab == i ? Palette.ink : Palette.inkFaint)),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 2,
                          width: 40,
                          color: _tab == i ? Palette.coral : Colors.transparent,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const DashedRule(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
        Expanded(
          child: _tab == 0
              ? _SavedTab(s: s)
              : _HistoryTab(s: s),
        ),
      ],
    );
  }
}

/// Saved variants — offset-based pagination, 30 per page, prefetch at 10.
class _SavedTab extends StatefulWidget {
  final Strings s;

  const _SavedTab({required this.s});

  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab> {
  PaginationController<Recipe>? _controller;

  PaginationController<Recipe> _buildController(AppState appState) {
    final savedIds = appState.savedRecipeIds;
    return offsetPagination<Recipe>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetch: (offset, limit) async {
        final pageIds = savedIds.skip(offset).take(limit).toList();
        final recipes = <Recipe>[];
        for (final id in pageIds) {
          final r = await appState.corpus.loadRecipe(id);
          if (r != null) recipes.add(r);
        }
        return Page(items: recipes);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = context.read<AppState>();
    _controller ??= _buildController(appState);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    _controller ??= _buildController(appState);
    return PaginatedListView<Recipe>(
      controller: _controller!,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      emptyState: EmptyState(title: widget.s.cbEmptySaved, body: widget.s.cbEmptySavedBody),
      itemBuilder: (context, recipe, index) => _RecipeRow(
        recipe: recipe,
        s: widget.s,
        subtitle: widget.s.cbSavedAt.replaceAll('{date}', _dateLabel(recipe.id, appState)),
        onTap: () => openDish(context, recipe.dishId),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark, size: 18, color: Palette.coral),
          onPressed: () => appState.toggleSaved(recipe.id),
        ),
      ),
    );
  }

  String _dateLabel(String recipeId, AppState appState) {
    // The saved box holds saved_at per recipe id.
    final saved = AppStorage.savedBox.get(recipeId);
    if (saved is Map) {
      final at = DateTime.tryParse(saved['saved_at'] as String? ?? '');
      if (at != null) return '${at.day}. ${widget.s.monthName(at.month)} ${at.year}';
    }
    return '';
  }
}

/// History — time-based pagination, 7-week windows, grouped with headers.
class _HistoryTab extends StatefulWidget {
  final Strings s;

  const _HistoryTab({required this.s});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  PaginationController<HistoryEntry>? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= timeWindowPagination<HistoryEntry>(
      windowDays: 7,
      prefetchWeeks: 1,
      maxWeeks: 4,
      fetch: (windowStart, windowDays) async {
        final appState = context.read<AppState>();
        final end = windowStart.add(Duration(days: windowDays));
        final entries = appState.history
            .where((e) =>
                !e.cookedAt.isBefore(windowStart) && e.cookedAt.isBefore(end))
            .toList();
        return Page(items: entries);
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return PaginatedListView<HistoryEntry>(
      controller: _controller!,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      emptyState: EmptyState(title: widget.s.cbEmptyHistory),
      itemBuilder: (context, entry, index) {
        final recipe = appState.corpus.loadedRecipe(entry.recipeId);
        final weekId = weekIdFor(entry.cookedAt);
        final now = DateTime.now();
        final isThisWeek = weekId == weekIdFor(now);
        final header = isThisWeek ? widget.s.cbThisWeek : widget.s.cbLastWeek;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index == 0 || weekIdFor(appState.history[index - 1].cookedAt) != weekId)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(header.toUpperCase(),
                    style: Typography.mono(9.5, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
              ),
            _RecipeRow(
              recipe: recipe,
              s: widget.s,
              subtitle: widget.s.cbCookedAt.replaceAll('{date}', _fmtDate(entry.cookedAt, widget.s)),
              onTap: recipe != null ? () => openDish(context, recipe.dishId) : null,
            ),
          ],
        );
      },
    );
  }

  String _fmtDate(DateTime date, Strings s) =>
      '${date.day}. ${s.monthName(date.month)} ${date.year}';
}

class _RecipeRow extends StatelessWidget {
  final Recipe? recipe;
  final Strings s;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _RecipeRow({required this.recipe, required this.s, required this.subtitle, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    if (recipe == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(subtitle, style: Typography.mono(10, color: Palette.inkFaint)),
      );
    }
    final dish = context.read<AppState>().corpus.dishById(recipe!.dishId);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Palette.paper,
          border: Border.all(color: Palette.line),
          boxShadow: const [BoxShadow(color: Color(0x1A2B2620), blurRadius: 8, offset: Offset(1, 3))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 48,
              child: StripedPlate(
                color: dish != null ? _color(dish.stripeColor) : Palette.coral,
                height: 48,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe!.title.resolve(s.lang), style: Typography.hand(20)),
                  Text(
                    '${recipe!.timeMinutes} ${s.commonMin} · ~${recipe!.caloriesPerServing} ${s.commonKcal} · ${s.effortLabel(recipe!.effort)}',
                    style: Typography.mono(9.5, color: Palette.inkFaint),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

Color _color(String hex) {
  final digits = hex.replaceFirst('#', '');
  final value = int.tryParse(digits, radix: 16);
  if (value == null) return Palette.coral;
  return Color(digits.length == 6 ? 0xFF000000 | value : value);
}
