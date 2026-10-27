import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../services/pagination.dart';
import '../state/app_state.dart';
import '../widgets/paper_widgets.dart';
import '../widgets/recipe_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onOpenRecipe});
  final void Function(Dish dish, Recipe recipe) onOpenRecipe;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController queryController = TextEditingController();
  final Set<String> selectedTags = {};
  late final PaginationController<Recipe> pages;
  Timer? debounce;
  String? loggedQuery;

  @override
  void initState() {
    super.initState();
    final app = context.read<AppState>();
    pages = PaginationController<Recipe>(
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      loader: (cursor, offset) => app.repository
          .search(
            queryController.text,
            selectedTags,
            app.profile,
            after: cursor,
            now: app.clock(),
            lastCooked: app.lastCooked,
          )
          .then(
            (page) => PaginationPage(
              items: page.recipes,
              nextCursor: page.nextCursor,
            ),
          ),
    )..addListener(onPagesChanged);
    pages.loadMore();
  }

  void onPagesChanged() {
    if (!mounted) return;
    setState(() {});
    if (pages.initialized && !pages.isLoading && pages.items.isEmpty) {
      final query = queryController.text.trim();
      if (query.isNotEmpty && loggedQuery != query) {
        loggedQuery = query;
        context.read<AppState>().recordContentRequest(query);
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    queryController.dispose();
    pages
      ..removeListener(onPagesChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    const filters = [
      'quick',
      'vegan',
      'keto',
      'gluten-free',
      'breakfast',
      'dinner',
      'comfort-food',
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.t('search_title'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: Paper(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                child: TextField(
                  controller: queryController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.l10n.t('search_hint'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: queryController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              queryController.clear();
                              refresh();
                            },
                            icon: const Icon(Icons.close),
                            tooltip: context.l10n.t('clear'),
                          ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    debounce?.cancel();
                    debounce = Timer(
                      const Duration(milliseconds: 280),
                      refresh,
                    );
                  },
                  onSubmitted: (_) => refresh(),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final tag = filters[index];
                    return FilterChip(
                      label: Text(context.l10n.tag(tag)),
                      selected: selectedTags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                        refresh();
                      },
                    );
                  },
                ),
              ),
              const DashedRule(),
              Expanded(
                child: !pages.initialized && pages.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: LoadingList(),
                      )
                    : pages.error != null &&
                          pages.items.isEmpty &&
                          !pages.isLoading
                    ? EmptyState(
                        title: context.l10n.t('list_error'),
                        body: context.l10n.t('search_empty_body'),
                        action: OutlinedButton(
                          onPressed: pages.loadMore,
                          child: Text(context.l10n.t('retry')),
                        ),
                      )
                    : pages.items.isEmpty && !pages.isLoading
                    ? EmptyState(
                        title: context.l10n.t('search_empty'),
                        body: queryController.text.trim().isEmpty
                            ? context.l10n.t('home_empty_body')
                            : context.l10n.t('search_empty_body'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        itemCount:
                            pages.items.length +
                            (pages.hasMore || pages.isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= pages.items.length) {
                            if (pages.shouldLoadMore(index - 1)) {
                              Future.microtask(pages.loadMore);
                            }
                            return Padding(
                              padding: const EdgeInsets.all(18),
                              child: Center(
                                child: pages.error != null
                                    ? TextButton(
                                        onPressed: pages.loadMore,
                                        child: Text(
                                          context.l10n.t('list_error'),
                                        ),
                                      )
                                    : Text(
                                        context.l10n.t('loading_more'),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                              ),
                            );
                          }
                          if (pages.shouldLoadMore(index)) {
                            Future.microtask(pages.loadMore);
                          }
                          final recipe = pages.items[index];
                          final dish = app.repository.dishes[recipe.dishId]!;
                          return RecipeListTile(
                            dish: dish,
                            recipe: recipe,
                            onTap: () => widget.onOpenRecipe(dish, recipe),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void refresh() {
    loggedQuery = null;
    pages.refresh();
  }
}
