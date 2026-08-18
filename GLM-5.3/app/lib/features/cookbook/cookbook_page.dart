import 'package:flutter/material.dart' hide Page;
import 'package:provider/provider.dart';

import '../../core/models/user_data.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/util/dates.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import '../widgets/dish_card.dart';

/// Cookbook (saved): the user saves a *specific variant* (SPEC). Offset-based
/// pagination, 30 items per page, prefetch at 10, max 50 rendered.
class CookbookPage extends StatefulWidget {
  const CookbookPage({super.key});

  @override
  State<CookbookPage> createState() => _CookbookPageState();
}

class _CookbookPageState extends State<CookbookPage> {
  late final PaginationController<SavedEntry> _pager;
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _state = state;
    _pager = PaginationController<SavedEntry>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxItems: 50,
      fetch: (cursor) async {
        final entries = _state.savedNewestFirst;
        final offset = int.tryParse(cursor ?? '0') ?? 0;
        final slice = entries.skip(offset).take(30).toList();
        final nextOffset = offset + slice.length;
        return Page(
          items: slice,
          nextCursor: nextOffset < entries.length ? '$nextOffset' : null,
        );
      },
    );
    _pager.loadMore();
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
    // Keep the paginated list in sync when entries are saved/removed
    // elsewhere in the app (dish pages, planner picker).
    if (!_pager.isLoading && _pager.items.length != state.saved.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pager.refresh();
      });
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 400) {
          _pager.loadMore();
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('book.title'),
                      style: AppFonts.display(size: 40, color: AppColors.ink)),
                  const SizedBox(height: 6),
                  Text(
                    '${state.saved.length} ${context.trRead('home.variantsCount', {'n': '${state.saved.length}'})}',
                    style: AppFonts.mono(size: 10, color: AppColors.inkSoft, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 8),
                  const DashedRule(glyph: '&'),
                ],
              ),
            ),
          ),
          if (state.saved.isEmpty && !_pager.isLoading)
            const SliverFillRemaining(hasScrollBody: false, child: _EmptyBook())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final row = _pager.items[index];
                    return _SavedRowWidget(entry: row, lang: lang);
                  },
                  childCount: _pager.items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A saved entry row (specific variant, per SPEC).
class _SavedRowWidget extends StatelessWidget {
  const _SavedRowWidget({required this.entry, required this.lang});

  final SavedEntry entry;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final recipe = state.corpus.recipe(entry.recipeId);
    final dish = recipe == null ? null : state.corpus.dishes[recipe.dish];
    if (recipe == null || dish == null) return const SizedBox.shrink();
    return DishRow(
      title: state.localized(recipe.title),
      subtitle:
          '${context.tr('book.savedAt', {'when': DateFmt.shortDate(entry.at, lang)})} · ~${recipe.cal} ${context.trRead('common.kcal')}',
      stripeColor: dish.stripeColor,
      onTap: () => openDish(context, dish.id),
      trailing: IconButton(
        icon: const Icon(Icons.bookmark, size: 16, color: AppColors.coral),
        onPressed: () => state.toggleSaved(recipe.id),
      ),
    );
  }
}

class _EmptyBook extends StatelessWidget {
  const _EmptyBook();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('book.empty'),
                style: AppFonts.display(size: 24, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Text(
              context.tr('book.emptyBody'),
              textAlign: TextAlign.center,
              style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
