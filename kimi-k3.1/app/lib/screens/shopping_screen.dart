import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../services/shopping_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';
import 'shopping_insights_screen.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key, this.onOpenRecipe});

  final void Function(String recipeId)? onOpenRecipe;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  Future<List<Recipe>>? _recipesFuture;
  List<String> _requestedIds = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = context.watch<AppState>().snapshot.shoppingRecipeIds;
    if (_recipesFuture == null || !listEquals(_requestedIds, ids)) {
      _loadSelectedRecipes(ids);
    }
  }

  void _loadSelectedRecipes(List<String> ids) {
    _requestedIds = List<String>.unmodifiable(ids);
    _recipesFuture = _ensureRecipes(context.read<AppState>(), _requestedIds);
  }

  Future<void> _openInsights() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ShoppingInsightsScreen()),
    );
  }

  Future<void> _openAddRecipes() {
    final appState = context.read<AppState>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          child: const FractionallySizedBox(
            heightFactor: 0.9,
            child: _AddRecipesSheet(),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final appState = context.read<AppState>();
    final count = appState.snapshot.shoppingRecipeIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paperLight,
        title: Text(
          dialogContext.l10n.t('clear_list'),
          style: Theme.of(dialogContext).textTheme.headlineSmall?.handwritten,
        ),
        content: Text(
          dialogContext.l10n.t('selected_recipes', {'count': '$count'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.t('clear_list')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      context.read<AppState>().clearShopping();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final hasList =
        appState.snapshot.shoppingRecipeIds.isNotEmpty ||
        appState.snapshot.checkedShoppingItems.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.t('nav_shopping'),
          style: Theme.of(context).textTheme.headlineSmall?.handwritten,
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.t('shopping_insights'),
            onPressed: _openInsights,
            icon: const Icon(Icons.insights_outlined),
          ),
          if (hasList)
            IconButton(
              tooltip: context.l10n.t('clear_list'),
              onPressed: _confirmClear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
          IconButton(
            tooltip: context.l10n.t('add_recipes'),
            onPressed: _openAddRecipes,
            icon: const Icon(Icons.playlist_add),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Paper(
        child: SafeArea(
          top: false,
          child: FutureBuilder<List<Recipe>>(
            future: _recipesFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ErrorState(
                  title: context.l10n.t('load_error'),
                  onRetry: () => setState(
                    () => _loadSelectedRecipes(
                      context.read<AppState>().snapshot.shoppingRecipeIds,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    SectionHeading(context.l10n.t('shopping_title')),
                    const SizedBox(height: 16),
                    const LoadingList(count: 3),
                  ],
                );
              }
              final recipes = snapshot.data ?? const <Recipe>[];
              if (recipes.isEmpty && _requestedIds.isEmpty) {
                return EmptyState(
                  title: context.l10n.t('shopping_empty'),
                  body: context.l10n.t('shopping_empty_body'),
                  action: PrimaryButton(
                    label: context.l10n.t('add_recipes'),
                    icon: Icons.playlist_add,
                    onPressed: _openAddRecipes,
                  ),
                );
              }
              if (recipes.isEmpty &&
                  snapshot.hasError == false &&
                  _requestedIds.isNotEmpty) {
                return _ErrorState(
                  title: context.l10n.t('list_error'),
                  onRetry: () =>
                      setState(() => _loadSelectedRecipes(_requestedIds)),
                );
              }
              return _buildList(context, recipes);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Recipe> recipes) {
    final appState = context.read<AppState>();
    final groups = const ShoppingService().aggregate(recipes);
    final byAisle = <String, List<ShoppingGroup>>{};
    for (final group in groups) {
      byAisle.putIfAbsent(group.aisle, () => []).add(group);
    }
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          sliver: SliverToBoxAdapter(
            child: SectionHeading(
              context.l10n.t('shopping_title'),
              kicker: context.l10n.t('selected_recipes', {
                'count': '${recipes.length}',
              }),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final recipe = recipes[index];
              return _SelectedRecipeCard(
                recipe: recipe,
                onOpen: widget.onOpenRecipe == null
                    ? null
                    : () => widget.onOpenRecipe!(recipe.id),
                onRemove: () => context
                    .read<AppState>()
                    .removeRecipeFromShopping(recipe.id),
              );
            }, childCount: recipes.length),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 8),
            child: DashedRule(),
          ),
        ),
        if (groups.isEmpty)
          SliverToBoxAdapter(
            child: EmptyState(
              title: context.l10n.t('shopping_empty'),
              body: context.l10n.t('shopping_empty_body'),
            ),
          ),
        for (final entry in byAisle.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 2),
              child: SectionHeading(context.l10n.aisle(entry.key)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final group = entry.value[index];
                final checked = context
                    .watch<AppState>()
                    .snapshot
                    .checkedShoppingItems
                    .contains(group.key);
                return _ShoppingItem(
                  group: group,
                  recipes: recipes,
                  checked: checked,
                  onToggle: () => appState.toggleShoppingChecked(group.key),
                );
              }, childCount: entry.value.length),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
            child: PrimaryButton(
              label: context.l10n.t('add_recipes'),
              icon: Icons.playlist_add,
              onPressed: _openAddRecipes,
            ),
          ),
        ),
      ],
    );
  }
}

Future<List<Recipe>> _ensureRecipes(
  AppState appState,
  Iterable<String> recipeIds,
) async {
  final ids = recipeIds.toSet().toList(growable: false);
  await Future.wait(ids.map(appState.repository.ensureRecipe));
  return ids
      .map((id) => appState.repository.recipes[id])
      .whereType<Recipe>()
      .toList(growable: false);
}

class _SelectedRecipeCard extends StatelessWidget {
  const _SelectedRecipeCard({
    required this.recipe,
    required this.onRemove,
    this.onOpen,
  });

  final Recipe recipe;
  final VoidCallback? onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 9),
      color: AppColors.paperLight.withValues(alpha: 0.78),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.muted.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ListTile(
        onTap: onOpen,
        title: Text(
          recipe.title.of(locale),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          '${context.l10n.t('minutes', {'count': '${recipe.timeMinutes}'})} · '
          '${context.l10n.t('servings', {'count': '${recipe.servings}'})}',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        trailing: IconButton(
          tooltip: context.l10n.t('remove'),
          onPressed: onRemove,
          icon: const Icon(Icons.close, size: 20),
        ),
      ),
    );
  }
}

class _ShoppingItem extends StatelessWidget {
  const _ShoppingItem({
    required this.group,
    required this.recipes,
    required this.checked,
    required this.onToggle,
  });

  final ShoppingGroup group;
  final List<Recipe> recipes;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final decoration = checked
        ? TextDecoration.lineThrough
        : TextDecoration.none;
    final color = checked ? AppColors.muted : AppColors.ink;
    final preparations = group.preparations
        .map((item) => item.of(locale))
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final sourceRecipes = [
      for (final recipe in recipes)
        if (group.recipeIds.contains(recipe.id)) recipe.title.of(locale),
    ];
    final unit = context.l10n.unit(group.unit);
    final amount = group.amount == null
        ? unit
        : '${ShoppingService.formatNumber(group.amount!)} $unit';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: checked,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.teal,
                side: BorderSide(color: AppColors.muted.withValues(alpha: 0.7)),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      group.name.of(locale),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        decoration: decoration,
                      ),
                    ),
                    if (preparations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          preparations.join(' · '),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(decoration: decoration),
                        ),
                      ),
                    if (sourceRecipes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          sourceRecipes.join(' · '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: color, decoration: decoration),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: SizedBox(
                  width: 94,
                  child: Text(
                    amount,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      decoration: decoration,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddRecipesSheet extends StatefulWidget {
  const _AddRecipesSheet();

  @override
  State<_AddRecipesSheet> createState() => _AddRecipesSheetState();
}

class _AddRecipesSheetState extends State<_AddRecipesSheet> {
  late final AppState _appState;
  late Future<List<Recipe>> _savedFuture;
  final TextEditingController _searchText = TextEditingController();
  final Set<String> _addingIds = {};
  Timer? _debounce;
  List<Recipe> _searchRecipes = [];
  String _query = '';
  String? _nextCursor;
  Object? _searchError;
  bool _searchLoading = false;
  bool _searchLoadingMore = false;
  bool _nextPageScheduled = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _appState = context.read<AppState>();
    _savedFuture = _ensureRecipes(
      _appState,
      _appState.snapshot.saved.map((item) => item.recipeId),
    );
    _loadSearch(notify: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchText.dispose();
    super.dispose();
  }

  Future<void> _addRecipe(Recipe recipe) async {
    if (_addingIds.contains(recipe.id) ||
        _appState.snapshot.shoppingRecipeIds.contains(recipe.id)) {
      return;
    }
    setState(() => _addingIds.add(recipe.id));
    try {
      await _appState.addRecipeIdsToShopping([recipe.id]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.t('list_error'))));
      }
    } finally {
      if (mounted) setState(() => _addingIds.remove(recipe.id));
    }
  }

  void _queryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadSearch();
    });
  }

  Future<void> _loadSearch({bool more = false, bool notify = true}) async {
    if (more && (_searchLoading || _nextCursor == null)) return;
    final generation = more ? _searchGeneration : ++_searchGeneration;
    final query = more ? _query : _searchText.text.trim();
    final cursor = more ? _nextCursor : null;
    if (!more) _query = query;
    void updateLoading() {
      _searchError = null;
      _searchLoading = true;
      _searchLoadingMore = more;
      if (!more) {
        _searchRecipes = [];
        _nextCursor = null;
      }
    }

    if (notify) {
      setState(updateLoading);
    } else {
      updateLoading();
    }
    try {
      final page = await _appState.repository.search(
        query,
        const <String>{},
        _appState.profile,
        after: cursor,
        now: _appState.clock(),
        lastCooked: _appState.lastCooked,
        limit: 20,
      );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        if (more) {
          _searchRecipes.addAll(page.recipes);
        } else {
          _searchRecipes = List<Recipe>.of(page.recipes);
        }
        if (_searchRecipes.length > 50) {
          _searchRecipes.removeRange(0, _searchRecipes.length - 50);
        }
        _nextCursor = page.nextCursor;
        _searchLoading = false;
        _searchLoadingMore = false;
      });
      if (!more && query.isNotEmpty && page.recipes.isEmpty) {
        _appState.recordContentRequest(query);
      }
    } catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchError = error;
        _searchLoading = false;
        _searchLoadingMore = false;
      });
    }
  }

  void _maybeLoadNextPage(int index) {
    if (index < _searchRecipes.length - 10 ||
        _searchLoading ||
        _nextCursor == null ||
        _nextPageScheduled) {
      return;
    }
    final generation = _searchGeneration;
    _nextPageScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nextPageScheduled = false;
      if (mounted && generation == _searchGeneration) {
        _loadSearch(more: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIds = context
        .watch<AppState>()
        .snapshot
        .shoppingRecipeIds
        .toSet();
    return DefaultTabController(
      length: 2,
      child: Material(
        color: AppColors.paper,
        child: Paper(
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.t('add_recipes'),
                          style: Theme.of(
                            context,
                          ).textTheme.headlineMedium?.handwritten,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.t('close'),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: context.l10n.t('from_cookbook')),
                    Tab(text: context.l10n.t('from_search')),
                  ],
                ),
                const DashedRule(height: 2),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildSavedTab(context, selectedIds),
                      _buildSearchTab(context, selectedIds),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSavedTab(BuildContext context, Set<String> selectedIds) {
    return FutureBuilder<List<Recipe>>(
      future: _savedFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            title: context.l10n.t('list_error'),
            onRetry: () => setState(() {
              _savedFuture = _ensureRecipes(
                _appState,
                _appState.snapshot.saved.map((item) => item.recipeId),
              );
            }),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [LoadingList(count: 2)],
          );
        }
        final recipes = snapshot.data ?? const <Recipe>[];
        if (recipes.isEmpty) {
          return EmptyState(
            title: context.l10n.t('cookbook_empty'),
            body: context.l10n.t('cookbook_empty_body'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final recipe = recipes[index];
            return _RecipePickCard(
              recipe: recipe,
              selected: selectedIds.contains(recipe.id),
              adding: _addingIds.contains(recipe.id),
              onAdd: () => _addRecipe(recipe),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchTab(BuildContext context, Set<String> selectedIds) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchText,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.l10n.t('search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchText.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.t('clear'),
                      onPressed: () {
                        _debounce?.cancel();
                        _searchText.clear();
                        _loadSearch();
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
            onChanged: _queryChanged,
            onSubmitted: (_) {
              _debounce?.cancel();
              _loadSearch();
            },
          ),
        ),
        Expanded(child: _buildSearchResults(context, selectedIds)),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, Set<String> selectedIds) {
    if (_searchLoading && _searchRecipes.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
    }
    if (_searchError != null && _searchRecipes.isEmpty) {
      return _ErrorState(
        title: context.l10n.t('list_error'),
        onRetry: _loadSearch,
      );
    }
    if (_searchRecipes.isEmpty) {
      return EmptyState(
        title: context.l10n.t('search_empty'),
        body: context.l10n.t('search_empty_body'),
      );
    }
    final hasFooter = _searchLoadingMore || _searchError != null;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
      itemCount: _searchRecipes.length + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _searchRecipes.length) {
          if (_searchError != null) {
            return SizedBox(
              height: 210,
              child: _ErrorState(
                title: context.l10n.t('list_error'),
                onRetry: () => _loadSearch(more: true),
              ),
            );
          }
          return const SizedBox(
            height: 76,
            child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
          );
        }
        _maybeLoadNextPage(index);
        final recipe = _searchRecipes[index];
        return _RecipePickCard(
          recipe: recipe,
          selected: selectedIds.contains(recipe.id),
          adding: _addingIds.contains(recipe.id),
          onAdd: () => _addRecipe(recipe),
        );
      },
    );
  }
}

class _RecipePickCard extends StatelessWidget {
  const _RecipePickCard({
    required this.recipe,
    required this.selected,
    required this.adding,
    required this.onAdd,
  });

  final Recipe recipe;
  final bool selected;
  final bool adding;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final enabled = !selected && !adding;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 11),
      color: AppColors.paperLight.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: selected
              ? AppColors.teal.withValues(alpha: 0.65)
              : AppColors.muted.withValues(alpha: 0.22),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: InkWell(
        onTap: enabled ? onAdd : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title.of(locale),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${context.l10n.t('minutes', {'count': '${recipe.timeMinutes}'})} · '
                      '${context.l10n.t('kcal', {'count': '${recipe.caloriesPerServing}'})}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.teal)
              else if (adding)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                IconButton(
                  tooltip: context.l10n.t('add_recipes'),
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.onRetry});

  final String title;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.coral, size: 36),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: context.l10n.t('retry'),
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
