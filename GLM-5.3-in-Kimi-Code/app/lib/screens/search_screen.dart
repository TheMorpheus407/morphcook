/// Free-text search with tag filters, cursor pagination, zero-result log.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/pagination.dart';
import '../logic/search.dart';
import '../state/app_state.dart';
import '../l10n.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'dish_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;
  late PaginationController<SearchHit> _pager;
  SearchFilters _filters = SearchFilters.empty;
  bool _filtersOpen = false;

  static const _cuisines = ['italian', 'asian', 'middle-eastern', 'german',
    'turkish', 'thai', 'japanese', 'indian', 'hungarian', 'american'];
  static const _diets = ['classic', 'vegan', 'vegetarian', 'pescatarian',
    'halal', 'kosher', 'keto', 'gluten-free', 'lactose-free', 'low-fodmap',
    'sugar-free', 'nut-free'];
  static const _efforts = ['easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _pager = PaginationController<SearchHit>(
      policy: PaginationPolicy.search,
      fetchPage: (cursor) async {
        final app = context.read<AppState>();
        final res = app.search(_controller.text,
            filters: _filters, cursor: cursor);
        // zero-result query → content request log
        if (res.total == 0 && _controller.text.trim().isNotEmpty) {
          await app.noteZeroResults(_controller.text.trim());
        }
        return Future.value(res.hits);
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _pager.dispose();
    super.dispose();
  }

  void _run() {
    _pager.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t(lang, 'scTitle'),
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 20)),
      ),
      body: PaperGrain(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (_) => _debounceRun(),
                  onSubmitted: (_) => _run(),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: L.t(lang, 'scHint'),
                    hintStyle: const TextStyle(
                        fontFamily: AppTheme.hand,
                        fontSize: 18,
                        color: AppTheme.inkFaint),
                    border: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: AppTheme.ink, width: 1.4)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: AppTheme.coral, width: 1.8)),
                  ),
                  style: const TextStyle(
                      fontFamily: AppTheme.display, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _filtersOpen = !_filtersOpen),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: _filters.isEmpty
                            ? AppTheme.line
                            : AppTheme.coral),
                  ),
                  child: Text(
                    L.t(lang, 'scFilters').toUpperCase(),
                    style: TextStyle(
                        fontFamily: AppTheme.mono,
                        fontSize: 9.5,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        color: _filters.isEmpty
                            ? AppTheme.inkSoft
                            : AppTheme.coral),
                  ),
                ),
              ),
            ]),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _filtersOpen
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterGroup(
                    lang: lang,
                    label: L.t(lang, 'scCuisine'),
                    values: _cuisines,
                    selected: _filters.cuisine,
                    onPick: (v) => setState(() {
                      _filters =
                          SearchFilters(cuisine: v, diet: _filters.diet, effort: _filters.effort);
                      _run();
                    }),
                  ),
                  _FilterGroup(
                    lang: lang,
                    label: L.t(lang, 'scDiet'),
                    values: _diets,
                    selected: _filters.diet,
                    onPick: (v) => setState(() {
                      _filters = SearchFilters(
                          cuisine: _filters.cuisine,
                          diet: v == _filters.diet ? null : v,
                          effort: _filters.effort);
                      _run();
                    }),
                  ),
                  _FilterGroup(
                    lang: lang,
                    label: L.t(lang, 'scEffort'),
                    values: _efforts,
                    selected: _filters.effort,
                    onPick: (v) => setState(() {
                      _filters = SearchFilters(
                          cuisine: _filters.cuisine,
                          diet: _filters.diet,
                          effort: v == _filters.effort ? null : v);
                      _run();
                    }),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedBuilder(
              animation: _pager,
              builder: (context, _) {
                if (_pager.status == PageStatus.loading &&
                    _pager.items.isEmpty) {
                  return _SkeletonList();
                }
                if (_pager.items.isEmpty) {
                  return ListView(padding: const EdgeInsets.all(28), children: [
                    const SizedBox(height: 30),
                    HandNote(text: L.t(lang, 'scNoResults')),
                    const SizedBox(height: 12),
                    Text(
                      L.t(lang, 'scNoResultsBody'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontFamily: AppTheme.display,
                          fontSize: 15,
                          height: 1.5,
                          color: AppTheme.inkSoft),
                    ),
                  ]);
                }
                return ListView.builder(
                  itemCount: _pager.items.length + 1,
                  itemBuilder: (context, i) {
                    if (_pager.shouldLoadMore(i) && !_pager.isLoading) {
                      _pager.loadMore();
                    }
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                        child: Text(
                          L.f(lang, 'scResults', {'n': '${_pager.items.length}'}),
                          style: const TextStyle(
                              fontFamily: AppTheme.mono,
                              fontSize: 9.5,
                              letterSpacing: 1.4,
                              color: AppTheme.inkFaint),
                        ),
                      );
                    }
                    final hit = _pager.items[i - 1];
                    return _HitRow(
                      lang: lang,
                      app: app,
                      hit: hit,
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  bool _debounceScheduled = false;
  void _debounceRun() {
    if (_debounceScheduled) return;
    _debounceScheduled = true;
    Future.delayed(const Duration(milliseconds: 350), () {
      _debounceScheduled = false;
      _run();
    });
  }
}

class _FilterGroup extends StatelessWidget {
  final Lang lang;
  final String label;
  final List<String> values;
  final String? selected;
  final ValueChanged<String> onPick;
  const _FilterGroup({
    required this.lang,
    required this.label,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 9,
                letterSpacing: 1.8,
                color: AppTheme.inkFaint)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final v in values)
            StampChip(
              label: v,
              color: AppTheme.teal,
              selected: selected == v,
              onTap: () => onPick(v),
            ),
        ]),
      ]),
    );
  }
}

class _HitRow extends StatelessWidget {
  final Lang lang;
  final AppState app;
  final SearchHit hit;
  const _HitRow({required this.lang, required this.app, required this.hit});

  @override
  Widget build(BuildContext context) {
    final dietLabel =
        app.ontology.dietLabels[hit.recipe.diet]?.label.get(lang) ?? hit.recipe.diet;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => DishScreen(dishId: hit.dish.id))),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.paper,
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(children: [
          SizedBox(
            width: 64,
            height: 64,
            child: StripedPlate(
              color: hit.dish.color,
              caption: '',
              height: 64,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                hit.dish.canonicalName.get(lang),
                style: const TextStyle(
                    fontFamily: AppTheme.hand, fontSize: 21, color: AppTheme.ink),
              ),
              const SizedBox(height: 2),
              Text(
                hit.recipe.subtitle.get(lang),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 13.5,
                    color: AppTheme.inkSoft),
              ),
              const SizedBox(height: 4),
              Text(
                '$dietLabel · ${hit.recipe.effort} · ${hit.recipe.timeMinutes} ${L.t(lang, 'minutes')} · ~${hit.recipe.caloriesPerServing} ${L.t(lang, 'kcal')}',
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9.5,
                    color: AppTheme.inkFaint),
              ),
            ]),
          ),
          const Icon(Icons.chevron_right, size: 20, color: AppTheme.inkFaint),
        ]),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 7),
            height: 84,
            decoration: BoxDecoration(
              color: AppTheme.paperDeep.withValues(alpha: 0.6),
              border: Border.all(color: AppTheme.line),
            ),
          ),
      ],
    );
  }
}
