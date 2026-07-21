import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'backup_service.dart';
import 'data.dart';
import 'package:file_picker/file_picker.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

String _timeGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'morning';
  if (hour < 18) return 'afternoon';
  return 'evening';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final lang = store.lang;
    final featureDish = dishFor('doener');
    final featureRecipe = store.recipeForDish(featureDish);
    final visible = store.visibleRecipes;
    final picks = visible
        .where((recipe) => recipe.id != featureRecipe.id)
        .take(4)
        .toList();
    return ScreenFrame(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: PageTopBar(
              trailing: Avatar(
                name: store.profile.name,
                onTap: () => store.goToRoute(AppRoute.settings),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 24),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'good ${_timeGreeting()},\n${store.profile.name.toLowerCase()}.',
                    style: displayStyle(size: 39),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'a little room for dinner\nto become itself.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      HandNote('make room', color: coral, size: 22),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _FeaturedDish(
                    dish: featureDish,
                    recipe: featureRecipe,
                    lang: lang,
                    onTap: () => store.openDish(featureDish.id),
                    onCook: () => store.startCooking(featureRecipe.id),
                  ),
                  const SizedBox(height: 29),
                  SectionHeader(
                    eyebrow: 'the daily page',
                    title: 'made for your mood',
                    action: 'see all',
                    onAction: () => store.goToTab(AppTab.search),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: <Widget>[
                        _MoodCard(
                          label: 'quick & quiet',
                          detail: 'under 30 min',
                          color: sea,
                          icon: '◌',
                          onTap: () {
                            store.setSearchTag('quick');
                            store.goToTab(AppTab.search);
                          },
                        ),
                        _MoodCard(
                          label: 'pantry rescue',
                          detail: 'soft landing',
                          color: mustard,
                          icon: '✳',
                          onTap: () {
                            store.setSearchTag('comfort');
                            store.goToTab(AppTab.search);
                          },
                        ),
                        _MoodCard(
                          label: 'weekend project',
                          detail: 'take your time',
                          color: blush,
                          icon: '⌁',
                          onTap: () {
                            store.setSearchTag('weekend');
                            store.goToTab(AppTab.search);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SectionHeader(
                    eyebrow: 'pulled from the stack',
                    title: 'for you, today',
                    action: 'open search',
                    onAction: () => store.goToTab(AppTab.search),
                  ),
                  const SizedBox(height: 13),
                ],
              ),
            ),
          ),
          if (picks.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final recipe = picks[index];
                  return RecipeCard(
                    recipe: recipe,
                    lang: lang,
                    onTap: () => store.openRecipe(recipe.id),
                    onSave: () => store.toggleSaved(recipe.id),
                  );
                }, childCount: picks.length),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 13,
                  mainAxisSpacing: 17,
                  childAspectRatio: 0.69,
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeader(
                    eyebrow: 'still warm in your memory',
                    title: 'cook it again?',
                    action: 'your book',
                    onAction: () => store.goToTab(AppTab.cookbook),
                  ),
                  const SizedBox(height: 13),
                  ...store.recentHistory.take(2).map((entry) {
                    final recipe = recipeFor(entry.recipeId);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: CompactRecipeTile(
                        recipe: recipe,
                        lang: lang,
                        onTap: () => store.openRecipe(recipe.id),
                      ),
                    );
                  }),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      color: coral.withValues(alpha: 0.23),
                      border: Border.all(color: coral.withValues(alpha: 0.42)),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Eyebrow('a note from the pantry', color: coral),
                              const SizedBox(height: 5),
                              Text(
                                'Every variant is a whole recipe.',
                                style: displayStyle(size: 21),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No swaps. No side-eye. Just dinner that fits.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '♡',
                          style: displayStyle(
                            size: 35,
                            color: coral,
                            style: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturedDish extends StatelessWidget {
  const _FeaturedDish({
    required this.dish,
    required this.recipe,
    required this.lang,
    required this.onTap,
    required this.onCook,
  });

  final Dish dish;
  final Recipe recipe;
  final String lang;
  final VoidCallback onTap;
  final VoidCallback onCook;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Color(dish.accent),
            border: Border.all(color: ink.withValues(alpha: 0.28)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: ink.withValues(alpha: 0.13),
                offset: const Offset(4, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: StripeArt(
            color: Color(dish.accent),
            caption: dish.title(lang),
            pattern: dish.pattern,
            height: 267,
            borderRadius: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 15, 17, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Eyebrow(
                          'dish of the day',
                          color: ink.withValues(alpha: 0.74),
                        ),
                      ),
                      TagPill(
                        recipe.diet,
                        color: paper.withValues(alpha: 0.75),
                        compact: true,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    dish.title(lang),
                    style: displayStyle(size: 36, color: ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dish.blurb(lang),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 13),
                  Row(
                    children: <Widget>[
                      Text(
                        '${recipe.timeMinutes} min · ${recipe.calories} kcal',
                        style: monoStyle(
                          size: 9,
                          color: ink,
                          letterSpacing: 0.45,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: onCook,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          color: ink,
                          child: Text(
                            'cook this →',
                            style: monoStyle(
                              size: 9,
                              color: whiteInk,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({
    required this.label,
    required this.detail,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String detail;
  final Color color;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: color.withValues(alpha: 0.5),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 158,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 9, 9),
              child: Row(
                children: <Widget>[
                  Text(
                    icon,
                    style: displayStyle(
                      size: 27,
                      color: ink,
                      style: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(label, style: displayStyle(size: 15)),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: monoStyle(
                            size: 8,
                            color: inkMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CookbookScreen extends StatelessWidget {
  const CookbookScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final saved = store.savedRecipes;
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'your cookbook',
            trailing: IconButton(
              onPressed: () => store.goToRoute(AppRoute.shopping),
              icon: const Icon(Icons.shopping_basket_outlined),
              color: seaDeep,
              tooltip: 'shopping list',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 3, 20, 17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${saved.length} recipes\nthat feel like you.',
                    style: displayStyle(size: 30),
                  ),
                ),
                HandNote('saved with care', color: coral, size: 19),
              ],
            ),
          ),
          const DashedRule(padding: 0),
          Expanded(
            child: saved.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: EmptyState(
                      title: 'the book is waiting',
                      message:
                          'Tap the bookmark on anything that makes you want to stand up and cook.',
                      action: 'find a recipe',
                      onAction: () => store.goToTab(AppTab.search),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 13, 14, 25),
                    itemCount: saved.take(50).length,
                    itemBuilder: (context, index) {
                      final recipe = saved[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: CompactRecipeTile(
                          recipe: recipe,
                          lang: store.lang,
                          onTap: () => store.openRecipe(recipe.id),
                          trailing: IconButton(
                            onPressed: () => store.toggleSaved(recipe.id),
                            icon: const Icon(Icons.bookmark_rounded, size: 19),
                            color: coral,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: store.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = store.searchResults;
    const tags = <String>[
      'all',
      'quick',
      'vegan',
      'comfort',
      'breakfast',
      'one-pan',
    ];
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(title: 'find something good'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 25),
              children: <Widget>[
                Text('a recipe for\nright now.', style: displayStyle(size: 35)),
                const SizedBox(height: 8),
                Text(
                  'Search the whole book. Your profile stays in the room.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 17),
                TextField(
                  controller: _controller,
                  onChanged: store.setSearch,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'try “noodles”, “quiet”, “lemon”…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 13),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: tags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(tag),
                          selected: store.searchTag == tag,
                          onSelected: (_) => store.setSearchTag(tag),
                          selectedColor: sea,
                          backgroundColor: const Color(0xFFECE6DA),
                          side: BorderSide(
                            color: store.searchTag == tag
                                ? seaDeep
                                : const Color(0xFFD7CABC),
                          ),
                          labelStyle: monoStyle(size: 10, color: ink),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: SectionHeader(
                        eyebrow: '${results.length} found',
                        title: store.searchQuery.trim().isEmpty
                            ? 'start here'
                            : 'your results',
                      ),
                    ),
                    if (store.showOutsideTarget)
                      const TagPill('target off', color: blush, compact: true),
                  ],
                ),
                const SizedBox(height: 13),
                if (results.isEmpty)
                  EmptyState(
                    title: 'a blank page',
                    message:
                        'Nothing here yet. Save the search so the next edition knows what to make room for.',
                    action: store.searchQuery.trim().isEmpty
                        ? null
                        : 'save this request',
                    onAction: () {
                      store.logContentRequest();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Saved locally for a future recipe edition.',
                          ),
                        ),
                      );
                    },
                  )
                else
                  ...results.take(50).map((recipe) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CompactRecipeTile(
                        recipe: recipe,
                        lang: store.lang,
                        onTap: () => store.openRecipe(recipe.id),
                        trailing: IconButton(
                          onPressed: () => store.toggleSaved(recipe.id),
                          icon: Icon(
                            store.isSaved(recipe.id)
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 19,
                          ),
                          color: store.isSaved(recipe.id) ? coral : inkMuted,
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key, required this.store});

  final AppStore store;

  static const List<String> _days = <String>[
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun',
  ];
  static const List<String> _meals = <String>['breakfast', 'lunch', 'dinner'];

  @override
  Widget build(BuildContext context) {
    final assigned = store.mealPlan.length;
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'the week ahead',
            trailing: IconButton(
              onPressed: () {
                store.addMealPlanToShopping();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('This week is on your shopping list.'),
                  ),
                );
              },
              icon: const Icon(Icons.playlist_add_rounded),
              color: seaDeep,
              tooltip: 'add week to shopping list',
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'leave a little\nroom for life.',
                        style: displayStyle(size: 34),
                      ),
                    ),
                    HandNote('$assigned planned', color: coral, size: 19),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'No auto-planning. Just a gentle place to put the things you already want.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const DashedRule(),
                ..._days.map((day) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: _DayPlan(
                      day: day,
                      meals: _meals,
                      store: store,
                      onPick: (key) => _pickSlot(context, key),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: mustard.withValues(alpha: 0.3),
                    border: Border.all(color: mustard.withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.drag_indicator_rounded, color: inkMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Press and hold a meal to move it between days.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickSlot(BuildContext context, String key) {
    final options = store.savedRecipes.isEmpty
        ? store.visibleRecipes
        : store.savedRecipes;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.68,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 9),
                Container(
                  width: 38,
                  height: 4,
                  color: ink.withValues(alpha: 0.2),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 13),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'choose something for ${key.split('.').last}',
                          style: displayStyle(size: 25),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final recipe = options[index];
                      return CompactRecipeTile(
                        recipe: recipe,
                        lang: store.lang,
                        onTap: () {
                          store.assignMeal(key, recipe.id);
                          Navigator.pop(sheetContext);
                        },
                        trailing: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: seaDeep,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayPlan extends StatelessWidget {
  const _DayPlan({
    required this.day,
    required this.meals,
    required this.store,
    required this.onPick,
  });

  final String day;
  final List<String> meals;
  final AppStore store;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5ED).withValues(alpha: 0.72),
        border: Border.all(color: const Color(0xFFD7CABC)),
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: sea.withValues(alpha: 0.3),
            child: Text(
              day,
              style: monoStyle(size: 11, color: seaDeep, letterSpacing: 1.3),
            ),
          ),
          ...meals.map((meal) {
            final key = '$day.$meal';
            final recipeId = store.mealPlan[key];
            final recipe = recipeId == null ? null : recipeFor(recipeId);
            return DragTarget<String>(
              onAcceptWithDetails: (details) {
                final moved = store.mealPlan[details.data];
                store.assignMeal(key, moved);
                store.assignMeal(details.data, null);
              },
              builder: (context, candidate, rejected) {
                final slot = InkWell(
                  onTap: () => onPick(key),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 67,
                          child: Text(
                            meal,
                            style: monoStyle(
                              size: 9,
                              color: inkMuted,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        Expanded(
                          child: recipe == null
                              ? Text(
                                  'add a recipe +',
                                  style: displayStyle(
                                    size: 16,
                                    color: inkMuted,
                                    style: FontStyle.italic,
                                    weight: FontWeight.w400,
                                  ),
                                )
                              : Row(
                                  children: <Widget>[
                                    Container(
                                      width: 5,
                                      height: 27,
                                      color: Color(recipe.accent),
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Text(
                                        recipe.name(store.lang),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: displayStyle(size: 17),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        Icon(
                          recipe == null
                              ? Icons.add_rounded
                              : Icons.more_horiz_rounded,
                          size: 18,
                          color: recipe == null ? seaDeep : inkMuted,
                        ),
                      ],
                    ),
                  ),
                );
                if (recipe == null) return slot;
                return Draggable<String>(
                  data: key,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: 270, child: slot),
                  ),
                  childWhenDragging: Opacity(opacity: 0.3, child: slot),
                  child: slot,
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = store.profile;
    return ScreenFrame(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          PageTopBar(title: 'your kitchen'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 3, 20, 22),
            child: Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: sea.withValues(alpha: 0.3),
                border: Border.all(color: seaDeep.withValues(alpha: 0.28)),
              ),
              child: Row(
                children: <Widget>[
                  Avatar(name: p.name),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(p.name, style: displayStyle(size: 25)),
                        const SizedBox(height: 4),
                        Text(
                          '${p.dietPreference} · ${p.maxTimeMinutes} min · ${p.calorieTarget} kcal / meal',
                          style: monoStyle(
                            size: 9,
                            color: seaDeep,
                            letterSpacing: 0.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => store.goToRoute(AppRoute.profileEditor),
                    icon: const Icon(Icons.edit_outlined, color: seaDeep),
                  ),
                ],
              ),
            ),
          ),
          _SettingsSection(
            title: 'your profile',
            children: <Widget>[
              _SettingTile(
                icon: Icons.person_outline_rounded,
                title: 'Name, diet & allergies',
                subtitle: 'Keep the book honest to you',
                onTap: () => store.goToRoute(AppRoute.profileEditor),
              ),
              _SettingTile(
                icon: Icons.translate_rounded,
                title: 'Language',
                subtitle: p.lang == 'en'
                    ? 'English · DE ready'
                    : 'Deutsch · EN bereit',
                onTap: () {
                  store.updateProfile(
                    p.copyWith(lang: p.lang == 'en' ? 'de' : 'en'),
                  );
                },
                trailing: Text(
                  p.lang.toUpperCase(),
                  style: monoStyle(size: 10, color: coral),
                ),
              ),
              _SettingTile(
                icon: Icons.tune_rounded,
                title: 'Adaptation preferences',
                subtitle: 'How the cookbook meets your day',
                onTap: () => store.goToRoute(AppRoute.profileEditor),
              ),
            ],
          ),
          _SettingsSection(
            title: 'your tools',
            children: <Widget>[
              _SettingTile(
                icon: Icons.shopping_basket_outlined,
                title: 'Smart shopping list',
                subtitle:
                    '${store.shoppingItems.length} ingredients · grouped by aisle',
                onTap: () => store.goToRoute(AppRoute.shopping),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: inkMuted,
                ),
              ),
              _SettingTile(
                icon: Icons.insights_outlined,
                title: 'Shopping insights',
                subtitle: 'See the shape of your pantry',
                onTap: () => store.goToRoute(AppRoute.insights),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: inkMuted,
                ),
              ),
              _SettingTile(
                icon: Icons.help_outline_rounded,
                title: 'Help center',
                subtitle: 'Answers without the runaround',
                onTap: () => store.goToRoute(AppRoute.help),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: inkMuted,
                ),
              ),
              _SettingTile(
                icon: Icons.ios_share_rounded,
                title: 'Backup & restore',
                subtitle: 'A copy that belongs to you',
                onTap: () => store.goToRoute(AppRoute.backup),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: inkMuted,
                ),
              ),
            ],
          ),
          _SettingsSection(
            title: 'cook mode',
            children: <Widget>[
              ToggleRow(
                title: 'Visual timer alert',
                subtitle: 'A coral / teal flash when a timer ends',
                value: p.visualAlertEnabled,
                onChanged: (value) =>
                    store.updateProfile(p.copyWith(visualAlertEnabled: value)),
              ),
              ToggleRow(
                title: 'Quick next tap',
                subtitle: 'Tap the step card to move on one-handed',
                value: p.quickNextTapEnabled,
                onChanged: (value) =>
                    store.updateProfile(p.copyWith(quickNextTapEnabled: value)),
              ),
              ToggleRow(
                title: 'Reduce motion',
                subtitle: 'Short, quiet transitions throughout the app',
                value: p.reduceMotion,
                onChanged: (value) =>
                    store.updateProfile(p.copyWith(reduceMotion: value)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
            child: Column(
              children: <Widget>[
                const DashedRule(padding: 2),
                Text(
                  'MorphCook is offline-only. No account, no telemetry, no disappearing recipes.',
                  textAlign: TextAlign.center,
                  style: monoStyle(
                    size: 9,
                    color: inkMuted,
                    letterSpacing: 0.35,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => store.startOnboarding(fromSettings: true),
                  child: Text(
                    'replay setup',
                    style: monoStyle(size: 9, color: coral),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Eyebrow(title),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F5ED).withValues(alpha: 0.76),
              border: Border.all(color: const Color(0xFFD7CABC)),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 21, color: seaDeep),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: displayStyle(size: 17)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: inkMuted,
                ),
          ],
        ),
      ),
    );
  }
}

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _nameController;
  late String _diet;
  late Set<String> _avoidFlags;
  late Set<String> _avoidIngredients;
  late int _maxTime;
  late int _calories;
  late String _effort;
  late String _language;
  final TextEditingController _specificController = TextEditingController();

  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final p = store.profile;
    _nameController = TextEditingController(text: p.name);
    _diet = p.dietPreference;
    _avoidFlags = Set<String>.from(p.avoidFlags);
    _avoidIngredients = Set<String>.from(p.avoidIngredients);
    _maxTime = p.maxTimeMinutes;
    _calories = p.calorieTarget;
    _effort = p.preferredEffort;
    _language = p.lang;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specificController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'edit your profile',
            showBack: true,
            onBack: store.back,
            trailing: TextButton(
              onPressed: _save,
              child: Text('save', style: monoStyle(size: 10, color: coral)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 3, 20, 35),
              children: <Widget>[
                Text(
                  'make it yours.\nkeep it easy.',
                  style: displayStyle(size: 35),
                ),
                const SizedBox(height: 8),
                Text(
                  'These settings shape what shows up — nothing is ever removed from the world.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 25),
                _ProfileSection(
                  title: 'your name',
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'what should we call you?',
                    ),
                  ),
                ),
                _ProfileSection(
                  title: 'language',
                  child: Wrap(
                    spacing: 7,
                    children: <Widget>[
                      _Choice(
                        label: 'english',
                        value: 'en',
                        groupValue: _language,
                        onTap: () => setState(() => _language = 'en'),
                      ),
                      _Choice(
                        label: 'deutsch',
                        value: 'de',
                        groupValue: _language,
                        onTap: () => setState(() => _language = 'de'),
                      ),
                    ],
                  ),
                ),
                _ProfileSection(
                  title: 'how you eat',
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children:
                        <String>[
                          'flexible',
                          'vegan',
                          'vegetarian',
                          'pescatarian',
                          'halal',
                          'kosher',
                        ].map((diet) {
                          return _Choice(
                            label: diet,
                            value: diet,
                            groupValue: _diet,
                            onTap: () {
                              setState(() {
                                _diet = diet;
                                _avoidFlags.removeWhere(
                                  compoundAvoidFlags.containsKey,
                                );
                                if (diet != 'flexible') _avoidFlags.add(diet);
                              });
                            },
                          );
                        }).toList(),
                  ),
                ),
                _ProfileSection(
                  title: 'also avoid',
                  subtitle: 'Class-level flags combine with your diet.',
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children:
                        <String>[
                          'dairy',
                          'nuts',
                          'peanuts',
                          'shellfish',
                          'gluten',
                          'added-sugar',
                        ].map((flag) {
                          return _ToggleChoice(
                            label: flag,
                            selected: _avoidFlags.contains(flag),
                            onTap: () {
                              setState(() {
                                if (!_avoidFlags.add(flag)) {
                                  _avoidFlags.remove(flag);
                                }
                              });
                            },
                          );
                        }).toList(),
                  ),
                ),
                _ProfileSection(
                  title: 'specific ingredients',
                  subtitle:
                      'Pick a parent or a leaf. Avoidance propagates down the tree.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _specificController,
                        onSubmitted: (value) {
                          final clean = value.trim().toLowerCase();
                          if (clean.isNotEmpty) {
                            setState(() {
                              _avoidIngredients.add(clean);
                              _specificController.clear();
                            });
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'e.g. cilantro, apples, bell peppers',
                          suffixIcon: Icon(Icons.add_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: _avoidIngredients.map((ingredient) {
                          return InputChip(
                            label: Text(ingredient),
                            onDeleted: () => setState(
                              () => _avoidIngredients.remove(ingredient),
                            ),
                            deleteIconColor: coral,
                            backgroundColor: blush.withValues(alpha: 0.65),
                            labelStyle: monoStyle(size: 9, color: ink),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                _ProfileSection(
                  title: 'time budget',
                  trailing: Text(
                    '$_maxTime min',
                    style: monoStyle(size: 10, color: coral),
                  ),
                  child: Slider(
                    value: _maxTime.toDouble(),
                    min: 15,
                    max: 90,
                    divisions: 5,
                    activeColor: seaDeep,
                    onChanged: (value) =>
                        setState(() => _maxTime = value.round()),
                  ),
                ),
                _ProfileSection(
                  title: 'calorie target / meal',
                  trailing: Text(
                    '~$_calories kcal',
                    style: monoStyle(size: 10, color: coral),
                  ),
                  child: Slider(
                    value: _calories.toDouble(),
                    min: 300,
                    max: 1000,
                    divisions: 14,
                    activeColor: coral,
                    onChanged: (value) =>
                        setState(() => _calories = value.round()),
                  ),
                ),
                _ProfileSection(
                  title: 'effort mood',
                  child: Wrap(
                    spacing: 7,
                    children: <String>['easy', 'medium', 'hard'].map((effort) {
                      return _Choice(
                        label: effort,
                        value: effort,
                        groupValue: _effort,
                        onTap: () => setState(() => _effort = effort),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: mustard.withValues(alpha: 0.28),
                    border: Border.all(color: mustard.withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 19,
                        color: seaDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Halal and kosher recipes say “compatible ingredients” only. Certification belongs to sourcing, labels, and supervision.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'save my kitchen',
                  icon: Icons.check_rounded,
                  onPressed: _save,
                  expand: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    store.updateProfile(
      store.profile.copyWith(
        name: _nameController.text.trim().isEmpty
            ? 'Friend'
            : _nameController.text.trim(),
        lang: _language,
        dietPreference: _diet,
        avoidFlags: _avoidFlags,
        avoidIngredients: _avoidIngredients,
        maxTimeMinutes: _maxTime,
        calorieTarget: _calories,
        preferredEffort: _effort,
      ),
    );
    store.back();
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 21),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Eyebrow(title)),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onTap,
  });

  final String label;
  final String value;
  final String groupValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? sea : const Color(0xFFECE6DA),
          border: Border.all(
            color: selected ? seaDeep : const Color(0xFFD7CABC),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected)
              const Padding(
                padding: EdgeInsets.only(right: 5),
                child: Icon(Icons.check_rounded, size: 14, color: seaDeep),
              ),
            Text(
              label,
              style: monoStyle(size: 10, color: ink, letterSpacing: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChoice extends StatelessWidget {
  const _ToggleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TagPill(
        label,
        color: selected ? coral : const Color(0xFFECE6DA),
        compact: true,
      ),
    );
  }
}

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _controller = TextEditingController();
  String category = 'all';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.toLowerCase().trim();
    const categories = <String>[
      'all',
      'visibility',
      'dietary matching',
      'shopping',
      'cook mode',
      'privacy',
    ];
    final entries = faqs.where((faq) {
      final categoryMatch = category == 'all' || faq['category'] == category;
      final textMatch =
          query.isEmpty ||
          '${faq['question']} ${faq['answer']}'.toLowerCase().contains(query);
      return categoryMatch && textMatch;
    }).toList();
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'help center',
            showBack: true,
            onBack: widget.store.back,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 30),
              children: <Widget>[
                Text(
                  'small answers\nfor real kitchens.',
                  style: displayStyle(size: 34),
                ),
                const SizedBox(height: 8),
                Text(
                  'No mystery language. No “contact support” maze.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 17),
                TextField(
                  controller: _controller,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'search the kitchen notes',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(item),
                          selected: category == item,
                          onSelected: (_) => setState(() => category = item),
                          selectedColor: sea,
                          backgroundColor: const Color(0xFFECE6DA),
                          side: const BorderSide(color: Color(0xFFD7CABC)),
                          labelStyle: monoStyle(size: 9, color: ink),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),
                ...entries.map((faq) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F5ED).withValues(alpha: 0.78),
                        border: Border.all(color: const Color(0xFFD7CABC)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          15,
                        ),
                        title: Text(
                          faq['question']!,
                          style: displayStyle(size: 18),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            faq['category']!,
                            style: monoStyle(
                              size: 8,
                              color: coral,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        iconColor: seaDeep,
                        collapsedIconColor: inkMuted,
                        children: <Widget>[
                          Text(
                            faq['answer']!,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (entries.isEmpty)
                  const EmptyState(
                    title: 'no note found',
                    message: 'Try “diet”, “shopping”, or “timer”.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final groups = store.groupedShoppingItems;
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'smart shopping',
            showBack: true,
            onBack: store.back,
            trailing: IconButton(
              onPressed: () => store.goToRoute(AppRoute.insights),
              icon: const Icon(Icons.insights_outlined, color: seaDeep),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: <Widget>[
                Text(
                  'less list.\nmore cooking.',
                  style: displayStyle(size: 34),
                ),
                const SizedBox(height: 8),
                Text(
                  '${store.shoppingRecipeIds.length} recipes · ${store.shoppingItems.length} ingredients · units combined where they can be.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 17),
                Row(
                  children: <Widget>[
                    StatBox(
                      value: '${store.shoppingItems.length}',
                      label: 'to buy',
                      color: sea,
                    ),
                    const SizedBox(width: 8),
                    StatBox(
                      value: '${store.checkedShoppingIds.length}',
                      label: 'in basket',
                      color: mustard,
                    ),
                    const SizedBox(width: 8),
                    StatBox(
                      value: '${groups.length}',
                      label: 'aisles',
                      color: blush,
                    ),
                  ],
                ),
                const DashedRule(),
                if (groups.isEmpty)
                  EmptyState(
                    title: 'the list is quiet',
                    message: 'Add a recipe or export your planned week here.',
                  ),
                ...groups.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 17),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Eyebrow(entry.key),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF9F5ED,
                            ).withValues(alpha: 0.8),
                            border: Border.all(color: const Color(0xFFD7CABC)),
                          ),
                          child: Column(
                            children: entry.value.map((item) {
                              final guide = ingredientGuide[item.id];
                              return InkWell(
                                onTap: () => store.toggleShoppingItem(item.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: <Widget>[
                                      Checkbox(
                                        value: item.checked,
                                        onChanged: (_) =>
                                            store.toggleShoppingItem(item.id),
                                        activeColor: seaDeep,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      Expanded(
                                        child: Text(
                                          '${_amountText(item.amount)} ${item.unit} ${item.name}',
                                          style: displayStyle(
                                            size: 17,
                                            color: item.checked
                                                ? inkMuted
                                                : ink,
                                            weight: item.checked
                                                ? FontWeight.w400
                                                : FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (item.recipeCount > 1)
                                        Text(
                                          '${item.recipeCount}×',
                                          style: monoStyle(
                                            size: 8,
                                            color: coral,
                                          ),
                                        ),
                                      if (guide != null)
                                        IconButton(
                                          onPressed: () => _showIngredientGuide(
                                            context,
                                            guide,
                                          ),
                                          icon: const Icon(
                                            Icons.menu_book_outlined,
                                            size: 18,
                                          ),
                                          color: seaDeep,
                                          tooltip: 'learn more',
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sea.withValues(alpha: 0.2),
                    border: Border.all(color: seaDeep.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.auto_awesome_outlined, color: seaDeep),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Smart note: garlic 2 cloves + garlic 3 cloves = 5 cloves. Pantry math, not magic.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _amountText(double amount) {
    if (amount == amount.roundToDouble()) return amount.round().toString();
    return amount.toStringAsFixed(1);
  }

  void _showIngredientGuide(BuildContext context, Map<String, String> guide) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Eyebrow('kitchen reference'),
                const SizedBox(height: 5),
                Text(guide['title']!, style: displayStyle(size: 29)),
                const SizedBox(height: 10),
                Text(
                  guide['description']!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                Text('little tip', style: monoStyle(size: 9, color: coral)),
                const SizedBox(height: 3),
                Text(
                  guide['tip']!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final items = store.shoppingItems;
    final topIngredients = store.ingredientAddCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'shopping insights',
            showBack: true,
            onBack: store.back,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: <Widget>[
                Text(
                  'notice your\nown patterns.',
                  style: displayStyle(size: 35),
                ),
                const SizedBox(height: 8),
                Text(
                  'A soft little dashboard for the things that make it into your kitchen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    StatBox(
                      value: '${items.length}',
                      label: 'variety score',
                      color: sea,
                    ),
                    const SizedBox(width: 8),
                    StatBox(
                      value: '${store.shoppingRecipeIds.length}',
                      label: 'recipes added',
                      color: blush,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InsightCard(
                  eyebrow: 'variety score',
                  title: items.isEmpty
                      ? 'a fresh page'
                      : 'you have ${items.length} ingredients in rotation.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: math.min(items.length / 24, 1),
                          minHeight: 9,
                          backgroundColor: paperDeep,
                          color: seaDeep,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Variety means options, not pressure. The pantry is allowed to repeat itself.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                _InsightCard(
                  eyebrow: 'most added',
                  title: 'the ingredients you keep coming back to.',
                  child: Column(
                    children: topIngredients
                        .take(5)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final max = topIngredients.first.value;
                          return Padding(
                            padding: const EdgeInsets.only(top: 13),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '0${index + 1}',
                                    style: monoStyle(size: 9, color: coral),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    _prettyIngredient(item.key),
                                    style: displayStyle(size: 18),
                                  ),
                                ),
                                SizedBox(
                                  width: 78,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Text(
                                        '${item.value} adds',
                                        style: monoStyle(
                                          size: 8,
                                          color: inkMuted,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      LinearProgressIndicator(
                                        value: item.value / max,
                                        minHeight: 4,
                                        backgroundColor: paperDeep,
                                        color: coral,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        })
                        .toList(),
                  ),
                ),
                const SizedBox(height: 13),
                _InsightCard(
                  eyebrow: 'seasonal breakdown',
                  title: 'a year in little tastes.',
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      height: 145,
                      child: CustomPaint(painter: SeasonalChartPainter()),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: mustard.withValues(alpha: 0.28),
                    border: Border.all(color: mustard.withValues(alpha: 0.65)),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 19,
                        color: seaDeep,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This stays on your device. Insights are private, offline, and never a score of how well you eat.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _prettyIngredient(String id) {
    return id
        .split('-')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.eyebrow,
    required this.title,
    required this.child,
  });

  final String eyebrow;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 17),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F5ED).withValues(alpha: 0.82),
        border: Border.all(color: const Color(0xFFD7CABC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Eyebrow(eyebrow),
          const SizedBox(height: 5),
          Text(title, style: displayStyle(size: 22)),
          child,
        ],
      ),
    );
  }
}

class SeasonalChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final values = <double>[
      0.34,
      0.48,
      0.65,
      0.72,
      0.58,
      0.84,
      0.92,
      0.7,
      0.63,
      0.49,
      0.37,
      0.42,
    ];
    final labels = <String>[
      'j',
      'f',
      'm',
      'a',
      'm',
      'j',
      'j',
      'a',
      's',
      'o',
      'n',
      'd',
    ];
    final barWidth = size.width / values.length - 5;
    final baseY = size.height - 22;
    final grid = Paint()
      ..color = ink.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, baseY), Offset(size.width, baseY), grid);
    canvas.drawLine(
      Offset(0, baseY - size.height * 0.5),
      Offset(size.width, baseY - size.height * 0.5),
      grid,
    );
    for (var i = 0; i < values.length; i++) {
      final x = i * (barWidth + 5);
      final height = (size.height - 43) * values[i];
      final bar = Paint()..color = i.isEven ? sea : coral;
      canvas.drawRect(Rect.fromLTWH(x, baseY - height, barWidth, height), bar);
      final textPainter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: monoStyle(size: 9, color: inkMuted, letterSpacing: 0),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(x + barWidth / 2 - textPainter.width / 2, baseY + 7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant SeasonalChartPainter oldDelegate) => false;
}

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool password = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          PageTopBar(
            title: 'backup & restore',
            showBack: true,
            onBack: store.back,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: <Widget>[
                Text(
                  'keep a copy.\nkeep your calm.',
                  style: displayStyle(size: 34),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your cookbook is yours. Export a readable file whenever you like.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 21),
                _BackupOption(
                  icon: Icons.description_outlined,
                  title: 'morphcook-backup.json',
                  detail: 'Human-readable · best for debugging',
                  color: sea,
                  onTap: () => _showExport(context, compressed: false),
                ),
                const SizedBox(height: 10),
                _BackupOption(
                  icon: Icons.folder_zip_outlined,
                  title: 'morphcook-backup.json.gz',
                  detail: 'Compressed · best for sharing',
                  color: mustard,
                  onTap: () => _showExport(context, compressed: true),
                ),
                const SizedBox(height: 17),
                ToggleRow(
                  title: 'Password-protect JSON',
                  subtitle: 'AES-256-GCM when the backup is sensitive',
                  value: password,
                  onChanged: (value) => setState(() => password = value),
                ),
                if (password) ...<Widget>[
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'backup password',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: blush.withValues(alpha: 0.34),
                    border: Border.all(color: coral.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'The compressed file remains unencrypted for compatibility. Encrypted JSON begins with ENC so imports can identify it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                const DashedRule(),
                Eyebrow('restore'),
                const SizedBox(height: 7),
                Text(
                  'Bring back a MorphCook JSON or GZip file. The bundled recipes are never changed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 13),
                QuietButton(
                  label: 'choose a backup file',
                  icon: Icons.file_open_outlined,
                  onPressed: () => _showImport(context),
                ),
                const SizedBox(height: 23),
                Text(
                  'backup contains',
                  style: monoStyle(size: 9, color: coral),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children:
                      <String>[
                            'profile',
                            '${store.savedIds.length} saved recipes',
                            '${store.mealPlan.length} meal slots',
                            '${store.history.length} cooked moments',
                          ]
                          .map(
                            (label) => TagPill(
                              label,
                              color: sea.withValues(alpha: 0.6),
                              compact: true,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showExport(
    BuildContext context, {
    required bool compressed,
  }) async {
    final bundle = await BackupService.create(
      widget.store,
      password: password ? _passwordController.text : null,
    );
    if (!context.mounted) return;
    final json = widget.store.backupJson();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: paper,
          title: Text(
            compressed ? 'GZip backup ready' : 'JSON backup ready',
            style: displayStyle(size: 24),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  compressed
                      ? 'The compressed payload is ready for your OS share sheet.'
                      : 'The readable payload is ready for your OS share sheet.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 230),
                  padding: const EdgeInsets.all(10),
                  color: night,
                  child: SingleChildScrollView(
                    child: Text(
                      json,
                      style: monoStyle(
                        size: 8,
                        color: whiteInk,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('close', style: monoStyle(size: 9, color: inkMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await BackupService.share(bundle);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Backup sent to the share sheet.'),
                      ),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The share sheet was not available on this device.',
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text('share', style: monoStyle(size: 9, color: whiteInk)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImport(BuildContext context) async {
    final picked = await FilePicker.pickFiles(withData: true);
    if (!context.mounted) return;
    if (picked == null || picked.files.isEmpty) return;
    final selected = picked.files.single;
    final bytes =
        selected.bytes ??
        (selected.path == null
            ? null
            : await File(selected.path!).readAsBytes());
    if (!context.mounted) return;
    if (bytes == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This backup could not be read.')),
        );
      }
      return;
    }
    String? password;
    if (bytes.length >= 3 &&
        bytes[0] == 0x45 &&
        bytes[1] == 0x4E &&
        bytes[2] == 0x43) {
      password = await _askForPassword(context);
      if (!context.mounted) return;
      if (password == null) return;
    }
    try {
      final payload = await BackupService.decode(bytes, password: password);
      if (!context.mounted) return;
      final replace = await _askRestoreMode(context);
      if (replace == null) return;
      widget.store.restoreBackup(payload, replace: replace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored to this device.')),
        );
      }
    } on BackupException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  Future<String?> _askForPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: paper,
        title: Text('backup password', style: displayStyle(size: 23)),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'enter password'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel', style: monoStyle(size: 9, color: inkMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text('unlock', style: monoStyle(size: 9, color: whiteInk)),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool?> _askRestoreMode(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: paper,
        title: Text('restore mode', style: displayStyle(size: 23)),
        content: Text(
          'Replace this device’s cookbook data, or merge the backup into what is already here?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel', style: monoStyle(size: 9, color: inkMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('merge', style: monoStyle(size: 9, color: seaDeep)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('replace', style: monoStyle(size: 9, color: whiteInk)),
          ),
        ],
      ),
    );
  }
}

class _BackupOption extends StatelessWidget {
  const _BackupOption({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.32),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: <Widget>[
              Icon(icon, color: seaDeep, size: 27),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: displayStyle(size: 19)),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: monoStyle(
                        size: 9,
                        color: inkMuted,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.ios_share_outlined, size: 18, color: seaDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final Set<String> expanded = <String>{};
  int tab = 0;

  AppStore get store => widget.store;

  @override
  Widget build(BuildContext context) {
    final dish = store.activeDish;
    final recipe = store.activeRecipe;
    if (dish == null || recipe == null) return const SizedBox.shrink();
    final variants = store.variantsFor(dish);
    final language = store.lang;
    return ScreenFrame(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: PageTopBar(
              title: dish.title(language),
              showBack: true,
              onBack: store.back,
              trailing: IconButton(
                onPressed: () => store.toggleSaved(recipe.id),
                icon: Icon(
                  store.isSaved(recipe.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                ),
                color: coral,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 32),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  StripeArt(
                    color: Color(recipe.accent),
                    caption: recipe.caption(language),
                    pattern: dish.pattern,
                    height: 245,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(17, 14, 17, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Eyebrow(
                            dish.kicker(language),
                            color: ink.withValues(alpha: 0.72),
                          ),
                          const Spacer(),
                          Text(
                            recipe.name(language),
                            style: displayStyle(size: 37),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            recipe.subline(language),
                            style: monoStyle(
                              size: 9,
                              color: ink,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    recipe.blurb(language),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      StatBox(
                        value: '${recipe.timeMinutes}',
                        label: 'minutes',
                        color: sea,
                      ),
                      const SizedBox(width: 7),
                      StatBox(
                        value: '${recipe.calories}',
                        label: 'kcal / serving',
                        color: mustard,
                      ),
                      const SizedBox(width: 7),
                      StatBox(
                        value: recipe.effort,
                        label: 'effort',
                        color: blush,
                      ),
                    ],
                  ),
                  const DashedRule(padding: 17),
                  Eyebrow('make it yours'),
                  const SizedBox(height: 6),
                  Text(
                    'same dish. your version.',
                    style: displayStyle(size: 26),
                  ),
                  const SizedBox(height: 10),
                  _VariantRow(
                    label: 'diet',
                    selected: recipe.diet,
                    options: variants.map((item) => item.diet).toSet().toList(),
                    expanded: expanded.contains('diet'),
                    isAvailable: (value) => store.variantAvailable(
                      variants.firstWhere((item) => item.diet == value),
                      ignoreCalories: true,
                    ),
                    onToggle: () => setState(() => _toggle('diet')),
                    onSelect: (value) {
                      store.selectVariant(dish, 'diet', value);
                      setState(() => expanded.remove('diet'));
                    },
                  ),
                  _VariantRow(
                    label: 'effort',
                    selected: recipe.effort,
                    options: variants
                        .map((item) => item.effort)
                        .toSet()
                        .toList(),
                    expanded: expanded.contains('effort'),
                    isAvailable: (value) => store.variantAvailable(
                      variants.firstWhere((item) => item.effort == value),
                    ),
                    onToggle: () => setState(() => _toggle('effort')),
                    onSelect: (value) {
                      store.selectVariant(dish, 'effort', value);
                      setState(() => expanded.remove('effort'));
                    },
                  ),
                  _VariantRow(
                    label: 'calorie level',
                    selected: recipe.calorieBucket(),
                    options: variants
                        .map((item) => item.calorieBucket())
                        .toSet()
                        .toList(),
                    expanded: expanded.contains('calorie'),
                    isAvailable: (value) => store.variantAvailable(
                      variants.firstWhere(
                        (item) => item.calorieBucket() == value,
                      ),
                      ignoreCalories: true,
                    ),
                    onToggle: () => setState(() => _toggle('calorie')),
                    onSelect: (value) {
                      store.selectVariant(dish, 'calorie', value);
                      setState(() => expanded.remove('calorie'));
                    },
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: store.toggleCalorieOverride,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            store.showOutsideTarget
                                ? Icons.visibility_rounded
                                : Icons.visibility_outlined,
                            size: 17,
                            color: coral,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              store.showOutsideTarget
                                  ? 'showing versions outside target'
                                  : 'show versions outside calorie target',
                              style: monoStyle(
                                size: 9,
                                color: coral,
                                letterSpacing: 0.45,
                              ),
                            ),
                          ),
                          Icon(
                            store.showOutsideTarget
                                ? Icons.toggle_on_rounded
                                : Icons.toggle_off_outlined,
                            size: 23,
                            color: store.showOutsideTarget ? seaDeep : inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (store.showOutsideTarget) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(11),
                      color: blush.withValues(alpha: 0.35),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 17,
                            color: coral,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Showing versions outside your calorie target for this dish.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 19),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: PrimaryButton(
                          label: 'cook this one',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => store.startCooking(recipe.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      QuietButton(
                        label: 'shopping',
                        icon: Icons.playlist_add_rounded,
                        onPressed: () {
                          store.addToShopping(recipe.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to your smart list.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _DetailTabs(
                    selected: tab,
                    onChanged: (value) => setState(() => tab = value),
                  ),
                  const SizedBox(height: 17),
                  if (tab == 0) _Ingredients(recipe: recipe, lang: language),
                  if (tab == 1) _Method(recipe: recipe, lang: language),
                  if (tab == 2) _Macros(recipe: recipe),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String key) {
    if (!expanded.add(key)) expanded.remove(key);
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({
    required this.label,
    required this.selected,
    required this.options,
    required this.expanded,
    required this.isAvailable,
    required this.onToggle,
    required this.onSelect,
  });

  final String label;
  final String selected;
  final List<String> options;
  final bool expanded;
  final bool Function(String) isAvailable;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: <Widget>[
                Text(
                  '— $label',
                  style: monoStyle(
                    size: 9,
                    color: inkMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: const DashedRule(padding: 0),
                  ),
                ),
                Text(selected, style: displayStyle(size: 17)),
                const SizedBox(width: 6),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 19,
                  color: seaDeep,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.only(left: 15, right: 4, bottom: 10),
            child: Wrap(
              spacing: 7,
              runSpacing: 7,
              children: options.map((option) {
                final available = isAvailable(option);
                final current = option == selected;
                return GestureDetector(
                  onTap: available ? () => onSelect(option) : null,
                  child: Opacity(
                    opacity: available ? 1 : 0.4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: current ? sea : const Color(0xFFECE6DA),
                        border: Border.all(
                          color: current ? seaDeep : const Color(0xFFD7CABC),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (current)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.check_rounded,
                                size: 13,
                                color: seaDeep,
                              ),
                            ),
                          Text(
                            option,
                            style: monoStyle(
                              size: 9,
                              color: ink,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (!available)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                'not yet',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 7,
                                  color: inkMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _DetailTabs extends StatelessWidget {
  const _DetailTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = <String>['ingredients', 'method', 'macros'];
    return Row(
      children: labels.asMap().entries.map((entry) {
        final isSelected = entry.key == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(entry.key),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isSelected ? ink : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isSelected ? ink : const Color(0xFFD7CABC),
                  ),
                ),
              ),
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: monoStyle(
                  size: 9,
                  color: isSelected ? whiteInk : inkMuted,
                  letterSpacing: 0.45,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Ingredients extends StatelessWidget {
  const _Ingredients({required this.recipe, required this.lang});

  final Recipe recipe;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'for ${recipe.servings} people',
                style: handStyle(size: 21, color: coral),
              ),
            ),
            Text(
              'tap an ingredient to learn',
              style: monoStyle(size: 8, color: inkMuted, letterSpacing: 0.25),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9F5ED).withValues(alpha: 0.72),
            border: Border.all(color: const Color(0xFFD7CABC)),
          ),
          child: Column(
            children: recipe.ingredients.map((ingredient) {
              final guide = ingredientGuide[ingredient.id];
              return InkWell(
                onTap: guide == null ? null : () => _showGuide(context, guide),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 56,
                        child: Text(
                          _amountText(ingredient.amount),
                          style: monoStyle(
                            size: 9,
                            color: coral,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 53,
                        child: Text(
                          ingredient.unit,
                          style: monoStyle(
                            size: 8,
                            color: inkMuted,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ingredient.label(lang),
                          style: displayStyle(size: 17),
                        ),
                      ),
                      if (guide != null)
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 15,
                          color: seaDeep,
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _amountText(double amount) => amount == amount.roundToDouble()
      ? amount.round().toString()
      : amount.toStringAsFixed(1);

  void _showGuide(BuildContext context, Map<String, String> guide) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: paper,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Eyebrow('kitchen reference'),
              const SizedBox(height: 5),
              Text(guide['title']!, style: displayStyle(size: 28)),
              const SizedBox(height: 8),
              Text(
                guide['description']!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 10),
              Text(
                guide['tip']!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Method extends StatelessWidget {
  const _Method({required this.recipe, required this.lang});

  final Recipe recipe;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: recipe.steps.asMap().entries.map((entry) {
        final step = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                color: Color(recipe.accent).withValues(alpha: 0.7),
                alignment: Alignment.center,
                child: Text(
                  '${entry.key + 1}',
                  style: monoStyle(size: 10, color: ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step.label(lang),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              if (step.timerSeconds != null)
                Padding(
                  padding: const EdgeInsets.only(left: 7, top: 3),
                  child: Icon(Icons.timer_outlined, size: 16, color: coral),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Macros extends StatelessWidget {
  const _Macros({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final protein = (recipe.calories * 0.22 / 4).round();
    final carbs = (recipe.calories * 0.42 / 4).round();
    final fat = (recipe.calories * 0.36 / 9).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'a loose, useful estimate — not a moral score.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            StatBox(
              value: '${recipe.calories}',
              label: 'calories',
              color: mustard,
            ),
            const SizedBox(width: 7),
            StatBox(value: '${protein}g', label: 'protein', color: sea),
            const SizedBox(width: 7),
            StatBox(value: '${carbs}g', label: 'carbs', color: blush),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            StatBox(value: '${fat}g', label: 'fat', color: coral),
            const SizedBox(width: 7),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(15),
                color: paperDeep,
                child: Text(
                  'calculated per serving\nfor ${recipe.servings} servings',
                  style: monoStyle(
                    size: 9,
                    color: inkMuted,
                    letterSpacing: 0.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class CookModeScreen extends StatefulWidget {
  const CookModeScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<CookModeScreen> createState() => _CookModeScreenState();
}

class _CookModeScreenState extends State<CookModeScreen> {
  Timer? _timer;
  Timer? _alertTimer;
  late int stepIndex;
  late int remaining;
  late int servings;
  DateTime? _lastQuickTap;
  bool running = false;
  bool flashing = false;
  bool completed = false;

  AppStore get store => widget.store;

  Recipe? get recipe => store.activeRecipe;

  @override
  void initState() {
    super.initState();
    final current = recipe;
    stepIndex = current == null ? 0 : (store.cookProgress[current.id] ?? 0);
    remaining = current == null
        ? 0
        : (current.steps[stepIndex].timerSeconds ?? 0);
    servings = current?.servings ?? 2;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _alertTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final current = recipe;
    if (current == null) return const SizedBox.shrink();
    final step = current.steps[stepIndex];
    final total = current.steps.length;
    final progress = completed ? 1.0 : stepIndex / total;
    return ScreenFrame(
      dark: true,
      child: AnimatedContainer(
        duration: store.profile.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 220),
        color: flashing
            ? (stepIndex.isEven
                  ? coral.withValues(alpha: 0.93)
                  : seaDeep.withValues(alpha: 0.95))
            : Colors.transparent,
        child: Column(
          children: <Widget>[
            PageTopBar(
              title: 'cook mode',
              dark: true,
              showBack: true,
              onBack: () {
                _timer?.cancel();
                store.back();
              },
              trailing: Text(
                '${current.timeMinutes} min',
                style: monoStyle(size: 9, color: sea),
              ),
            ),
            Expanded(
              child: completed
                  ? _Completion(
                      recipe: current,
                      onDone: () => store.finishCooking(current.id),
                    )
                  : _StepContent(
                      recipe: current,
                      step: step,
                      stepIndex: stepIndex,
                      servings: servings,
                      remaining: remaining,
                      running: running,
                      progress: progress,
                      onTap: _quickTap,
                      onPrevious: _previous,
                      onNext: _next,
                      onTimer: _toggleTimer,
                      onServings: _showServings,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _quickTap() {
    if (!store.profile.quickNextTapEnabled || store.profile.reduceMotion) {
      return;
    }
    final now = DateTime.now();
    if (_lastQuickTap != null &&
        now.difference(_lastQuickTap!).inMilliseconds < 300) {
      return;
    }
    _lastQuickTap = now;
    _next();
    HapticFeedback.selectionClick();
  }

  void _next() {
    final current = recipe;
    if (current == null) return;
    _timer?.cancel();
    setState(() {
      running = false;
      if (stepIndex >= current.steps.length - 1) {
        completed = true;
        return;
      }
      stepIndex += 1;
      remaining = current.steps[stepIndex].timerSeconds ?? 0;
    });
    store.setCookProgress(current.id, stepIndex);
    HapticFeedback.selectionClick();
  }

  void _previous() {
    if (stepIndex == 0) return;
    _timer?.cancel();
    setState(() {
      running = false;
      stepIndex -= 1;
      remaining = recipe!.steps[stepIndex].timerSeconds ?? 0;
    });
    store.setCookProgress(recipe!.id, stepIndex);
  }

  void _toggleTimer() {
    final current = recipe;
    if (current == null || current.steps[stepIndex].timerSeconds == null) {
      return;
    }
    if (running) {
      _timer?.cancel();
      setState(() => running = false);
      return;
    }
    if (remaining <= 0) {
      setState(() => remaining = current.steps[stepIndex].timerSeconds!);
    }
    setState(() => running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (remaining <= 1) {
        _timer?.cancel();
        setState(() {
          remaining = 0;
          running = false;
          flashing = store.profile.visualAlertEnabled;
        });
        if (store.profile.visualAlertEnabled) {
          _alertTimer?.cancel();
          _alertTimer = Timer(const Duration(milliseconds: 1400), () {
            if (mounted) setState(() => flashing = false);
          });
        }
      } else {
        setState(() => remaining -= 1);
      }
    });
  }

  void _showServings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: nightSoft,
      builder: (context) {
        var draft = servings;
        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 23, 22, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Eyebrow('scale the quiet feast', color: sea),
                  const SizedBox(height: 6),
                  Text(
                    'servings',
                    style: displayStyle(size: 28, color: whiteInk),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ingredient amounts follow the base recipe. Your chosen serving count stays with this cook session.',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 16,
                      height: 1.4,
                      color: whiteInk.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: draft <= 1
                            ? null
                            : () => setSheetState(() => draft -= 1),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        color: coral,
                      ),
                      Text(
                        '$draft',
                        style: displayStyle(size: 28, color: whiteInk),
                      ),
                      IconButton(
                        onPressed: () => setSheetState(() => draft += 1),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        color: sea,
                      ),
                      const Spacer(),
                      QuietButton(
                        label: 'use this',
                        onPressed: () {
                          setState(() => servings = draft);
                          Navigator.pop(context);
                        },
                        color: sea,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent({
    required this.recipe,
    required this.step,
    required this.stepIndex,
    required this.servings,
    required this.remaining,
    required this.running,
    required this.progress,
    required this.onTap,
    required this.onPrevious,
    required this.onNext,
    required this.onTimer,
    required this.onServings,
  });

  final Recipe recipe;
  final CookingStep step;
  final int stepIndex;
  final int servings;
  final int remaining;
  final bool running;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onTimer;
  final VoidCallback onServings;

  @override
  Widget build(BuildContext context) {
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 13, 22, 19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    recipe.name('en'),
                    style: displayStyle(size: 20, color: whiteInk),
                  ),
                ),
                Text(
                  '${stepIndex + 1} / ${recipe.steps.length}',
                  style: monoStyle(size: 10, color: sea),
                ),
              ],
            ),
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: whiteInk.withValues(alpha: 0.16),
                color: coral,
              ),
            ),
            const Spacer(),
            Text(
              'step ${stepIndex + 1}',
              style: monoStyle(size: 10, color: sea, letterSpacing: 1.2),
            ),
            const SizedBox(height: 14),
            Text(
              step.label('en'),
              style: displayStyle(size: 36, color: whiteInk),
            ),
            const SizedBox(height: 19),
            if (step.timerSeconds != null)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                decoration: BoxDecoration(
                  color: whiteInk.withValues(alpha: 0.08),
                  border: Border.all(color: sea.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.timer_outlined, color: sea, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        remaining == 0 ? 'timer complete' : '$minutes:$seconds',
                        style: displayStyle(size: 27, color: whiteInk),
                      ),
                    ),
                    QuietButton(
                      label: running
                          ? 'pause'
                          : remaining == 0
                          ? 'again'
                          : 'start',
                      onPressed: onTimer,
                      color: sea,
                    ),
                  ],
                ),
              ),
            const Spacer(),
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: onServings,
                  icon: const Icon(Icons.people_outline_rounded),
                  color: sea,
                  tooltip: 'servings',
                ),
                Text(
                  '$servings people',
                  style: monoStyle(size: 8, color: sea, letterSpacing: 0.35),
                ),
                const Spacer(),
                Text(
                  'tap to advance',
                  style: monoStyle(
                    size: 8,
                    color: whiteInk.withValues(alpha: 0.5),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: whiteInk.withValues(alpha: 0.65),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  color: coral,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({required this.recipe, required this.onDone});

  final Recipe recipe;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Spacer(),
          Text(
            'well, that\nwas lovely.',
            style: displayStyle(size: 45, color: whiteInk),
          ),
          const SizedBox(height: 14),
          Text(
            'The kitchen gets a little quieter after a good meal.',
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              height: 1.4,
              color: whiteInk.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 22),
          StripeArt(
            color: Color(recipe.accent),
            caption: recipe.name('en'),
            pattern: recipe.id.hashCode.abs() % 6 + 1,
            height: 150,
          ),
          const Spacer(),
          PrimaryButton(
            label: 'save this moment',
            icon: Icons.check_rounded,
            onPressed: onDone,
            expand: true,
          ),
        ],
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final TextEditingController nameController;
  int step = 0;
  String language = 'en';
  String diet = 'flexible';
  final Set<String> allergies = <String>{};
  int time = 45;
  int calories = 600;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.store.profile.name);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = step == 4;
    return ScreenFrame(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Row(
              children: <Widget>[
                const BrandMark(),
                const Spacer(),
                if (step > 0)
                  IconButton(
                    onPressed: () => setState(() => step -= 1),
                    icon: const Icon(Icons.arrow_back_rounded, color: inkMuted),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            child: Row(
              children: List<Widget>.generate(
                5,
                (index) => Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.only(right: 5),
                    color: index <= step ? coral : paperDeep,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: widget.store.profile.reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              child: _onboardingContent(context, key: ValueKey<int>(step)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
            child: PrimaryButton(
              label: isLast ? 'open my cookbook' : 'keep going',
              icon: isLast
                  ? Icons.arrow_forward_rounded
                  : Icons.arrow_forward_rounded,
              onPressed: _next,
              expand: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _onboardingContent(BuildContext context, {required Key key}) {
    switch (step) {
      case 0:
        return Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(20, 35, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              StripeArt(
                color: coral,
                caption: 'your cookbook',
                pattern: 1,
                height: 220,
              ),
              const SizedBox(height: 24),
              Text(
                'a cookbook\nthat makes room.',
                style: displayStyle(size: 40),
              ),
              const SizedBox(height: 10),
              Text(
                'Every dish has a version for every body. Start with a few small things so the book can feel like yours.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              Text('your language', style: monoStyle(size: 9, color: coral)),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  _Choice(
                    label: 'english',
                    value: 'en',
                    groupValue: language,
                    onTap: () => setState(() => language = 'en'),
                  ),
                  const SizedBox(width: 8),
                  _Choice(
                    label: 'deutsch',
                    value: 'de',
                    groupValue: language,
                    onTap: () => setState(() => language = 'de'),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        );
      case 1:
        return Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(20, 45, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('first things first.', style: displayStyle(size: 39)),
              const SizedBox(height: 9),
              Text(
                'What should we call you around here?',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 27),
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(hintText: 'your name'),
              ),
            ],
          ),
        );
      case 2:
        return Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(20, 45, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'what belongs\non your table?',
                style: displayStyle(size: 38),
              ),
              const SizedBox(height: 9),
              Text(
                'Choose a way of eating, or leave the door open.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 25),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    <String>[
                          'flexible',
                          'vegan',
                          'vegetarian',
                          'pescatarian',
                          'halal',
                          'kosher',
                        ]
                        .map(
                          (item) => _Choice(
                            label: item,
                            value: item,
                            groupValue: diet,
                            onTap: () => setState(() => diet = item),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 27),
              Text(
                'anything to avoid?',
                style: monoStyle(size: 9, color: coral),
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    <String>[
                          'dairy',
                          'nuts',
                          'shellfish',
                          'gluten',
                          'apples',
                          'cilantro',
                        ]
                        .map(
                          (item) => _ToggleChoice(
                            label: item,
                            selected: allergies.contains(item),
                            onTap: () => setState(() {
                              if (!allergies.add(item)) allergies.remove(item);
                            }),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        );
      case 3:
        return Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(20, 45, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'how much room\ndo you have?',
                style: displayStyle(size: 38),
              ),
              const SizedBox(height: 9),
              Text(
                'The target is a helpful filter, never a judgement.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 30),
              _ProfileSection(
                title: 'time budget',
                trailing: Text(
                  '$time minutes',
                  style: monoStyle(size: 10, color: coral),
                ),
                child: Slider(
                  value: time.toDouble(),
                  min: 15,
                  max: 90,
                  divisions: 5,
                  activeColor: seaDeep,
                  onChanged: (value) => setState(() => time = value.round()),
                ),
              ),
              _ProfileSection(
                title: 'calorie target',
                trailing: Text(
                  '~$calories kcal',
                  style: monoStyle(size: 10, color: coral),
                ),
                child: Slider(
                  value: calories.toDouble(),
                  min: 300,
                  max: 1000,
                  divisions: 14,
                  activeColor: coral,
                  onChanged: (value) =>
                      setState(() => calories = value.round()),
                ),
              ),
            ],
          ),
        );
      default:
        return Padding(
          key: key,
          padding: const EdgeInsets.fromLTRB(20, 38, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Spacer(),
              HandNote('a little note', color: coral, size: 25),
              const SizedBox(height: 9),
              Text(
                'your book is\nready, ${nameController.text.isEmpty ? 'friend' : nameController.text}.',
                style: displayStyle(size: 40),
              ),
              const SizedBox(height: 13),
              Text(
                'We’ll keep the machinery invisible. You’ll just see recipes that fit the person standing in your kitchen.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 23),
              Container(
                padding: const EdgeInsets.all(15),
                color: sea.withValues(alpha: 0.28),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.auto_awesome_outlined, color: seaDeep),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your first page: vegan döner, golden soup, and a little room for whatever comes next.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ),
        );
    }
  }

  void _next() {
    if (step < 4) {
      setState(() => step += 1);
      return;
    }
    final avoid = <String>{...allergies};
    if (diet != 'flexible') avoid.add(diet);
    widget.store.finishOnboarding(
      widget.store.profile.copyWith(
        name: nameController.text.trim().isEmpty
            ? 'Friend'
            : nameController.text.trim(),
        lang: language,
        dietPreference: diet,
        avoidFlags: avoid,
        avoidIngredients: allergies
            .where((item) => item == 'apples' || item == 'cilantro')
            .toSet(),
        maxTimeMinutes: time,
        calorieTarget: calories,
      ),
    );
  }
}
