import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/dates.dart';
import '../../i18n/strings.dart';
import '../../logic/pagination.dart';
import '../../state/library_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';
import '../widgets/recipe_card.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('settings.history'))),
    body: const PaperBackground(child: HistoryList()),
  );
}

/// Cooking history grouped by ISO week with section headers; time-based
/// pagination (7 weeks per page, prefetch when within a week of the end).
class HistoryList extends StatefulWidget {
  const HistoryList({super.key});

  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  late final LibraryStore _library = context.read<LibraryStore>();
  late final CorpusRepository _repo = context.read<CorpusRepository>();
  late final PaginationController<HistoryWeek> _pages = PaginationController<HistoryWeek>(
    config: PaginationConfig.history,
    fetcher: (token, weeks) async {
      final page = await _library.historyPage(token, weeks);
      await _repo.ensureRecipes(page.items.expand((w) => w.entries.map((e) => e.recipeId)));
      return page;
    },
  );
  int _count = -1;

  @override
  void initState() {
    super.initState();
    _count = _library.history.length;
    _library.addListener(_onLibrary);
    _pages.loadMore();
  }

  void _onLibrary() {
    if (_library.history.length != _count) {
      _count = _library.history.length;
      _pages.refresh();
    }
  }

  @override
  void dispose() {
    _library.removeListener(_onLibrary);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final repo = context.watch<CorpusRepository>();
    return ListenableBuilder(
      listenable: _pages,
      builder: (context, _) {
        if (!_pages.isInitialised) return const Center(child: CircularProgressIndicator());
        if (_pages.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(title: tr('cookbook.empty.title'), body: tr('cookbook.history.empty')),
          );
        }
        final weeks = _pages.items;
        // flatten into header + rows; prefetch is measured in weeks
        final rows = <(int week, Widget)>[];
        for (var w = 0; w < weeks.length; w++) {
          final wk = weeks[w];
          final sunday = wk.week.monday.add(const Duration(days: 6));
          rows.add((
            w,
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tr('cookbook.week', {'w': wk.week.week, 'range': dayRange(wk.week.monday, sunday, lang)}),
                        style: MT.display(20),
                      ),
                      const Spacer(),
                      MonoLabel(tr('cookbook.count', {'n': wk.entries.length}), size: 10),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const DashedRule(),
                ],
              ),
            ),
          ));
          for (final e in wk.entries) {
            final r = repo.recipe(e.recipeId);
            if (r == null) continue;
            final dish = repo.dishes[r.dishId]!;
            rows.add((
              w,
              RecipeRow(
                dish: dish,
                recipe: r,
                note: '${weekdayName(e.cookedAt.weekday, lang).substring(0, 3)} · ${shortDate(e.cookedAt, lang)}',
                onTap: () => openDish(context, r.dishId, recipeId: r.id),
              ),
            ));
          }
        }
        return ListView.builder(
          key: const Key('history-list'),
          padding: const EdgeInsets.only(bottom: 30),
          itemBuilder: (context, i) {
            if (i < rows.length) {
              final week = rows[i].$1;
              if (_pages.shouldLoadMore(week)) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _pages.loadMore());
              }
              return rows[i].$2;
            }
            if (i == rows.length && _pages.hasMore) return const RecipeRowSkeleton();
            return null;
          },
        );
      },
    );
  }
}
