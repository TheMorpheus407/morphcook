import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/copy.dart';
import '../models/recipe.dart';
import '../services/pagination_controller.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/recipe_card.dart';
import '../widgets/states.dart';
import 'recipe_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _search = TextEditingController();
  final _selectedTags = <String>{};
  PaginationController<Recipe>? _pagination;
  Timer? _debounce;
  AppController? _app;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.read<AppController>();
    if (_app != app) {
      _app = app;
      _resetPagination();
    }
  }

  void _resetPagination() {
    _pagination?.dispose();
    final app = _app!;
    _pagination = PaginationController<Recipe>(
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      loader: (cursor, limit) async {
        final all = await app.search(_search.text, tags: _selectedTags);
        final offset = int.tryParse(cursor ?? '0') ?? 0;
        if (offset >= all.length) return const PageChunk(items: []);
        final end = (offset + limit).clamp(0, all.length);
        return PageChunk(
          items: all.sublist(offset, end),
          nextCursor: end < all.length ? '$end' : null,
        );
      },
    )..addListener(_pageChanged);
    _pagination!.loadMore();
  }

  void _pageChanged() {
    if (mounted) setState(() {});
  }

  void _queryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(_resetPagination);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pagination
      ?..removeListener(_pageChanged)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final pagination = _pagination;
    return Column(
      children: [
        ScreenHeader(title: Copy.text('search', lang)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _queryChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: Copy.text('search_hint', lang),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        setState(_resetPagination);
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 45,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: ['quick', 'vegan', 'gluten-free', 'comfort', 'breakfast']
                .map(
                  (tag) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: FilterChip(
                      selected: _selectedTags.contains(tag),
                      label: Text(app.ontology.label(tag, lang)),
                      onSelected: (_) {
                        setState(() {
                          _selectedTags.contains(tag)
                              ? _selectedTags.remove(tag)
                              : _selectedTags.add(tag);
                          _resetPagination();
                        });
                      },
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const DashedRule(),
        Expanded(
          child:
              pagination == null ||
                  (pagination.isLoading && pagination.items.isEmpty)
              ? const EditorialSkeleton(rows: 4)
              : pagination.items.isEmpty
              ? EmptyPageNote(
                  icon: Icons.search_off,
                  title: Copy.text('no_results', lang),
                )
              : ListView.builder(
                  key: const PageStorageKey('search-results'),
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      pagination.items.length +
                      (pagination.isLoading || pagination.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= pagination.items.length) {
                      pagination.loadMore();
                      return const Padding(
                        padding: EdgeInsets.all(22),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (pagination.shouldLoadMore(index)) pagination.loadMore();
                    final recipe = pagination.items[index];
                    final dish = app.content.dishById(recipe.dishId)!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 17),
                      child: RecipeCard(
                        recipe: recipe,
                        dish: dish,
                        language: lang,
                        dietLabel: app.ontology.label(recipe.diet, lang),
                        compact: true,
                        saved: app.savedIds.contains(recipe.id),
                        onSave: () => app.toggleSaved(recipe.id),
                        onTap: () =>
                            openRecipeDetail(context, recipe.dishId, recipe.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
            ?trailing,
          ],
        ),
      ),
      const Divider(thickness: 2),
    ],
  );
}
