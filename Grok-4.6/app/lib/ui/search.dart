import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../logic/pagination.dart';
import '../logic/search.dart';
import '../models/recipe.dart';
import 'home.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  final Set<String> _tags = {};
  PaginationController<Recipe>? _pager;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    if (!mounted) return;
    setState(() => _ready = true);
    _run();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    if (_query.text.trim().isNotEmpty) {
      await state.corpus.ensureAllLoaded();
    }
    if (!mounted) return;
    var results = state.corpus.searchIndex.query(_query.text, tagFilters: _tags);
    results = results
        .where((r) => state.matcher.isVisible(r, state.profile))
        .toList();
    results = collapseCoverageVariants(
      state.ranker.rank(results, state.profile, state.history),
    );
    if (results.isEmpty && _query.text.trim().isNotEmpty) {
      state.logContentRequest(_query.text);
    }
    _pager?.dispose();
    _pager = PaginationController<Recipe>(
      fetch: pagedResults(results),
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
    )..addListener(() => setState(() {}));
    _pager!.loadMore();
    setState(() {});
  }

  @override
  void dispose() {
    _query.dispose();
    _pager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final pager = _pager;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('navSearch'), style: Theme.of(context).textTheme.displayMedium),
                TextField(
                  controller: _query,
                  onSubmitted: (_) => _run(),
                  onChanged: (_) => _run(),
                  decoration: InputDecoration(
                    hintText: s('searchHint'),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _run,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in ['easy', 'medium', 'hard', 'le30', 'le60', 'bake', 'grill'])
                      SoftChip(
                        label: state.corpus.ontology.nameOf(tag, state.lang),
                        selected: _tags.contains(tag),
                        onTap: () {
                          setState(() {
                            if (!_tags.add(tag)) _tags.remove(tag);
                          });
                          _run();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: !_ready
                ? Center(child: Text(s('loading')))
                : pager == null
                    ? const SizedBox.shrink()
                    : pager.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '${s('searchEmpty')} “${_query.text}”.\n${s('searchEmptyNote')}',
                              style: TextStyle(
                                fontFamily: LedgerTheme.caveat,
                                fontSize: 22,
                                color: p.walnutSoft,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: pager.items.length + (pager.hasMore ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (pager.shouldLoadMore(i)) pager.loadMore();
                              if (i >= pager.items.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              }
                              final recipe = pager.items[i];
                              final dish = state.corpus.dishById(recipe.dishId);
                              return ListTile(
                                title: Text(recipe.title.of(state.lang)),
                                subtitle: Text(
                                  '${dish?.name.of(state.lang) ?? recipe.dishId}  ·  ${recipe.timeMinutes} ${s('minutes')}',
                                ),
                                onTap: () => openDish(
                                  context,
                                  recipe.dishId,
                                  recipeId: recipe.id,
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
