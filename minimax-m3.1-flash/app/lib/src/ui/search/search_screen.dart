import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/search_index.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../domain/pagination_controller.dart';
import '../../l10n/strings.dart';
import '../../models/recipe.dart';
import '../../state/app_state.dart';
import '../dish/dish_detail_screen.dart';

/// Search — free text plus tag filters, respecting the profile filters.
///
/// Cursor-based pagination, 20 to a page, prefetching 10 items ahead.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  SearchIndex? _index;

  late PaginationController<Recipe> _pagination;
  String _query = '';
  String _tag = _allTag;
  bool _loggedRequest = false;

  static const String _allTag = 'all';

  @override
  void initState() {
    super.initState();
    _pagination = PaginationController<Recipe>(
      type: PaginationType.cursor,
      pageSize: 20,
      prefetchThreshold: 10,
      maxRendered: 50,
      fetchPage: (request) async {
        final state = context.read<AppState>();
        await state.corpus.loadAll();
        final index = _index ??= SearchIndex.fromRecipes(state.corpus.allRecipes);
        final profile = state.profile.profile;

        final visible = state.corpus.allRecipes
            .where((recipe) => state.matcher.isVisible(recipe, profile))
            .toList();

        final hits = index.search(_query, universe: visible);
        final filtered = _applyTag(hits);

        final offset = int.tryParse(request.cursor ?? '0') ?? 0;
        final slice = filtered.skip(offset).take(request.limit).toList();
        return PageResult<Recipe>(
          items: slice,
          nextCursor: '${offset + slice.length}',
          hasMore: offset + slice.length < filtered.length,
        );
      },
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _pagination.dispose();
    super.dispose();
  }

  List<Recipe> _applyTag(List<SearchHit> hits) {
    if (_tag == _allTag) return hits.map((hit) => hit.recipe).toList();
    return hits
        .where((hit) => _tagsOf(hit.recipe).contains(_tag))
        .map((hit) => hit.recipe)
        .toList();
  }

  List<String> _tagsOf(Recipe recipe) {
    final tags = <String>{recipe.diet, recipe.effort};
    tags.addAll(recipe.mealSlots);
    return tags.toList();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _loggedRequest = false;
      });
      _pagination.reset();
      _pagination.loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final profile = state.profile.profile;

    // The search universe is filtered by the profile, so the tag filter
    // reflects only what the user can actually see.
    final availableTags = <String>{};
    for (final recipe in state.corpus.allRecipes) {
      if (!state.matcher.isVisible(recipe, profile)) continue;
      availableTags.add(recipe.diet);
      availableTags.add(recipe.effort);
      availableTags.addAll(recipe.mealSlots);
    }

    final tags = availableTags.toList()..sort();

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 18,
              20,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(strings.navSearch.toUpperCase(), style: Type.display(size: 30)),
                const SizedBox(height: 12),
                _SearchField(
                  controller: _controller,
                  hint: strings.searchHint,
                  onChanged: _onQueryChanged,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 30,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: <Widget>[
                      _TagFilter(
                        label: strings.searchFilterAll,
                        selected: _tag == _allTag,
                        onTap: () => _selectTag(_allTag),
                      ),
                      for (final tag in tags)
                        _TagFilter(
                          label: _tagLabel(tag, strings),
                          selected: _tag == tag,
                          onTap: () => _selectTag(tag),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const DashedRule(),
              ],
            ),
          ),
        ),
        if (_query.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: 'search the cookbook',
              message: 'dishes, ingredients, moods — whatever you have in mind',
              glyph: '⌕',
            ),
          )
        else if (_pagination.items.isEmpty && !_pagination.isLoading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: strings.searchNoResults,
              message: strings.searchNoResultsBody,
              glyph: '∅',
              action: _loggedRequest
                  ? null
                  : GhostButton(
                      label: strings.searchLogRequest,
                      icon: Icons.bookmark_add_outlined,
                      onPressed: () {
                        context
                            .read<AppState>()
                            .history
                            .logContentRequest(_query);
                        setState(() => _loggedRequest = true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.searchNoResultsBody)),
                        );
                      },
                    ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            sliver: SliverList.builder(
              itemCount: _pagination.items.length,
              itemBuilder: (context, index) {
                final recipe = _pagination.items[index];
                if (_pagination.shouldLoadMore(index)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _pagination.loadMore();
                  });
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SearchRow(
                    recipe: recipe,
                    strings: strings,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DishDetailScreen(dishId: recipe.dishId),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        SliverToBoxAdapter(
          child: PageLoadingIndicator(
            visible: _pagination.isLoading && _pagination.items.isNotEmpty,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  void _selectTag(String tag) {
    setState(() => _tag = tag);
    _pagination.reset();
    _pagination.loadMore();
  }

  String _tagLabel(String tag, Strings strings) {
    switch (tag) {
      case 'breakfast':
        return strings.planBreakfast;
      case 'lunch':
        return strings.planLunch;
      case 'dinner':
        return strings.planDinner;
      default:
        return strings.dietLabel(tag);
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: Type.body(size: 15.5, color: MC.ink),
      cursorColor: MC.coral,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Type.body(size: 14.5, color: MC.inkGhost),
        prefixIcon: const Icon(Icons.search_rounded, size: 19, color: MC.inkFaint),
        filled: true,
        fillColor: MC.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: MC.ruleFaint),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: MC.ruleFaint),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: MC.coral, width: 1.4),
        ),
      ),
    );
  }
}

class _TagFilter extends StatelessWidget {
  const _TagFilter({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? MC.coral : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: selected ? MC.coral : MC.rule),
          ),
          child: Text(
            label.toUpperCase(),
            style: Type.label(
              size: 9.5,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? MC.card : MC.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.recipe,
    required this.strings,
    required this.onTap,
  });

  final Recipe recipe;
  final Strings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: MC.ruleFaint)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipe.title.resolve(strings.lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.title(size: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      recipe.heroText.resolve(strings.lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.small(size: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${recipe.timeMinutes} min',
                    style: Type.label(size: 9.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${recipe.calories} kcal',
                    style: Type.label(size: 9.5, color: MC.inkGhost),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
