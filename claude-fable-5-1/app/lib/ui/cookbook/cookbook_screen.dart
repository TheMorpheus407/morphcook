import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/dish.dart';
import '../../data/models/recipe.dart';
import '../../domain/pagination.dart' as pg;
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../shell/app_shell.dart';
import '../widgets/dish_card.dart';

typedef _SavedRow = (Recipe, Dish, DateTime);

/// Saved versions, newest first, offset-paginated in windows of 50.
class CookbookScreen extends StatefulWidget {
  const CookbookScreen({super.key});

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen> with AutomaticKeepAliveClientMixin {
  pg.PaginationController<_SavedRow, int>? _controller;
  int _base = 0;
  String? _lastSignature;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _signature(AppController app) => '${app.lang}|${app.savedIdsNewestFirst.join(',')}';

  void _ensureController(AppController app) {
    final sig = _signature(app);
    if (_controller != null && sig == _lastSignature) return;
    _lastSignature = sig;
    if (_base >= app.savedCount) _base = 0;
    _controller?.dispose();
    final c = pg.PaginationController<_SavedRow, int>(
      pageSize: 30,
      prefetchThreshold: 10,
      maxRendered: 50,
      loader: (cursor, pageSize) async {
        final ids = app.savedIdsNewestFirst;
        final windowed = _base < ids.length ? ids.sublist(_base) : <String>[];
        final page = pg.offsetPage(windowed, cursor, pageSize);
        final rows = <_SavedRow>[];
        for (final id in page.items) {
          final r = await app.recipe(id);
          final d = r == null ? null : app.dish(r.dishId);
          final at = app.savedAt(id);
          if (r == null || d == null || at == null) continue;
          rows.add((r, d, at));
        }
        return pg.Page(items: rows, nextCursor: page.nextCursor);
      },
    );
    _controller = c;
    c.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => c.loadMore());
  }

  void _advanceWindow() {
    _base += 50;
    _lastSignature = null;
    setState(() {});
  }

  void _backToStart() {
    _base = 0;
    _lastSignature = null;
    setState(() {});
  }

  Future<void> _unsave(BuildContext context, AppController app, Recipe r) async {
    final s = context.s;
    await app.toggleSaved(r.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${s('common.remove')} · ${r.title.of(app.lang)}'),
        action: SnackBarAction(label: s('common.undo'), onPressed: () => app.toggleSaved(r.id)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final app = context.watch<AppController>();
    final s = context.s;
    _ensureController(app);
    final controller = _controller!;

    if (app.savedCount == 0) {
      return SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(context, s),
            Expanded(
              child: EmptyState(
                title: s('cookbook.empty.title'),
                note: s('cookbook.empty.note'),
                icon: Icons.bookmark_border,
                action: PaperButton(
                  label: s('nav.search'),
                  icon: Icons.search,
                  kind: PaperButtonKind.secondary,
                  onPressed: () => ShellTabs.maybeOf(context)?.select(ShellTabs.search),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final items = controller.items;
    return SafeArea(
      bottom: false,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: null,
        itemBuilder: (context, index) {
          if (index == 0) return _header(context, s);
          final i = index - 1;
          if (i < items.length) {
            if (controller.shouldLoadMore(i)) {
              WidgetsBinding.instance.addPostFrameCallback((_) => controller.loadMore());
            }
            final (r, d, at) = items[i];
            return RecipeRowTile(
              recipe: r,
              dish: d,
              subtitle: s('cookbook.savedOn', {'date': s.shortDate(at)}),
              trailing: IconButton(
                icon: const Icon(Icons.bookmark, color: Palette.ink),
                tooltip: s('common.remove'),
                onPressed: () => _unsave(context, app, r),
              ),
            );
          }
          if (i == items.length) {
            if (controller.isLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                child: Row(children: [SkeletonBox(height: 54, width: 54), SizedBox(width: 14), Expanded(child: SkeletonBox(height: 15))]),
              );
            }
            final hasMoreWindows = _base + 50 < app.savedCount;
            if (controller.capReached || _base > 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DashedRule(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_base > 0)
                          PaperButton(label: s('common.back'), kind: PaperButtonKind.quiet, icon: Icons.first_page, onPressed: _backToStart),
                        const Spacer(),
                        if (controller.capReached && hasMoreWindows)
                          PaperButton(
                            label: s('cookbook.loadNext', {'n': '50'}),
                            kind: PaperButtonKind.secondary,
                            icon: Icons.last_page,
                            onPressed: _advanceWindow,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            }
            return null;
          }
          return null;
        },
      ),
    );
  }

  Widget _header(BuildContext context, dynamic s) => SectionHeader(
        title: s('cookbook.title'),
        kicker: s('cookbook.kicker'),
        padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        trailing: IconButton(
          icon: const Icon(Icons.history),
          tooltip: s('cookbook.history'),
          onPressed: () => Routes.openHistory(context),
        ),
      );
}
