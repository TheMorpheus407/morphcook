import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/recipe.dart';
import '../services/pagination_controller.dart';
import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'dish_detail_screen.dart';
import 'faq_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  final Set<String> _tagFilters = {};
  String? _effortFilter;
  late PaginationController<Recipe> _paginationController;

  static const _quickTags = [
    'vegan',
    'keto',
    'halal',
    'gluten-free',
    'low-fodmap',
    'breakfast',
    'dinner',
    'pan-fry',
    'simmer',
  ];

  @override
  void initState() {
    super.initState();
    _paginationController = PaginationController<Recipe>.search(
      fetcher: _fetchSearchPage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _paginationController.refresh();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    _paginationController.dispose();
    super.dispose();
  }

  Future<PaginatedPageResult<Recipe>> _fetchSearchPage({
    required int pageIndex,
    required int offset,
    required int pageSize,
    String? cursor,
  }) async {
    final appState = context.read<MorphCookAppState>();
    final query = _queryController.text.trim();
    final result = await appState.corpus.searchRecipes(
      query: query,
      profile: appState.profile,
      tagFilters: _tagFilters,
      effortFilter: _effortFilter,
      cursor: cursor,
      pageSize: pageSize,
      now: appState.now,
      lastCookedByRecipeId: appState.lastCookedByRecipeId,
    );

    if (pageIndex == 0 && result.items.isEmpty && query.isNotEmpty) {
      await appState.logContentRequest(query);
    }

    return result;
  }

  void _triggerSearch() {
    _paginationController.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';

    return PaperGrainBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isDe ? 'rezept-archiv durchsuchen' : 'search kitchen index',
                        style: NostalgicTheme.serifDisplay(fontSize: 26),
                      ),
                    ),
                    IconButton(
                      tooltip: isDe ? 'Warum sehe ich bestimmte Rezepte?' : 'Recipe visibility FAQ',
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FaqScreen(
                              initialContextKey: 'calorie_filter',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('search_query_field'),
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: isDe
                        ? 'Titel, Zutat oder Technik suchen (z. B. Döner, Ramen, Safran)…'
                        : 'Search title, ingredient, or technique (e.g. Döner, Ramen, Saffron)…',
                    hintStyle: NostalgicTheme.mono(fontSize: 11.5),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _queryController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _queryController.clear();
                              _triggerSearch();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: NostalgicPalette.cardStock,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _triggerSearch(),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final eff in ['easy', 'medium', 'hard'])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            selected: _effortFilter == eff,
                            label: Text('effort:$eff'),
                            onSelected: (val) {
                              setState(() {
                                _effortFilter = val ? eff : null;
                              });
                              _triggerSearch();
                            },
                          ),
                        ),
                      for (final tag in _quickTags)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            key: ValueKey('search_tag_$tag'),
                            selected: _tagFilters.contains(tag),
                            label: Text('#$tag'),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _tagFilters.add(tag);
                                } else {
                                  _tagFilters.remove(tag);
                                }
                              });
                              _triggerSearch();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: DashedRule(),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _paginationController,
              builder: (context, _) {
                final items = _paginationController.items;
                final isLoading = _paginationController.isLoading;

                if (items.isEmpty && isLoading) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: 4,
                    itemBuilder: (_, _) => Container(
                      height: 82,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: NostalgicPalette.agedPaper.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  );
                }

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 40,
                            color: NostalgicPalette.fadedInk,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isDe
                                ? 'Noch kein passendes Rezept im Korpus gefunden.'
                                : 'No matching recipe found in the corpus yet.',
                            textAlign: TextAlign.center,
                            style: NostalgicTheme.serifDisplay(fontSize: 20),
                          ),
                          if (_queryController.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              isDe
                                  ? '„${_queryController.text.trim()}“ wurde lokal als Rezeptwunsch (content_requests) notiert.'
                                  : 'Logged “${_queryController.text.trim()}” to your local content_requests list.',
                              textAlign: TextAlign.center,
                              style: NostalgicTheme.handwritten(
                                fontSize: 18,
                                color: NostalgicPalette.terracotta,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  itemCount: items.length + (_paginationController.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_paginationController.shouldLoadMore(index)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _paginationController.loadMore();
                      });
                    }
                    if (index >= items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final recipe = items[index];
                    final dish = appState.corpus.dishById(recipe.dishId);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: NostalgicPalette.cardStock,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: NostalgicPalette.mutedRule),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        title: Text(
                          recipe.title.resolve(lang),
                          style: NostalgicTheme.serifDisplay(fontSize: 18),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              recipe.subtitle.resolve(lang),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: NostalgicTheme.serifBody(
                                fontSize: 13.5,
                                color: NostalgicPalette.fadedInk,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${recipe.dietDimension}  ·  ${recipe.effort}  ·  ${recipe.timeMinutes}m  ·  ~${recipe.caloriesPerServing} kcal',
                              style: NostalgicTheme.mono(
                                fontSize: 11,
                                color: NostalgicPalette.terracotta,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          if (dish != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => DishDetailScreen(
                                  dish: dish,
                                  initialRecipe: recipe,
                                ),
                              ),
                            );
                          }
                        },
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
