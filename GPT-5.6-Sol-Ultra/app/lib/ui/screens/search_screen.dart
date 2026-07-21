import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/recipe_repository.dart';
import '../../domain/models/dish.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/search.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../../services/pagination_controller.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';
import '../widgets/striped_placeholder.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({
    required this.repository,
    required this.profile,
    required this.dishesById,
    required this.isSaved,
    required this.onToggleSaved,
    required this.onOpenRecipe,
    required this.onContentGap,
    super.key,
  });

  final RecipeRepository repository;
  final UserProfile profile;
  final Map<String, Dish> dishesById;
  final bool Function(String recipeId) isSaved;
  final Future<void> Function(Recipe recipe) onToggleSaved;
  final ValueChanged<Recipe> onOpenRecipe;
  final Future<void> Function(String query) onContentGap;

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  late PaginationController<RecipeSearchResult> _pagination;
  Set<String> _tags = {};
  Set<String> _cuisines = {};
  Set<String> _mealTypes = {};
  int _totalMatches = 0;
  String? _lastLoggedGap;
  Object? _activeSearchToken;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pagination = _makeController();
    _pagination.addListener(_changed);
    unawaited(_pagination.loadMore());
  }

  @override
  void didUpdateWidget(covariant RecipeSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile ||
        oldWidget.repository != widget.repository) {
      _restart();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _activeSearchToken = null;
    _pagination
      ..removeListener(_changed)
      ..dispose();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  PaginationController<RecipeSearchResult> _makeController() {
    final searchToken = Object();
    _activeSearchToken = searchToken;
    final text = _query.text;
    final tags = Set<String>.of(_tags);
    final cuisines = Set<String>.of(_cuisines);
    final mealTypes = Set<String>.of(_mealTypes);
    return PaginationController<RecipeSearchResult>(
      policy: const PaginationPolicy.search(),
      loader: (request) async {
        final page = await widget.repository.search(
          SearchQuery(
            text: text,
            languageCode: widget.profile.languageCode,
            tags: tags,
            cuisineTags: cuisines,
            mealTypes: mealTypes,
            cursor: request.cursor,
            pageSize: request.limit,
          ),
          widget.profile,
        );
        if (mounted && identical(_activeSearchToken, searchToken)) {
          _totalMatches = page.totalMatches;
          final normalized = text.trim().toLowerCase();
          if (normalized.isNotEmpty &&
              page.totalMatches == 0 &&
              _lastLoggedGap != normalized) {
            _lastLoggedGap = normalized;
            unawaited(widget.onContentGap(text.trim()));
          }
        }
        return PaginationPage(
          items: page.items,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
        );
      },
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 330), _restart);
  }

  void _restart() {
    final old = _pagination;
    old.removeListener(_changed);
    _pagination = _makeController()..addListener(_changed);
    old.dispose();
    _totalMatches = 0;
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (mounted) setState(() {});
    unawaited(_pagination.loadMore());
  }

  void _toggle(Set<String> current, String value) {
    setState(
      () =>
          current.contains(value) ? current.remove(value) : current.add(value),
    );
    _restart();
  }

  void _clear() {
    _query.clear();
    _tags = {};
    _cuisines = {};
    _mealTypes = {};
    _restart();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final strings = context.strings;
    final activeFilters = _tags.length + _cuisines.length + _mealTypes.length;
    return PaperSurface(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings('search.title'),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                      ),
                      if (_query.text.isNotEmpty || activeFilters > 0)
                        TextButton(
                          onPressed: _clear,
                          child: Text(strings('common.clear')),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    onChanged: _onQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: strings('search.hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _query.clear();
                                _restart();
                              },
                              tooltip: strings('common.clear'),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  _FilterStrip(
                    profile: widget.profile,
                    tags: _tags,
                    cuisines: _cuisines,
                    mealTypes: _mealTypes,
                    onTag: (value) => _toggle(_tags, value),
                    onCuisine: (value) => _toggle(_cuisines, value),
                    onMealType: (value) => _toggle(_mealTypes, value),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Text(
                        strings
                            .plural('search.results', _totalMatches)
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: DashedRule(dash: 3, gap: 4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_pagination.isInitialLoading) {
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, _) => const MorphSkeleton(height: 142),
      );
    }
    if (_pagination.error != null && _pagination.items.isEmpty) {
      return MorphErrorState(
        message: context.strings('common.errorBody'),
        onRetry: _pagination.loadMore,
      );
    }
    if (_pagination.items.isEmpty) {
      return MorphEmptyState(
        icon: Icons.search_off_rounded,
        title: context.strings('search.noResultsTitle'),
        message: _query.text.trim().isEmpty
            ? context.strings('common.noResults')
            : context.strings('search.noResultsBody'),
        action: _query.text.isEmpty ? null : _clear,
        actionLabel: context.strings('common.clear'),
      );
    }

    return RefreshIndicator(
      onRefresh: _pagination.refresh,
      child: ListView.builder(
        key: const PageStorageKey('recipe-search-results'),
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        itemCount: _pagination.items.length + (_pagination.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _pagination.items.length) {
            unawaited(_pagination.loadMore());
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: MorphSkeleton(height: 92),
            );
          }
          if (_pagination.shouldLoadMore(index)) {
            unawaited(_pagination.loadMore());
          }
          final result = _pagination.items[index];
          final recipe = result.recipe;
          final dish = widget.dishesById[recipe.dishId];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SearchResultCard(
              recipe: recipe,
              dish: dish,
              profile: widget.profile,
              matchedTokens: result.matchedTokens,
              saved: widget.isSaved(recipe.id),
              onOpen: () => widget.onOpenRecipe(recipe),
              onSave: () async {
                await widget.onToggleSaved(recipe);
                if (mounted) setState(() {});
              },
            ),
          );
        },
      ),
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.profile,
    required this.tags,
    required this.cuisines,
    required this.mealTypes,
    required this.onTag,
    required this.onCuisine,
    required this.onMealType,
  });

  final UserProfile profile;
  final Set<String> tags;
  final Set<String> cuisines;
  final Set<String> mealTypes;
  final ValueChanged<String> onTag;
  final ValueChanged<String> onCuisine;
  final ValueChanged<String> onMealType;

  @override
  Widget build(BuildContext context) {
    const tagValues = ['quick', 'comfort-food', 'plant-based'];
    const cuisineValues = [
      'italian-inspired',
      'southeast-asian',
      'middle-eastern-inspired',
    ];
    const mealValues = ['breakfast', 'lunch', 'dinner'];
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return SizedBox(
      height: 42 * textScale.clamp(1, 1.6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final value in tagValues) ...[
            MorphTag(
              label: context.strings.option('filter.tag', value),
              selected: tags.contains(value),
              onSelected: (_) => onTag(value),
            ),
            const SizedBox(width: 7),
          ],
          for (final value in cuisineValues) ...[
            MorphTag(
              label: context.strings.option('filter.cuisine', value),
              selected: cuisines.contains(value),
              onSelected: (_) => onCuisine(value),
            ),
            const SizedBox(width: 7),
          ],
          for (final value in mealValues) ...[
            MorphTag(
              label: context.strings('plan.$value'),
              selected: mealTypes.contains(value),
              onSelected: (_) => onMealType(value),
            ),
            const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.recipe,
    required this.dish,
    required this.profile,
    required this.matchedTokens,
    required this.saved,
    required this.onOpen,
    required this.onSave,
  });

  final Recipe recipe;
  final Dish? dish;
  final UserProfile profile;
  final Set<String> matchedTokens;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final language = profile.languageCode;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cardHeight = (142 + (textScale.clamp(1, 2) - 1) * 90).toDouble();
    return Material(
      color: context.morph.paper,
      elevation: 1,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        onTap: onOpen,
        child: SizedBox(
          height: cardHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 126,
                child: StripedPlaceholder(
                  caption:
                      dish?.caption.resolve(language) ??
                      context.strings.option('diet', recipe.diet),
                  color: _parseColor(dish?.stripeColor, context.morph.teal),
                  height: cardHeight,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 12, 4, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.name.resolve(language),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        context.strings.format('common.recipeMeta', {
                          'minutes': recipe.timeMinutes,
                          'calories': recipe.caloriesPerServing,
                        }).toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      if (profile.showVariantTags) ...[
                        const SizedBox(height: 7),
                        Text(
                          [
                            context.strings.option('diet', recipe.diet),
                            context.strings.option('effort', recipe.effort),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (matchedTokens.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          matchedTokens.take(3).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.morph.coral),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: IconButton(
                  onPressed: onSave,
                  tooltip: saved
                      ? context.strings('common.removeFromCookbook')
                      : context.strings('common.saveToCookbook'),
                  icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _parseColor(String? value, Color fallback) {
  if (value == null) return fallback;
  final cleaned = value.replaceFirst('#', '');
  final parsed = int.tryParse(cleaned, radix: 16);
  if (parsed == null) return fallback;
  return Color(cleaned.length == 6 ? 0xFF000000 | parsed : parsed);
}
