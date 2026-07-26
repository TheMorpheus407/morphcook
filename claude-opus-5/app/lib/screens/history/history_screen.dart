import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/collections.dart';
import '../../l10n/strings.dart';
import '../../services/pagination.dart';
import '../../state/app_state.dart';
import '../widgets/recipe_card.dart';

/// Time-based pagination: seven weeks at a time, section headers per week,
/// another page pulled when the user is within one week of the end.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _WeekGroup {
  const _WeekGroup(this.week, this.entries);

  final IsoWeek week;
  final List<CookHistoryEntry> entries;
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final PaginationController<_WeekGroup> _pagination =
      PaginationController(
        config: PaginationConfig.history,
        fetcher: listFetcher(() => _groups),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pagination.loadMore());
  }

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  List<_WeekGroup> get _groups {
    final state = context.read<AppState>();
    final byWeek = <String, List<CookHistoryEntry>>{};
    for (final entry in state.history) {
      (byWeek[IsoWeek.of(entry.cookedAt).key] ??= []).add(entry);
    }
    final keys = byWeek.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys)
        _WeekGroup(
          IsoWeek.parse(key),
          byWeek[key]!..sort((a, b) => b.cookedAt.compareTo(a.cookedAt)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    if (state.history.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(s.historyTitle.toLowerCase())),
        body: EmptyNote(
          headline: s.historyEmptyTitle,
          body: s.historyEmptyBody,
          icon: Icons.history,
        ),
      );
    }

    final thisWeek = IsoWeek.of(state.now);
    final lastWeek = thisWeek.shift(-1);

    return Scaffold(
      appBar: AppBar(title: Text(s.historyTitle.toLowerCase())),
      body: AnimatedBuilder(
        animation: _pagination,
        builder: (context, _) {
          final groups = _pagination.items;
          if (groups.isEmpty && _pagination.isLoading) {
            return const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: Column(
                children: [SkeletonCard(), SkeletonCard(), SkeletonCard()],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            itemCount: groups.length + 1,
            itemBuilder: (context, index) {
              if (index == groups.length) {
                return PaginationFooter(
                  loading: _pagination.isLoading,
                  hasMore: _pagination.hasMore,
                  endLabel: s.thatIsEverything,
                  error: _pagination.error,
                  onRetry: _pagination.loadMore,
                  retryLabel: s.retry,
                );
              }
              if (_pagination.shouldLoadMore(index)) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _pagination.loadMore(),
                );
              }
              final group = groups[index];
              final label = group.week == thisWeek
                  ? s.historyThisWeek
                  : group.week == lastWeek
                  ? s.historyLastWeek
                  : s.historyWeekOf(
                      DateFormat.yMMMd(s.lang).format(group.week.monday),
                    );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  SectionHeader(
                    label,
                    subtitle: s.recipesCount(group.entries.length),
                  ),
                  const SizedBox(height: 6),
                  for (final entry in group.entries)
                    _HistoryRow(entry: entry, s: s),
                  const SizedBox(height: 6),
                  DashedRule(color: colors.edge),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.s});

  final CookHistoryEntry entry;
  final S s;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final recipe = state.repository.recipe(entry.recipeId);
    final subtitle = [
      DateFormat.MMMEd(s.lang).format(entry.cookedAt),
      s.servings(entry.servings),
      if (!entry.completed) s.historyIncomplete,
    ].join(' · ');

    if (recipe == null) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          entry.recipeId,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        subtitle: Text(
          subtitle,
          style: MorphType.numeric(colors.inkFaint, size: 10),
        ),
      );
    }
    return RecipeRow(recipe: recipe, subtitleOverride: subtitle);
  }
}
