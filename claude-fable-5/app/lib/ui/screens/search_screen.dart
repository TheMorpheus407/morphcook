import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../logic/pagination.dart';
import '../../logic/search.dart';
import '../../models/recipe.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
import '../widgets/recipe_row.dart';

/// Free-text + tag-filter search. Results respect profile filters and are
/// paginated cursor-style (20/page, prefetch at 10, max 50 rendered).
class SearchScreen extends StatefulWidget {
  /// When set, taps return the recipe instead of opening the dish.
  final bool pickerMode;
  const SearchScreen({super.key, this.pickerMode = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final Set<String> _tagFilters = {};
  PaginationController<Recipe>? _pager;
  Timer? _debounce;
  String _query = '';
  bool _zeroLogged = false;

  static const _filterableTags = [
    'vegan', 'vegetarian', 'gluten-free', 'halal', 'kosher',
    'easy', 'le15', 'le30', 'le400', 'bake', 'grill',
  ];

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _pager?.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _query = value;
      _runSearch();
    });
  }

  Future<void> _runSearch() async {
    final state = context.read<AppState>();
    // Search spans the whole corpus: pull remaining partitions on demand.
    await state.corpus.ensureAllLoaded();
    final raw = state.corpus.searchIndex
        .query(_query, tagFilters: _tagFilters);
    final results = raw
        .where((r) => state.matcher.isVisible(r, state.profile))
        .toList();

    if (results.isEmpty && _query.trim().isNotEmpty && !_zeroLogged) {
      // Content-gap logging: zero-result queries are recorded locally and
      // exported with backups to inform corpus priorities.
      _zeroLogged = true;
      await state.logContentRequest(_query);
    } else if (results.isNotEmpty) {
      _zeroLogged = false;
    }

    final old = _pager;
    final pager = PaginationController<Recipe>(
      fetch: pagedResults(results),
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
    );
    if (!mounted) return;
    setState(() => _pager = pager);
    old?.dispose();
    await pager.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final pager = _pager;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: TextField(
              controller: _controller,
              onChanged: _onQueryChanged,
              style: MorphText.mono.copyWith(fontSize: 13),
              decoration: InputDecoration(
                hintText: s('searchHint'),
                hintStyle: MorphText.mono
                    .copyWith(fontSize: 13, color: MorphColors.inkFaint),
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: MorphColors.inkSoft),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: MorphColors.line)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: MorphColors.terracotta)),
              ),
            ),
          ),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                for (final tag in _filterableTags)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MonoChip(
                      label: state.corpus.ontology.nameOf(tag, state.lang),
                      selected: _tagFilters.contains(tag),
                      onTap: () {
                        setState(() {
                          _tagFilters.contains(tag)
                              ? _tagFilters.remove(tag)
                              : _tagFilters.add(tag);
                        });
                        _runSearch();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: pager == null
                ? const SizedBox.shrink()
                : ListenableBuilder(
                    listenable: pager,
                    builder: (context, _) => _results(pager, s),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _results(PaginationController<Recipe> pager, S s) {
    if (pager.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text('${s('searchEmpty')} "$_query"',
                textAlign: TextAlign.center,
                style: MorphText.display.copyWith(fontSize: 20)),
            const SizedBox(height: 10),
            Text(s('searchEmptyNote'),
                textAlign: TextAlign.center,
                style: MorphText.hand
                    .copyWith(fontSize: 18, color: MorphColors.inkSoft)),
          ],
        ),
      );
    }
    if (pager.items.isEmpty && pager.isLoading) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: const [
          SkeletonBlock(), SkeletonBlock(), SkeletonBlock(),
        ],
      );
    }
    final items = pager.items;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: items.length + (pager.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (pager.shouldLoadMore(index)) {
          scheduleMicrotask(pager.loadMore);
        }
        if (index >= items.length) return const SkeletonBlock();
        final recipe = items[index];
        return RecipeRow(
          recipe: recipe,
          index: index,
          onTap: widget.pickerMode
              ? () => Navigator.of(context).pop(recipe)
              : null,
        );
      },
    );
  }
}
