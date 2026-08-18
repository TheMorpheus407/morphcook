import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../logic/pagination.dart';
import '../models/recipe.dart';
import '../state/app_state.dart';
import '../widgets/recipe_card.dart';
import 'home.dart';

/// Search: free text + tag filters, cursor-based pagination (20/page,
/// prefetch 10, max rendered 50). Results respect profile filters.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  final Set<String> _cuisines = {};
  final Set<String> _meals = {};
  final Set<String> _efforts = {};
  PaginationController<Recipe>? _pagination;
  String _lastQuery = '';

  @override
  void dispose() {
    _query.dispose();
    _pagination?.dispose();
    super.dispose();
  }

  Future<PageSlice<Recipe>> _fetch(int offset, String? cursor) async {
    final corpus = context.read<Corpus>();
    final store = context.read<AppStore>();
    final matcher = context.read<Matcher>();
    await corpus.loadPartition('extended');

    List<Recipe> all;
    if (_query.text.trim().isEmpty) {
      all = corpus.allRecipes.toList();
    } else {
      final ids = corpus.searchIds(_query.text.trim());
      all = [for (final id in ids) if (corpus.recipe(id) != null) corpus.recipe(id)!];
    }

    final filtered = matcher.filter(all, store.profile).where((r) {
      if (_cuisines.isNotEmpty && !_cuisines.contains(r.cuisine)) return false;
      if (_meals.isNotEmpty &&
          r.mealTypes.intersection(_meals).isEmpty &&
          !r.mealTypes.contains('any')) {
        return false;
      }
      if (_efforts.isNotEmpty && !_efforts.contains(r.effort)) return false;
      return true;
    }).toList();

    if (_query.text.trim().isNotEmpty && filtered.isEmpty) {
      store.addContentRequest(_query.text.trim());
    }

    return PageSlice.cursor(filtered, offset, 20);
  }

  void _search() {
    final q = _query.text.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    _pagination?.dispose();
    _pagination = PaginationController<Recipe>(
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      type: PaginationType.cursor,
      fetcher: _fetch,
    );
    setState(() {});
    _pagination!.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Masthead(subtitle: context.t('tabSearch')),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: TextField(
                controller: _query,
                decoration: InputDecoration(
                  hintText: context.t('searchHint'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    onPressed: _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
                onChanged: (_) {
                  if (_query.text.trim().isEmpty) {
                    _lastQuery = '';
                    _pagination?.refresh();
                  }
                },
              ),
            ),
            _filters(context),
            Expanded(
              child: ListenableBuilder(
                listenable: _pagination ?? _Noop(),
                builder: (context, _) {
                  final p = _pagination;
                  if (p == null || (p.isInitialLoading && _query.text.trim().isNotEmpty)) {
                    return _prompt(context);
                  }
                  final items = p.renderedItems;
                  if (items.isEmpty && !p.loading) {
                    return _noResults(context);
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.axis == Axis.vertical &&
                          n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
                        p.loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      itemCount: items.length + (p.hasMore ? 2 : 0),
                      itemBuilder: (context, i) {
                        if (i >= items.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.6, color: MC.coral),
                              ),
                            ),
                          );
                        }
                        final recipe = items[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: RecipeCard(
                            recipe: recipe,
                            rotation: _rot(recipe.id),
                            onTap: () => openDish(context, recipe.dishId),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final corpus = context.corpus;
    final cuisines = <String>{for (final r in corpus.allRecipes) r.cuisine}.toList();
    final meals = ['breakfast', 'lunch', 'dinner'];
    final efforts = ['easy', 'medium', 'hard'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in cuisines)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(context.t('cuisine.$c') == 'cuisine.$c' ? c : context.t('cuisine.$c')),
                      selected: _cuisines.contains(c),
                      onSelected: (v) => setState(() {
                        v ? _cuisines.add(c) : _cuisines.remove(c);
                        _pagination?.refresh();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in meals)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(context.t('meal.$m')),
                      selected: _meals.contains(m),
                      onSelected: (v) => setState(() {
                        v ? _meals.add(m) : _meals.remove(m);
                        _pagination?.refresh();
                      }),
                    ),
                  ),
                for (final e in efforts)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(context.t('effort.$e')),
                      selected: _efforts.contains(e),
                      onSelected: (v) => setState(() {
                        v ? _efforts.add(e) : _efforts.remove(e);
                        _pagination?.refresh();
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.t('searchHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 22,
                color: MC.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noResults(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40, color: MC.inkFaint),
            const SizedBox(height: 12),
            Text(
              context.t('searchNoResults'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.t('searchZeroNote'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: MC.inkFaint),
            ),
          ],
        ),
      ),
    );
  }

  double _rot(String id) {
    const rot = [0.7, -0.9, 0.5, -0.6, 1.0];
    return rot[id.codeUnits.fold<int>(0, (a, b) => a + b) % rot.length];
  }
}

class _Noop extends ChangeNotifier {}
