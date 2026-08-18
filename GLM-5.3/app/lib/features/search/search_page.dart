import 'dart:async';

import 'package:flutter/material.dart' hide Page;
import 'package:provider/provider.dart';

import '../../core/pagination/pagination_controller.dart';
import '../../core/search/search_index.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/dashed_rule.dart';
import '../../l10n/strings.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../routes.dart';
import '../widgets/dish_card.dart';

/// Free-text search + tag filters; results respect profile filters
/// (post-match). Cursor pagination: 20 per page, prefetch at 10, max 50.
/// Zero-result queries are logged as content requests (SPEC).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late SearchIndex _index;
  bool _filtersOpen = false;
  final _filters = SearchFilters();
  List<SearchHit> _ranked = const [];
  late final PaginationController<SearchHit> _pager;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _index = SearchIndex(state.corpus, state.lang)..build();
    _pager = PaginationController<SearchHit>(
      pageSize: 20,
      prefetchThreshold: 10,
      maxItems: 50,
      fetch: (cursor) async {
        final offset = int.tryParse(cursor ?? '0') ?? 0;
        final slice = _ranked.skip(offset).take(20).toList();
        final nextOffset = offset + slice.length;
        return Page(
          items: slice,
          nextCursor: nextOffset < _ranked.length ? '$nextOffset' : null,
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _runSearch(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _runSearch(value));
  }

  void _runSearch(String query) {
    final state = context.read<AppState>();
    setState(() => _query = query.trim());
    var hits = query.trim().isEmpty ? _allDishesAsHits(state) : _index.query(query);
    hits = _index.applyFilters(hits, _filters);
    // Profile filters apply to results post-match (SPEC).
    final visible = <SearchHit>[];
    for (final hit in hits) {
      final best = state.bestVariantFor(hit.dish);
      if (best == null) continue;
      visible.add(SearchHit(dish: hit.dish, recipe: best, score: hit.score));
    }
    setState(() => _ranked = visible);
    _pager.refresh();
    if (query.trim().isNotEmpty && visible.isEmpty) {
      state.logContentRequest(query.trim());
    }
  }

  List<SearchHit> _allDishesAsHits(AppState state) {
    final hits = <SearchHit>[];
    for (final dish in state.corpus.allDishes) {
      final best = state.bestVariantFor(dish);
      if (best == null) continue;
      hits.add(SearchHit(dish: dish, recipe: best, score: 0));
    }
    return hits;
  }
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 400) {
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
                  Text(context.tr('nav.search'),
                      style: AppFonts.display(size: 40, color: AppColors.ink)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    onChanged: _onQueryChanged,
                    onSubmitted: _runSearch,
                    style: AppFonts.serif(size: 17),
                    decoration: InputDecoration(
                      hintText: context.tr('search.hint'),
                      hintStyle: AppFonts.mono(size: 11, color: AppColors.inkFaint),
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.teal, size: 20),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.inkFaint),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: AppColors.teal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      QuietLink(
                        label: '${context.tr('search.filters')} ▾',
                        onTap: () => setState(() => _filtersOpen = !_filtersOpen),
                      ),
                      const Spacer(),
                      if (_query.isNotEmpty)
                        Text(
                          context.tr('search.results', {'n': '${_ranked.length}'}),
                          style: AppFonts.mono(size: 10, color: AppColors.inkSoft),
                        ),
                    ],
                  ),
                  if (_filtersOpen) _filterPanel(),
                  const DashedRule(glyph: '?'),
                ],
              ),
            ),
          ),
          if (_pager.items.isEmpty && !_pager.isLoading)
            const SliverFillRemaining(hasScrollBody: false, child: _SearchEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => DishCard(
                      dish: _pager.items[index].dish,
                      recipe: _pager.items[index].recipe),
                  childCount: _pager.items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
  Widget _filterPanel() {
    final state = context.watch<AppState>();
    final lang = state.lang;
    Widget group(String label, List<String> values, Set<String> selected,
        void Function(String) toggle) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: AppFonts.mono(size: 9, color: AppColors.coral, letterSpacing: 1.4)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final value in values)
                  SelectablePill(
                    label: _labelFor(state, value, lang),
                    selected: selected.contains(value),
                    onTap: () {
                      toggle(value);
                      _runSearch(_controller.text);
                    },
                    compact: true,
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          group(context.tr('search.filterDiets'),
              [for (final d in state.corpus.ontology.diets) d.id], _filters.diets, (v) {
            _filters.diets.contains(v) ? _filters.diets.remove(v) : _filters.diets.add(v);
          }),
          group(context.tr('search.filterCuisines'),
              ['italian', 'asian', 'middle-eastern', 'american'], _filters.cuisines,
              (v) {
            _filters.cuisines.contains(v)
                ? _filters.cuisines.remove(v)
                : _filters.cuisines.add(v);
          }),
          group(context.tr('search.filterEfforts'),
              [for (final e in state.corpus.ontology.efforts) e.id], _filters.efforts,
              (v) {
            _filters.efforts.contains(v) ? _filters.efforts.remove(v) : _filters.efforts.add(v);
          }),
          group(context.tr('search.filterTechniques'),
              [for (final t in state.corpus.ontology.techniques) t.id], _filters.techniques,
              (v) {
            _filters.techniques.contains(v)
                ? _filters.techniques.remove(v)
                : _filters.techniques.add(v);
          }),
        ],
      ),
    );
  }

  String _labelFor(AppState state, String value, String lang) {
    if (['italian', 'asian', 'middle-eastern', 'american'].contains(value)) {
      return AppL.t(lang, 'cuisine.$value');
    }
    return state.corpus.ontology.attrLabel(value, lang);
  }
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('search.emptyTitle'),
                style: AppFonts.display(size: 24, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            Text(
              context.tr('search.emptyBody'),
              textAlign: TextAlign.center,
              style: AppFonts.serif(size: 13, color: AppColors.inkSoft, height: 1.5),
            ),
            const SizedBox(height: 12),
            QuietLink(
              label: context.tr('common.viewFaq'),
              onTap: () => openFaq(context, 'faq-no-results'),
            ),
          ],
        ),
      ),
    );
  }
}
