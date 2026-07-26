import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../l10n/strings.dart';
import '../../services/pagination.dart';
import '../../services/search_service.dart';
import '../../state/app_state.dart';
import '../widgets/recipe_card.dart';

/// Free text + tag filters, results filtered by the profile, cursor-paginated
/// twenty at a time with an infinite scroll that prefetches ten items out.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.onPick, this.title});

  /// When set the screen behaves as a picker (used by the meal plan).
  final ValueChanged<String>? onPick;
  final String? title;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();

  late final PaginationController<SearchHit> _pagination = PaginationController(
    config: PaginationConfig.search,
    fetcher: _fetch,
  );

  Timer? _debounce;
  SearchOutcome _outcome = SearchOutcome.empty;
  List<SearchHit> _all = const [];
  bool _includeHidden = false;
  bool _searching = false;
  bool _hasSearched = false;

  final Set<String> _diet = {};
  final Set<String> _effort = {};
  final Set<String> _tags = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    _pagination.dispose();
    super.dispose();
  }

  Future<PageResult<SearchHit>> _fetch(String? cursor, int limit) async {
    final start = int.tryParse(cursor ?? '0') ?? 0;
    if (start >= _all.length) {
      return PageResult<SearchHit>(items: const [], totalHint: _all.length);
    }
    final end = (start + limit).clamp(0, _all.length);
    return PageResult<SearchHit>(
      items: _all.sublist(start, end),
      nextCursor: end < _all.length ? end.toString() : null,
      totalHint: _all.length,
    );
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _runSearch);
  }

  Future<void> _runSearch() async {
    final state = context.read<AppState>();
    final query = _query.text.trim();
    if (query.isEmpty && _diet.isEmpty && _effort.isEmpty && _tags.isEmpty) {
      setState(() {
        _hasSearched = false;
        _all = const [];
        _outcome = SearchOutcome.empty;
      });
      _pagination.reset();
      return;
    }

    setState(() => _searching = true);
    final outcome = await state.searchService.search(
      query,
      lang: state.lang,
      context: state.matchContext(),
      dietFilters: _diet,
      effortFilters: _effort,
      tagFilters: _tags,
      includeHidden: _includeHidden,
    );
    if (!mounted) return;

    setState(() {
      _outcome = outcome;
      _all = outcome.hits;
      _searching = false;
      _hasSearched = true;
    });
    await _pagination.refresh();

    // A search that found nothing at all is a content gap worth recording.
    if (outcome.hits.isEmpty && outcome.hiddenCount == 0 && query.isNotEmpty) {
      await state.recordEmptySearch(query);
    }
  }

  void _toggle(Set<String> target, String value) {
    setState(() {
      target.contains(value) ? target.remove(value) : target.add(value);
    });
    _runSearch();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final ontology = state.repository.ontology;

    return Scaffold(
      appBar: widget.title == null
          ? null
          : AppBar(title: Text(widget.title!.toLowerCase())),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                widget.title == null ? 18 : 6,
                20,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.title == null) ...[
                    Text(
                      s.navSearch.toLowerCase(),
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _query,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _runSearch(),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: s.searchHint,
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: colors.inkFaint,
                      ),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _query.clear();
                                _runSearch();
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final v in ontology.axisValues['diet'] ?? const [])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkChip(
                              label: v.label(s.lang),
                              dense: true,
                              selected: _diet.contains(v.id),
                              onTap: () => _toggle(_diet, v.id),
                            ),
                          ),
                        Container(width: 1, height: 22, color: colors.edge),
                        const SizedBox(width: 8),
                        for (final e in ontology.efforts)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkChip(
                              label: e.label(s.lang),
                              dense: true,
                              tone: colors.secondary,
                              selected: _effort.contains(e.id),
                              onTap: () => _toggle(_effort, e.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_diet.isNotEmpty ||
                      _effort.isNotEmpty ||
                      _tags.isNotEmpty)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _diet.clear();
                            _effort.clear();
                            _tags.clear();
                          });
                          _runSearch();
                        },
                        child: Text(s.searchClearFilters),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _results(s)),
          ],
        ),
      ),
    );
  }

  Widget _results(S s) {
    if (_searching && _all.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: const [SkeletonCard(), SkeletonCard(), SkeletonCard()],
      );
    }
    if (!_hasSearched) {
      return EmptyNote(
        headline: s.searchStartTitle,
        body: s.searchStartBody,
        hand: s.tagline,
        icon: Icons.travel_explore_outlined,
      );
    }
    if (_all.isEmpty && _outcome.hiddenCount == 0) {
      return EmptyNote(
        headline: s.searchEmptyTitle,
        body: s.searchEmptyBody(_outcome.query),
        icon: Icons.inbox_outlined,
      );
    }

    return AnimatedBuilder(
      animation: _pagination,
      builder: (context, _) {
        final items = _pagination.items;
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: items.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) return _resultsHeader(s);
            if (index == items.length + 1) {
              return PaginationFooter(
                loading: _pagination.isLoading,
                hasMore: _pagination.hasMore,
                endLabel: s.thatIsEverything,
                droppedFromHead: _pagination.droppedFromHead,
                droppedLabel: s.itemsCount(_pagination.droppedFromHead),
                error: _pagination.error,
                onRetry: _pagination.loadMore,
                retryLabel: s.retry,
              );
            }
            final i = index - 1;
            if (_pagination.shouldLoadMore(i)) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _pagination.loadMore(),
              );
            }
            final hit = items[i];
            return Column(
              children: [
                RecipeRow(
                  recipe: hit.recipe,
                  dimmed: !hit.visible,
                  onTap: widget.onPick == null
                      ? null
                      : () => widget.onPick!(hit.recipe.id),
                ),
                DashedRule(color: context.colors.edge),
              ],
            );
          },
        );
      },
    );
  }

  Widget _resultsHeader(S s) {
    if (_outcome.hiddenCount == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          s.recipesCount(_all.length),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      );
    }
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.paperSunk,
        border: Border.all(color: colors.edge),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_off_outlined, size: 16, color: colors.inkFaint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.searchHiddenCount(_outcome.hiddenCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _includeHidden = !_includeHidden);
              _runSearch();
            },
            child: Text(_includeHidden ? s.searchFilters : s.dishShowHidden),
          ),
        ],
      ),
    );
  }
}
