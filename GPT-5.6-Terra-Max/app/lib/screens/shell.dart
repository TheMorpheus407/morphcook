import 'dart:async';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../copy.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'auxiliary.dart';
import 'detail.dart';
import 'shopping.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final pages = [
      HomeScreen(onChangeTab: (index) => setState(() => _index = index)),
      const SearchScreen(),
      const CookbookScreen(),
      const MealPlanScreen(),
    ];
    final labels = ['home', 'discover', 'cookbook', 'plan'];
    return PaperScaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xffad9f8c), width: .8)),
          color: Color(0xfff6eddf),
        ),
        child: NavigationBar(
          height: 67,
          backgroundColor: Colors.transparent,
          indicatorColor: MorphColors.teal.withValues(alpha: .13),
          selectedIndex: _index,
          onDestinationSelected: (index) => setState(() => _index = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: Copybook.t(labels[0], state.lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.search),
              label: Copybook.t(labels[1], state.lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_stories_outlined),
              selectedIcon: const Icon(Icons.auto_stories),
              label: Copybook.t(labels[2], state.lang),
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_month_outlined),
              selectedIcon: const Icon(Icons.calendar_month),
              label: Copybook.t(labels[3], state.lang),
            ),
          ],
        ),
      ),
    );
  }
}

void openRecipe(BuildContext context, String recipeId) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipeId: recipeId)),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onChangeTab});
  final ValueChanged<int> onChangeTab;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final recipes = state.rankedVisibleRecipes();
    final featured = recipes.firstOrNull;
    final name = state.profile.name.trim();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Masthead(
            trailing: [
              IconButton(
                tooltip: Copybook.t('shoppingList', state.lang),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                ),
                icon: Badge(
                  isLabelVisible: state.shoppingRecipeIds.isNotEmpty,
                  label: Text('${state.shoppingRecipeIds.length}'),
                  child: const Icon(Icons.shopping_basket_outlined),
                ),
              ),
              IconButton(
                tooltip: Copybook.t('settings', state.lang),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 7, 20, 8),
            child: Text(
              name.isEmpty
                  ? (state.lang == 'de'
                        ? 'heute kochen wir für dich.'
                        : 'today, we cook for you.')
                  : (state.lang == 'de' ? 'hallo, $name.' : 'hello, $name.'),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
        ),
        if (featured != null) ...[
          SliverToBoxAdapter(
            child: SectionTitle(children: Copybook.t('today', state.lang)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _FeaturedRecipe(recipe: featured),
            ),
          ),
        ] else
          SliverToBoxAdapter(
            child: EmptyNote(
              message: state.lang == 'de'
                  ? 'Dein Profil ist gerade sehr streng. Passe es in den Einstellungen an.'
                  : 'Your profile is filtering very tightly. Adjust it in settings.',
            ),
          ),
        SliverToBoxAdapter(
          child: SectionTitle(
            children: Copybook.t('quick', state.lang),
            action: TextButton(
              onPressed: () => onChangeTab(1),
              child: Text(Copybook.t('discover', state.lang)),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 278,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              scrollDirection: Axis.horizontal,
              itemCount: recipes
                  .where((recipe) => recipe.timeMinutes <= 30)
                  .take(8)
                  .length,
              separatorBuilder: (_, _) => const SizedBox(width: 15),
              itemBuilder: (context, index) {
                final recipe = recipes
                    .where((recipe) => recipe.timeMinutes <= 30)
                    .take(8)
                    .elementAt(index);
                return RecipeCard(
                  recipe: recipe,
                  lang: state.lang,
                  width: 223,
                  rotation: index.isEven ? -.012 : .012,
                  saved: state.savedRecipeIds.contains(recipe.id),
                  onSave: () => state.toggleSaved(recipe.id),
                  onTap: () => openRecipe(context, recipe.id),
                );
              },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SectionTitle(children: Copybook.t('weekend', state.lang)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList.separated(
            itemCount: recipes
                .where((recipe) => recipe.axes['effort'] != 'easy')
                .take(4)
                .length,
            itemBuilder: (context, index) {
              final recipe = recipes
                  .where((recipe) => recipe.axes['effort'] != 'easy')
                  .take(4)
                  .elementAt(index);
              return _RecipeRow(
                recipe: recipe,
                onTap: () => openRecipe(context, recipe.id),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 9),
          ),
        ),
      ],
    );
  }
}

class _FeaturedRecipe extends StatelessWidget {
  const _FeaturedRecipe({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final dish = state.dishById(recipe.dishId);
    return Material(
      color: const Color(0xfffffaf1),
      elevation: 1.5,
      child: InkWell(
        onTap: () => openRecipe(context, recipe.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StripePlaceholder(
                color: stripeColor(recipe.stripeColor),
                caption:
                    dish?.captionFor(state.lang) ??
                    recipe.captionFor(state.lang),
                height: 205,
              ),
              const SizedBox(height: 14),
              Text(
                recipe.titleFor(state.lang),
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 6),
              Text(
                recipe.subtitleFor(state.lang),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  TinyTag(
                    label: '${recipe.timeMinutes} min',
                    color: MorphColors.teal,
                  ),
                  const SizedBox(width: 6),
                  TinyTag(
                    label: '${recipe.caloriesPerServing} kcal',
                    color: MorphColors.coral,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward,
                    color: MorphColors.ink.withValues(alpha: .7),
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

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _tags = <String>{};
  List<Recipe> _results = [];
  var _visibleCount = 20;
  var _hasInitial = false;
  var _loading = false;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasInitial) return;
    _results = MorphCookScope.of(context).rankedVisibleRecipes();
    _hasInitial = true;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading) return;
    if (_scrollController.position.extentAfter < 400 &&
        _visibleCount < _results.length) {
      setState(() => _visibleCount = (_visibleCount + 20).clamp(0, 50));
    }
  }

  void _runSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      setState(() => _loading = true);
      final state = MorphCookScope.of(context);
      final query = _controller.text;
      final results = query.trim().isEmpty && _tags.isEmpty
          ? state.rankedVisibleRecipes()
          : await state.search(query, tags: _tags);
      if (!mounted) return;
      setState(() {
        _results = results;
        _visibleCount = 20;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final visible = _results.take(_visibleCount.clamp(0, 50)).toList();
    final tags = [
      'breakfast',
      'lunch',
      'dinner',
      'italian',
      'asian',
      'middle-eastern',
    ];
    return Column(
      children: [
        Masthead(
          compact: true,
          trailing: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              ),
              icon: const Icon(Icons.shopping_basket_outlined),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: TextField(
            controller: _controller,
            onChanged: (_) => _runSearch(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              hintText: Copybook.t('searchHint', state.lang),
            ),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: tags.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, index) {
              final tag = tags[index];
              return FilterChip(
                label: Text(tag),
                selected: _tags.contains(tag),
                selectedColor: MorphColors.mustard.withValues(alpha: .22),
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _tags.add(tag);
                    } else {
                      _tags.remove(tag);
                    }
                  });
                  _runSearch();
                },
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: visible.isEmpty && !_loading
              ? EmptyNote(
                  message: Copybook.t('noResults', state.lang),
                  icon: Icons.search_off,
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
                  itemCount:
                      visible.length +
                      (_visibleCount < _results.length ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) {
                    if (index == visible.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _RecipeRow(
                      recipe: visible[index],
                      onTap: () => openRecipe(context, visible[index].id),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class CookbookScreen extends StatelessWidget {
  const CookbookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final recipes = state.savedRecipes.take(50).toList();
    return Column(
      children: [
        Masthead(
          compact: true,
          trailing: [
            IconButton(
              tooltip: Copybook.t('shoppingList', state.lang),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              ),
              icon: const Icon(Icons.shopping_basket_outlined),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              Copybook.t('yourCookbook', state.lang),
              style: Theme.of(context).textTheme.displayMedium,
            ),
          ),
        ),
        Expanded(
          child: recipes.isEmpty
              ? EmptyNote(message: Copybook.t('emptyCookbook', state.lang))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  itemCount: recipes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => _RecipeRow(
                    recipe: recipes[index],
                    onTap: () => openRecipe(context, recipes[index].id),
                    trailing: IconButton(
                      tooltip: Copybook.t('addToList', state.lang),
                      onPressed: () =>
                          state.addRecipesToShopping([recipes[index].id]),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.recipe, required this.onTap, this.trailing});
  final Recipe recipe;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return Material(
      color: Colors.white.withValues(alpha: .47),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Row(
            children: [
              SizedBox(
                width: 82,
                height: 75,
                child: StripePlaceholder(
                  color: stripeColor(recipe.stripeColor),
                  caption: '',
                  height: 75,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.titleFor(state.lang),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${recipe.timeMinutes} min · ${recipe.caloriesPerServing} kcal',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    if (state.profile.showVariantTags) ...[
                      const SizedBox(height: 6),
                      TinyTag(
                        label: recipe.axes['diet'] ?? 'classic',
                        color: MorphColors.coral,
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.arrow_forward_ios, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
  }

  List<DateTime> get _days =>
      List.generate(7, (index) => _weekStart.add(Duration(days: index)));

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final meals = ['breakfast', 'lunch', 'dinner'];
    final weekRecipeIds = meals
        .expand((meal) => _days.map((day) => state.mealAt(day, meal)))
        .whereType<String>()
        .toSet();
    return Column(
      children: [
        Masthead(
          compact: true,
          trailing: [
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              ),
              icon: const Icon(Icons.shopping_basket_outlined),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 5),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () =>
                      _weekStart = _weekStart.subtract(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '${_weekStart.day}.${_weekStart.month}. — ${_weekStart.add(const Duration(days: 6)).day}.${_weekStart.add(const Duration(days: 6)).month}.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => _weekStart = _weekStart.add(const Duration(days: 7)),
                ),
                icon: const Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            Copybook.t('dragHint', state.lang),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 7 * 145.0,
              child: Column(
                children: [
                  Row(
                    children: _days.map((day) => _DayHeader(day: day)).toList(),
                  ),
                  const SizedBox(height: 7),
                  ...meals.map(
                    (meal) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: _days
                            .map(
                              (day) => _PlanCell(
                                day: day,
                                meal: meal,
                                recipeId: state.mealAt(day, meal),
                                onChoose: () => _pickRecipe(context, day, meal),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 3, 20, 17),
          child: InkButton(
            expanded: true,
            label: Copybook.t('plannedToList', state.lang),
            icon: Icons.shopping_basket_outlined,
            onPressed: weekRecipeIds.isEmpty
                ? null
                : () async {
                    await state.addRecipesToShopping(weekRecipeIds);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(Copybook.t('savedRecipe', state.lang)),
                        ),
                      );
                    }
                  },
          ),
        ),
      ],
    );
  }

  Future<void> _pickRecipe(
    BuildContext context,
    DateTime day,
    String meal,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MorphColors.paper,
      builder: (_) => _RecipePickerSheet(meal: meal),
    );
    if (selected != null && context.mounted) {
      await MorphCookScope.of(context).assignMeal(day, meal, selected);
    }
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final labels = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return SizedBox(
      width: 145,
      child: Center(
        child: Column(
          children: [
            Text(
              labels[day.weekday - 1].toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            Text(
              '${day.day}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanDrag {
  const _PlanDrag({
    required this.fromDay,
    required this.fromMeal,
    required this.recipeId,
  });
  final DateTime fromDay;
  final String fromMeal;
  final String recipeId;
}

class _PlanCell extends StatelessWidget {
  const _PlanCell({
    required this.day,
    required this.meal,
    required this.recipeId,
    required this.onChoose,
  });
  final DateTime day;
  final String meal;
  final String? recipeId;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final recipe = recipeId == null ? null : state.recipeById(recipeId!);
    return DragTarget<_PlanDrag>(
      onWillAcceptWithDetails: (details) => details.data.recipeId != recipeId,
      onAcceptWithDetails: (details) async {
        final source = details.data;
        await state.assignMeal(day, meal, source.recipeId);
        if (dayKey(source.fromDay) != dayKey(day) || source.fromMeal != meal) {
          await state.assignMeal(source.fromDay, source.fromMeal, null);
        }
      },
      builder: (context, candidates, _) => SizedBox(
        width: 145,
        height: 102,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: candidates.isNotEmpty
                ? MorphColors.teal.withValues(alpha: .12)
                : Colors.white.withValues(alpha: .34),
            child: InkWell(
              onTap: onChoose,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: candidates.isNotEmpty
                        ? MorphColors.teal
                        : const Color(0xffb6aa9a),
                  ),
                ),
                padding: const EdgeInsets.all(7),
                child: recipe == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Copybook.t(meal, state.lang).toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const Spacer(),
                          const Center(
                            child: Icon(
                              Icons.add,
                              size: 19,
                              color: MorphColors.mutedInk,
                            ),
                          ),
                        ],
                      )
                    : LongPressDraggable<_PlanDrag>(
                        data: _PlanDrag(
                          fromDay: day,
                          fromMeal: meal,
                          recipeId: recipe.id,
                        ),
                        feedback: Material(
                          color: MorphColors.paper,
                          child: SizedBox(
                            width: 132,
                            child: _PlanCard(recipe: recipe),
                          ),
                        ),
                        childWhenDragging: const Center(
                          child: Icon(Icons.open_with, color: MorphColors.teal),
                        ),
                        child: _PlanCard(recipe: recipe),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.recipe});
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.titleFor(state.lang),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
        ),
        const Spacer(),
        Text(
          '${recipe.timeMinutes} min',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _RecipePickerSheet extends StatefulWidget {
  const _RecipePickerSheet({required this.meal});
  final String meal;

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = MorphCookScope.of(context);
    final query = _search.text.toLowerCase();
    final available =
        [
              ...state.savedRecipes,
              ...state.rankedVisibleRecipes().where(
                (recipe) => !state.savedRecipeIds.contains(recipe.id),
              ),
            ]
            .where(
              (recipe) =>
                  query.isEmpty ||
                  recipe.titleFor(state.lang).toLowerCase().contains(query),
            )
            .take(50)
            .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${Copybook.t('chooseRecipe', state.lang)} · ${Copybook.t(widget.meal, state.lang)}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Expanded(
              child: ListView.builder(
                itemCount: available.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(available[index].titleFor(state.lang)),
                  subtitle: Text(
                    '${available[index].timeMinutes} min · ${available[index].caloriesPerServing} kcal',
                  ),
                  trailing: const Icon(Icons.add),
                  onTap: () => Navigator.pop(context, available[index].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
