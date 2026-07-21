import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/dish.dart';
import '../../domain/models/local_state.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../../services/pagination_controller.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';
import '../widgets/striped_placeholder.dart';

class CookbookScreen extends StatefulWidget {
  const CookbookScreen({
    required this.savedRecipes,
    required this.recipesById,
    required this.dishesById,
    required this.profile,
    required this.onOpenRecipe,
    required this.onRemoveSaved,
    required this.onBrowse,
    super.key,
  });

  final List<SavedRecipe> savedRecipes;
  final Map<String, Recipe> recipesById;
  final Map<String, Dish> dishesById;
  final UserProfile profile;
  final ValueChanged<Recipe> onOpenRecipe;
  final Future<void> Function(Recipe recipe) onRemoveSaved;
  final VoidCallback onBrowse;

  @override
  State<CookbookScreen> createState() => _CookbookScreenState();
}

class _CookbookScreenState extends State<CookbookScreen>
    with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  late PaginationController<SavedRecipe> _pagination;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pagination = _createController()..addListener(_changed);
    unawaited(_pagination.loadMore());
  }

  @override
  void didUpdateWidget(covariant CookbookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.savedRecipes.map((item) => item.recipeId);
    final newIds = widget.savedRecipes.map((item) => item.recipeId);
    if (!const IterableEquality<String>().equals(oldIds, newIds)) _restart();
  }

  @override
  void dispose() {
    _pagination
      ..removeListener(_changed)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  List<SavedRecipe> get _filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.savedRecipes;
    return widget.savedRecipes.where((saved) {
      final recipe = widget.recipesById[saved.recipeId];
      if (recipe == null) return false;
      final language = widget.profile.languageCode;
      return recipe.name.resolve(language).toLowerCase().contains(query) ||
          recipe.name.resolve('en').toLowerCase().contains(query) ||
          recipe.tags.any((tag) => tag.toLowerCase().contains(query));
    }).toList();
  }

  PaginationController<SavedRecipe> _createController() {
    final source = List<SavedRecipe>.of(_filtered);
    return PaginationController(
      policy: const PaginationPolicy.cookbook(),
      loader: (request) async {
        final start = request.offset.clamp(0, source.length);
        final end = (start + request.limit).clamp(start, source.length);
        return PaginationPage(
          items: source.sublist(start, end),
          hasMore: end < source.length,
        );
      },
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _restart() {
    final old = _pagination;
    old.removeListener(_changed);
    _pagination = _createController()..addListener(_changed);
    old.dispose();
    if (mounted) setState(() {});
    unawaited(_pagination.loadMore());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PaperSurface(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Text(
                        context.strings('cookbook.title'),
                        style: Theme.of(context).textTheme.headlineLarge,
                      );
                      final count = TapeLabel(
                        text: context.strings.format('cookbook.savedCount', {
                          'count': widget.savedRecipes.length,
                        }),
                        angle: .025,
                      );
                      final textScale =
                          MediaQuery.textScalerOf(context).scale(14) / 14;
                      if (textScale > 1.3 || constraints.maxWidth < 340) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: count,
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(child: title),
                          count,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 13),
                  TextField(
                    controller: _search,
                    onChanged: (_) => _restart(),
                    decoration: InputDecoration(
                      hintText: context.strings('search.hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                _restart();
                              },
                              tooltip: context.strings('common.clear'),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_pagination.isInitialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pagination.items.isEmpty) {
      return MorphEmptyState(
        title: context.strings('cookbook.emptyTitle'),
        message: context.strings('cookbook.emptyBody'),
        action: widget.onBrowse,
        actionLabel: context.strings('home.browseAll'),
      );
    }
    return RefreshIndicator(
      onRefresh: _pagination.refresh,
      child: ListView.builder(
        key: const PageStorageKey('cookbook-list'),
        padding: const EdgeInsets.fromLTRB(20, 7, 20, 28),
        itemCount: _pagination.items.length + (_pagination.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _pagination.items.length) {
            unawaited(_pagination.loadMore());
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: MorphSkeleton(height: 110),
            );
          }
          if (_pagination.shouldLoadMore(index)) {
            unawaited(_pagination.loadMore());
          }
          final saved = _pagination.items[index];
          final recipe = widget.recipesById[saved.recipeId];
          if (recipe == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _SavedRecipeCard(
              recipe: recipe,
              dish: widget.dishesById[recipe.dishId],
              savedAt: saved.savedAt,
              profile: widget.profile,
              onTap: () => widget.onOpenRecipe(recipe),
              onRemove: () => widget.onRemoveSaved(recipe),
            ),
          );
        },
      ),
    );
  }
}

class _SavedRecipeCard extends StatelessWidget {
  const _SavedRecipeCard({
    required this.recipe,
    required this.dish,
    required this.savedAt,
    required this.profile,
    required this.onTap,
    required this.onRemove,
  });

  final Recipe recipe;
  final Dish? dish;
  final DateTime savedAt;
  final UserProfile profile;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final language = profile.languageCode;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cardHeight = (132 + (textScale.clamp(1, 2) - 1) * 70).toDouble();
    return Transform.rotate(
      angle: recipe.id.hashCode.isEven ? -.004 : .004,
      child: Material(
        color: context.morph.paper,
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: cardHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 124,
                  child: StripedPlaceholder(
                    caption:
                        dish?.caption.resolve(language) ??
                        context.strings.option('diet', recipe.diet),
                    color: _parseColor(dish?.stripeColor, context.morph.coral),
                    height: cardHeight,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 13, 4, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          recipe.name.resolve(language),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${context.strings.option('diet', recipe.diet)} · ${context.strings.option('effort', recipe.effort)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          DateFormat.yMMMd(language).format(savedAt.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topCenter,
                  child: IconButton(
                    onPressed: onRemove,
                    tooltip: context.strings('common.remove'),
                    icon: const Icon(Icons.bookmark_rounded),
                  ),
                ),
              ],
            ),
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
