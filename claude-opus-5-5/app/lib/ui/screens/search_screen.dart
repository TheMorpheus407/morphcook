import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../logic/pagination.dart';
import '../../logic/search_engine.dart';
import '../../models/recipe.dart';
import '../../state/library_store.dart';
import '../../state/profile_controller.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/recipe_card.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RecipeSearchView(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(context.tr('search.title'), style: MT.display(38)),
        ),
        onPick: (r) => openDish(context, r.dishId, recipeId: r.id),
      ),
    );
  }
}

/// Free-text + tag-filter search with cursor pagination (20 per page,
/// prefetch 10 from the end, at most 50 rendered). Also used as a picker.
class RecipeSearchView extends StatefulWidget {
  const RecipeSearchView({super.key, required this.onPick, this.header, this.autofocus = false});
  final ValueChanged<Recipe> onPick;
  final Widget? header;
  final bool autofocus;

  @override
  State<RecipeSearchView> createState() => _RecipeSearchViewState();
}

class _RecipeSearchViewState extends State<RecipeSearchView> {
  final _query = TextEditingController();
  Timer? _debounce;
  SearchFilters _filters = const SearchFilters();
  List<Recipe> _results = const [];
  SearchOutcome? _outcome;
  late final PaginationController<Recipe> _pages = PaginationController<Recipe>(
    config: PaginationConfig.search,
    fetcher: (token, size) async => SearchEngine.page(_results, token, size),
  );
  int _runId = 0;
  Object? _error;

  late final ProfileController _profileCtrl = context.read<ProfileController>();
  late final CorpusRepository _repo = context.read<CorpusRepository>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    _profileCtrl.addListener(_onProfile);
    _repo.addListener(_onCorpus);
  }

  void _onProfile() => _run();

  bool _wasAllLoaded = false;
  void _onCorpus() {
    final all = _repo.allLoaded;
    if (all && !_wasAllLoaded) {
      _wasAllLoaded = true;
      if (_query.text.isEmpty) _run();
    }
  }

  @override
  void dispose() {
    _profileCtrl.removeListener(_onProfile);
    _repo.removeListener(_onCorpus);
    _debounce?.cancel();
    _query.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _run(logEmpty: true));
  }

  Future<void> _run({bool logEmpty = false}) async {
    final id = ++_runId;
    final engine = context.read<SearchEngine>();
    final profileCtrl = context.read<ProfileController>();
    final repo = context.read<CorpusRepository>();
    final library = context.read<LibraryStore>();
    try {
      final outcome = await engine.run(
        query: _query.text,
        filters: _filters,
        profile: profileCtrl.profile,
        ctx: profileCtrl.matchContext(repo),
        lastCooked: library.lastCooked,
      );
      if (!mounted || id != _runId) return;
      _results = outcome.results;
      setState(() {
        _outcome = outcome;
        _error = null;
      });
      await _pages.refresh();
      // A text search with nothing visible (tag filters aside) is a content
      // gap worth remembering — it goes out only inside a user's backup.
      final noVisibleMatch = outcome.corpusHits - outcome.hiddenByProfile == 0;
      if (logEmpty && _query.text.trim().isNotEmpty && noVisibleMatch) {
        await library.logContentRequest(_query.text);
      }
    } catch (e) {
      if (mounted && id == _runId) setState(() => _error = e);
    }
  }

  void _setFilters(SearchFilters f) {
    setState(() => _filters = f);
    _run();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final repo = context.watch<CorpusRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) widget.header!,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: TextField(
            key: const Key('search-field'),
            controller: _query,
            autofocus: widget.autofocus,
            onChanged: _onChanged,
            onSubmitted: (_) => _run(logEmpty: true),
            textInputAction: TextInputAction.search,
            style: MT.serif(17),
            decoration: InputDecoration(
              hintText: tr('search.hint'),
              prefixIcon: const Icon(Icons.search, color: MC.inkSoft),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: tr('search.clear'),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _query.clear();
                        _run();
                      },
                    ),
            ),
          ),
        ),
        _FilterBar(filters: _filters, onChanged: _setFilters, repo: repo),
        if (_outcome != null && _results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
            child: Row(
              children: [
                MonoLabel(tr('search.results', {'n': _results.length})),
                const Spacer(),
                if (_outcome!.hiddenByProfile > 0)
                  Flexible(
                    child: Text(
                      tr('search.hidden', {'n': _outcome!.hiddenByProfile}),
                      style: MT.mono(10, color: MC.inkFaint),
                      textAlign: TextAlign.right,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    final tr = context.tr;
    final repo = context.read<CorpusRepository>();
    if (_error != null) {
      return EmptyState(
        title: tr('search.error'),
        body: '',
        action: PaperButton(label: tr('search.retry'), onPressed: _run),
      );
    }
    return ListenableBuilder(
      listenable: _pages,
      builder: (context, _) {
        if (!_pages.isInitialised || (_pages.isLoading && _pages.length == 0)) {
          return ListView.builder(itemCount: 6, itemBuilder: (_, __) => const RecipeRowSkeleton());
        }
        if (_pages.isEmpty) {
          return SingleChildScrollView(
            child: EmptyState(
              title: tr('search.empty.title'),
              body: tr('search.empty.body'),
              action: TextLink(tr('search.why'), onTap: () => openFaq(context, entryId: 'search-empty')),
            ),
          );
        }
        final items = _pages.items;
        final offset = _pages.hasPrevious ? 1 : 0;
        return ListView.builder(
          key: const Key('search-results'),
          padding: const EdgeInsets.only(bottom: 30),
          // unknown itemCount: the builder returns null past the end
          itemBuilder: (context, i) {
            if (offset == 1 && i == 0) {
              return Center(
                child: TextLink(tr('cookbook.earlier'), icon: Icons.expand_less, onTap: _pages.loadPrevious),
              );
            }
            final idx = i - offset;
            if (idx < items.length) {
              if (_pages.shouldLoadMore(idx)) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _pages.loadMore());
              }
              final r = items[idx];
              final dish = repo.dishes[r.dishId]!;
              return RecipeRow(dish: dish, recipe: r, onTap: () => widget.onPick(r));
            }
            if (idx == items.length && (_pages.hasMore || _pages.isLoading)) return const RecipeRowSkeleton();
            return null;
          },
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filters, required this.onChanged, required this.repo});
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;
  final CorpusRepository repo;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final onto = repo.ontology;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        children: [
          InkChip(
            key: const Key('filters-open'),
            label: filters.isEmpty ? tr('search.filters') : '${tr('search.filters')} · ${filters.count}',
            icon: Icons.tune,
            selected: !filters.isEmpty,
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => _FilterSheet(initial: filters, onChanged: onChanged, repo: repo),
            ),
          ),
          const SizedBox(width: 8),
          for (final m in [15, 30]) ...[
            InkChip(
              dense: true,
              label: '≤ ${tr('profile.minutes', {'n': m})}',
              selected: filters.maxMinutes == m,
              onTap: () => onChanged(filters.copy(maxMinutes: () => filters.maxMinutes == m ? null : m)),
            ),
            const SizedBox(width: 6),
          ],
          for (final meal in ['breakfast', 'dinner', 'dessert']) ...[
            InkChip(
              dense: true,
              label: onto.label('meal_type', meal, lang),
              selected: filters.meals.contains(meal),
              onTap: () => onChanged(filters.toggle('meal', meal)),
            ),
            const SizedBox(width: 6),
          ],
          if (!filters.isEmpty)
            TextButton(
              onPressed: () => onChanged(const SearchFilters()),
              child: Text(tr('search.clear'), style: MT.mono(11)),
            ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.onChanged, required this.repo});
  final SearchFilters initial;
  final ValueChanged<SearchFilters> onChanged;
  final CorpusRepository repo;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _f = widget.initial;

  void _set(SearchFilters f) {
    setState(() => _f = f);
    widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final onto = widget.repo.ontology;
    Widget group(String title, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(title),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
    List<Widget> chips(String key, Iterable<String> values, String Function(String) label, Set<String> selected) => [
      for (final v in values)
        InkChip(dense: true, label: label(v), selected: selected.contains(v), onTap: () => _set(_f.toggle(key, v))),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        children: [
          Text(tr('search.filters'), style: MT.display(28)),
          const SizedBox(height: 16),
          group(
            tr('search.group.diet'),
            chips(
              'diet',
              onto.dimensionValues['diet']!.keys,
              (v) => onto.dimensionValueLabel('diet', v, lang),
              _f.diets,
            ),
          ),
          group(
            tr('search.group.effort'),
            chips('effort', const ['easy', 'medium', 'hard'], (v) => tr('effort.$v'), _f.efforts),
          ),
          group(tr('search.group.time'), [
            for (final m in [15, 30, 60])
              InkChip(
                dense: true,
                label: '≤ ${tr('profile.minutes', {'n': m})}',
                selected: _f.maxMinutes == m,
                onTap: () => _set(_f.copy(maxMinutes: () => _f.maxMinutes == m ? null : m)),
              ),
          ]),
          group(
            tr('search.group.meal'),
            chips('meal', onto.mealTypes, (v) => onto.label('meal_type', v, lang), _f.meals),
          ),
          group(
            tr('search.group.technique'),
            chips('technique', onto.techniques, (v) => onto.label('technique', v, lang), _f.techniques),
          ),
          group(
            tr('search.group.cuisine'),
            chips('cuisine', onto.labels['cuisine']!.keys, (v) => onto.label('cuisine', v, lang), _f.cuisines),
          ),
          const SizedBox(height: 6),
          InkButton(label: tr('common.done'), expand: true, onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}
