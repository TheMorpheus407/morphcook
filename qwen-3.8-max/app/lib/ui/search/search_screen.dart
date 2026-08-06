import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../domain/pagination.dart';
import '../../domain/search.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../dish/dish_screen.dart';
import '../widgets.dart';

/// Search: free text over the bundled index, results respect profile
/// filters. Cursor-based pagination (20/page) with prefetch; zero-result
/// queries are logged as content requests.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  PaginationController<String>? _controller;
  String _activeQuery = '';
  bool _zeroLogged = false;
  final Set<String> _activeTags = {};

  static const _tagFilters = [
    'vegan',
    'vegetarian',
    'keto',
    'gluten-free',
    'halal',
    'comfort',
    'one-pan',
    'meal-prep',
  ];

  static const _pageSize = 20;
  static const _prefetch = 10;

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(_effectiveQuery(value));
    });
  }

  /// Free text + tag filters: active tags are ANDed into the query.
  String _effectiveQuery(String text) {
    final parts = [text.trim(), ..._activeTags]..removeWhere((p) => p.isEmpty);
    return parts.join(' ');
  }

  void _toggleTag(String tag) {
    setState(() {
      _activeTags.contains(tag)
          ? _activeTags.remove(tag)
          : _activeTags.add(tag);
    });
    _runSearch(_effectiveQuery(_query.text));
  }

  void _runSearch(String value) {
    if (!mounted) return;
    final app = context.read<AppModel>();
    final corpus = context.read<CorpusRepository>();
    final search = SearchService(corpus);

    _activeQuery = value;
    _zeroLogged = false;
    _controller?.dispose();
    _controller = PaginationController<String>(
      pageSize: _pageSize,
      prefetchThreshold: _prefetch,
      maxRendered: 50,
      fetchPage: (offset, limit) async {
        final page = await search.search(
          _activeQuery,
          cursor: offset == 0 ? null : SearchService.encodeCursor(offset),
          profile: app.profile,
        );
        if (page.isEmpty && offset == 0 && !_zeroLogged) {
          _zeroLogged = true;
          if (mounted) {
            context.read<LibraryModel>().logContentRequest(_activeQuery);
          }
        }
        return page.recipeIds;
      },
    );
    setState(() {});
    _controller!.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final corpus = context.read<CorpusRepository>();
    final library = context.watch<LibraryModel>();
    final s = app.strings;
    final lang = app.lang;
    final controller = _controller;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.get('search'), style: Type.displayBold(size: 30)),
                const SizedBox(height: 12),
                PaperField(
                  controller: _query,
                  hint: s.get('searchPlaceholder'),
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final tag in _tagFilters)
                        PaperChip(
                          label: tag,
                          selected: _activeTags.contains(tag),
                          onTap: () => _toggleTag(tag),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller == null
                ? EmptyNote(title: '…')
                : AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      if (controller.isLoading && controller.items.isEmpty) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: 5,
                          itemBuilder: (_, _) => const SkeletonCard(),
                        );
                      }
                      if (controller.items.isEmpty) {
                        return EmptyNote(
                          title: s.get('noResults'),
                          note: _activeQuery.isNotEmpty
                              ? s.get('noResultsNote')
                              : null,
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        itemCount:
                            controller.items.length + (controller.hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= controller.items.length) {
                            if (controller.shouldLoadMore(index - 1)) {
                              controller.loadMore();
                            }
                            return const Padding(
                              padding: EdgeInsets.all(8),
                              child: SkeletonCard(),
                            );
                          }
                          if (controller.shouldLoadMore(index)) {
                            controller.loadMore();
                          }
                          final recipe = corpus.recipe(controller.items[index]);
                          if (recipe == null) return const SizedBox.shrink();
                          final dish = corpus.dish(recipe.dishId);
                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => DishScreen(
                                  dishId: recipe.dishId,
                                  initialRecipeId: recipe.id,
                                ),
                              ));
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Paper.white,
                                border: Border.all(color: Paper.rule),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    color: StripedPlaceholder.parseHex(
                                        dish?.stripeColor ?? '#C2703F'),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(tx(recipe.title, lang),
                                            style: Type.display(size: 15)),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal · ${tx(dish?.name, lang)}',
                                          style: Type.mono(
                                              size: 10,
                                              color: Paper.inkSoft),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (library.isSaved(recipe.id))
                                    Text('★',
                                        style: Type.mono(
                                            size: 13, color: Paper.coral)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
