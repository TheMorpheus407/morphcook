import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/engine/week.dart';
import '../../core/l10n.dart';
import '../../core/models/dish.dart';
import '../../core/models/local_text.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/striped_image.dart';

/// Weekly meal planner: Mon–Sun × breakfast/lunch/dinner, one week per page,
/// ±4 weeks navigable. Slots accept tap-to-assign and drag-drop moves.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  static const _maxWeekOffset = 4;

  int _weekOffset = 0;
  String? _dragSourceSlot;
  bool _intlReady = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting().then((_) {
      if (mounted) setState(() => _intlReady = true);
    });
  }

  DateTime get _monday => mondayOf(shiftWeeks(DateTime.now(), _weekOffset));
  String get _weekKey => isoWeekKey(_monday);

  bool get _reduceMotion =>
      context.read<ProfileStore>().profile.reduceMotion ??
      MediaQuery.disableAnimationsOf(context);

  Duration get _animDuration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  String get _locale => _intlReady ? S(context).lang : 'en';

  String _weekLabel(AppStrings s) {
    final weekNo = int.parse(_weekKey.split('-W')[1]);
    final start = _monday;
    final end = _monday.add(const Duration(days: 6));
    final month = DateFormat.MMMM(_locale);
    final String range;
    if (start.month == end.month) {
      range = '${start.day}–${end.day} ${month.format(start)}';
    } else {
      range =
          '${start.day} ${month.format(start)} – ${end.day} ${month.format(end)}';
    }
    return '${s.t('mealplan.week')} $weekNo · ${range.toLowerCase()}';
  }

  // ---- actions -----------------------------------------------------------

  void _shift(int delta) {
    setState(
      () => _weekOffset = (_weekOffset + delta).clamp(
        -_maxWeekOffset,
        _maxWeekOffset,
      ),
    );
  }

  Future<void> _moveRecipe(String recipeId, String targetSlot) async {
    final localStore = context.read<LocalStore>();
    final source = _dragSourceSlot;
    if (source == targetSlot) return;
    await localStore.assignSlot(_weekKey, targetSlot, recipeId);
    if (source != null) {
      await localStore.assignSlot(_weekKey, source, null);
    }
  }

  Future<void> _exportToShopping() async {
    final s = S(context);
    final messenger = ScaffoldMessenger.of(context);
    final localStore = context.read<LocalStore>();
    final corpus = context.read<CorpusRepository>();
    final plan = localStore.weekPlan(_weekKey);
    if (plan.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.t('mealplan.nothing_planned'))),
      );
      return;
    }
    final recipes = <String, Iterable<String>>{};
    for (final id in plan.values.toSet()) {
      final recipe = corpus.recipeById(id);
      if (recipe != null) recipes[id] = recipe.ingredientIds;
    }
    await localStore.addAllToShoppingList(recipes);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.t('mealplan.added_shopping')),
        action: SnackBarAction(
          label: s.t('mealplan.view'),
          textColor: AppColors.coralSoft,
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.shopping),
        ),
      ),
    );
  }

  Future<void> _showAssignSheet(String slot) async {
    final corpus = context.read<CorpusRepository>();
    final localStore = context.read<LocalStore>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.8,
        child: _AssignSheet(
          corpus: corpus,
          localStore: localStore,
          onPick: (recipeId) {
            Navigator.of(sheetContext).pop();
            localStore.assignSlot(_weekKey, slot, recipeId);
          },
        ),
      ),
    );
  }

  Future<void> _showSlotMenu(Recipe recipe) async {
    final s = S(context);
    final localStore = context.read<LocalStore>();
    final weekKey = _weekKey;
    // Find this recipe's slot in the current week (first match wins).
    final plan = localStore.weekPlan(weekKey);
    final slot = plan.entries.firstWhere((e) => e.value == recipe.id).key;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.restaurant_outlined,
                color: AppColors.ink,
              ),
              title: Text(
                s.t('mealplan.open_dish'),
                style: AppText.body(size: 16),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.dish, arguments: recipe.dishId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.coral),
              title: Text(
                s.t('mealplan.remove'),
                style: AppText.body(size: 16, color: AppColors.coral),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                localStore.assignSlot(weekKey, slot, null);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final localStore = context.watch<LocalStore>();
    final corpus = context.read<CorpusRepository>();
    final plan = localStore.weekPlan(_weekKey);

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(s),
            Expanded(
              child: AnimatedSwitcher(
                duration: _animDuration,
                child: KeyedSubtree(
                  key: ValueKey(_weekKey),
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        constraints.maxWidth >= 840
                        ? _buildWeekGrid(s, plan, corpus)
                        : _buildDayCards(s, plan, corpus),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppStrings s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.t('mealplan.title'),
                  style: AppText.masthead(size: 30),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportToShopping,
                icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                label: Text(
                  s.t('mealplan.to_shopping'),
                  style: AppText.monoLabel(size: 11, color: AppColors.ink),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.ink, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _navArrow(
                icon: Icons.chevron_left,
                tooltip: s.t('mealplan.prev_week'),
                onPressed: _weekOffset > -_maxWeekOffset
                    ? () => _shift(-1)
                    : null,
              ),
              Expanded(
                child: Text(
                  _weekLabel(s),
                  textAlign: TextAlign.center,
                  style: AppText.monoLabel(size: 12, color: AppColors.ink),
                ),
              ),
              _navArrow(
                icon: Icons.chevron_right,
                tooltip: s.t('mealplan.next_week'),
                onPressed: _weekOffset < _maxWeekOffset
                    ? () => _shift(1)
                    : null,
              ),
            ],
          ),
          AnimatedSize(
            duration: _animDuration,
            child: _weekOffset != 0
                ? Center(
                    child: TextButton(
                      onPressed: () => setState(() => _weekOffset = 0),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        s.t('mealplan.today'),
                        style: AppText.monoLabel(
                          size: 11,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _navArrow({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(
        icon,
        color: onPressed != null ? AppColors.ink : AppColors.disabled,
      ),
      splashRadius: 20,
    );
  }

  // ---- wide layout: 7 columns × 3 meal rows --------------------------------

  Widget _buildWeekGrid(
    AppStrings s,
    Map<String, String> plan,
    CorpusRepository corpus,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 72),
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Text(
                    '${DateFormat.E(_locale).format(_monday.add(Duration(days: d)))} '
                            '${_monday.add(Duration(days: d)).day}'
                        .toLowerCase(),
                    textAlign: TextAlign.center,
                    style: AppText.monoLabel(size: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var m = 0; m < mealSlots.length; m++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          s.t('mealplan.meal.${mealSlots[m]}'),
                          style: AppText.handwritten(size: 17),
                        ),
                      ),
                    ),
                    for (var d = 0; d < 7; d++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _Slot(
                            dayIndex: d,
                            mealIndex: m,
                            plan: plan,
                            corpus: corpus,
                            fillHeight: true,
                            animDuration: _animDuration,
                            isDragSource: _dragSourceSlot == slotKey(d, m),
                            onDragStarted: () =>
                                setState(() => _dragSourceSlot = slotKey(d, m)),
                            onDragEnd: () =>
                                setState(() => _dragSourceSlot = null),
                            onAccept: (recipeId) =>
                                _moveRecipe(recipeId, slotKey(d, m)),
                            onTapEmpty: () => _showAssignSheet(slotKey(d, m)),
                            onTapFilled: _showSlotMenu,
                          ),
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

  // ---- narrow layout: one day-card per day -----------------------------------

  Widget _buildDayCards(
    AppStrings s,
    Map<String, String> plan,
    CorpusRepository corpus,
  ) {
    final now = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: 7,
      itemBuilder: (context, d) {
        final date = _monday.add(Duration(days: d));
        final isToday =
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.polaroid,
            border: Border.all(
              color: AppColors.inkSoft.withValues(alpha: 0.5),
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${s.t('mealplan.day.${weekDaySlots[d]}')} · '
                              '${DateFormat.MMMd(_locale).format(date)}'
                          .toLowerCase(),
                      style: AppText.monoLabel(
                        size: 11,
                        color: isToday ? AppColors.teal : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  if (isToday)
                    Text(
                      s.t('mealplan.today'),
                      style: AppText.handwritten(
                        size: 16,
                        color: AppColors.teal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const DashedRule(),
              const SizedBox(height: 10),
              for (var m = 0; m < mealSlots.length; m++) ...[
                Text(
                  s.t('mealplan.meal.${mealSlots[m]}'),
                  style: AppText.monoLabel(size: 9),
                ),
                const SizedBox(height: 4),
                _Slot(
                  dayIndex: d,
                  mealIndex: m,
                  plan: plan,
                  corpus: corpus,
                  fillHeight: false,
                  animDuration: _animDuration,
                  isDragSource: _dragSourceSlot == slotKey(d, m),
                  onDragStarted: () =>
                      setState(() => _dragSourceSlot = slotKey(d, m)),
                  onDragEnd: () => setState(() => _dragSourceSlot = null),
                  onAccept: (recipeId) => _moveRecipe(recipeId, slotKey(d, m)),
                  onTapEmpty: () => _showAssignSheet(slotKey(d, m)),
                  onTapFilled: _showSlotMenu,
                ),
                if (m < mealSlots.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// One plan slot: DragTarget wrapper around an empty "+ add" box or a filled
/// mini polaroid. Filled slots are LongPressDraggable (data = recipeId).
class _Slot extends StatelessWidget {
  final int dayIndex;
  final int mealIndex;
  final Map<String, String> plan;
  final CorpusRepository corpus;
  final bool fillHeight;
  final Duration animDuration;
  final bool isDragSource;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final ValueChanged<String> onAccept;
  final VoidCallback onTapEmpty;
  final ValueChanged<Recipe> onTapFilled;

  const _Slot({
    required this.dayIndex,
    required this.mealIndex,
    required this.plan,
    required this.corpus,
    required this.fillHeight,
    required this.animDuration,
    required this.isDragSource,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAccept,
    required this.onTapEmpty,
    required this.onTapFilled,
  });

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final lang = s.lang;
    final recipeId = plan[slotKey(dayIndex, mealIndex)];
    final recipe = recipeId == null ? null : corpus.recipeById(recipeId);

    Widget content;
    if (recipe == null) {
      content = GestureDetector(
        onTap: onTapEmpty,
        behavior: HitTestBehavior.opaque,
        child: _DashedBorder(
          radius: 8,
          child: SizedBox(
            height: fillHeight ? double.infinity : 52,
            width: double.infinity,
            child: Center(
              child: Text(
                s.t('mealplan.add'),
                style: AppText.handwritten(size: 16),
              ),
            ),
          ),
        ),
      );
    } else {
      final dish = corpus.dishById(recipe.dishId);
      content = _FilledSlot(
        recipe: recipe,
        dish: dish,
        lang: lang,
        compact: !fillHeight,
      );
      content = GestureDetector(
        onTap: () => onTapFilled(recipe),
        child: content,
      );
      content = LongPressDraggable<String>(
        data: recipe.id,
        onDragStarted: onDragStarted,
        onDragEnd: (_) => onDragEnd(),
        onDraggableCanceled: (_, _) => onDragEnd(),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 150,
            child: Opacity(
              opacity: 0.9,
              child: _FilledSlot(
                recipe: recipe,
                dish: dish,
                lang: lang,
                compact: true,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: content),
        child: content,
      );
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => !isDragSource,
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: animDuration,
          decoration: BoxDecoration(
            color: hovering
                ? AppColors.tealSoft.withValues(alpha: 0.5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(2),
          child: content,
        );
      },
    );
  }
}

/// Mini polaroid for an assigned recipe: tiny striped thumb in the dish's
/// stripe color, dish name in Playfair, variant title in Caveat.
class _FilledSlot extends StatelessWidget {
  final Recipe recipe;
  final Dish? dish;
  final String lang;
  final bool compact;

  const _FilledSlot({
    required this.recipe,
    required this.dish,
    required this.lang,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final dishName = dish == null
        ? localize(recipe.title, lang)
        : localize(dish!.name, lang);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.polaroid,
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.75),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          StripedImage(
            stripeColor: dish?.stripeColor ?? '#C4573B',
            height: compact ? 26 : 34,
            showCaption: false,
          ),
          const SizedBox(height: 5),
          Text(
            dishName,
            style: AppText.headline(size: compact ? 13 : 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            localize(recipe.title, lang),
            style: AppText.handwritten(size: compact ? 15 : 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Assignment sheet: "cookbook" tab (saved recipes) + "search" tab (all
/// loaded recipes filtered by title/dish name).
class _AssignSheet extends StatefulWidget {
  final CorpusRepository corpus;
  final LocalStore localStore;
  final ValueChanged<String> onPick;

  const _AssignSheet({
    required this.corpus,
    required this.localStore,
    required this.onPick,
  });

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _allLoaded = false;

  @override
  void initState() {
    super.initState();
    widget.corpus.ensureAllLoaded().then((_) {
      if (mounted) setState(() => _allLoaded = true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.inkSoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          Text(s.t('mealplan.assign_title'), style: AppText.headline(size: 20)),
          TabBar(
            labelStyle: AppText.monoLabel(size: 11, color: AppColors.ink),
            unselectedLabelStyle: AppText.monoLabel(size: 11),
            labelColor: AppColors.ink,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.coral,
            tabs: [
              Tab(text: s.t('mealplan.tab_cookbook')),
              Tab(text: s.t('mealplan.tab_search')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [_buildCookbookTab(s), _buildSearchTab(s)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCookbookTab(AppStrings s) {
    final saved = widget.localStore.saved;
    if (saved.isEmpty) {
      return _QuietNote(text: s.t('mealplan.empty_saved'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: saved.length,
      itemBuilder: (context, i) {
        final recipe = widget.corpus.recipeById(saved[i].recipeId);
        if (recipe == null) return const SizedBox.shrink();
        return _RecipePickTile(
          recipe: recipe,
          dish: widget.corpus.dishById(recipe.dishId),
          lang: s.lang,
          onTap: () => widget.onPick(recipe.id),
        );
      },
    );
  }

  Widget _buildSearchTab(AppStrings s) {
    final lang = s.lang;
    final q = _query.trim().toLowerCase();
    final results = <Recipe>[];
    if (_allLoaded) {
      for (final recipe in widget.corpus.recipes.values) {
        if (q.isNotEmpty) {
          final dish = widget.corpus.dishById(recipe.dishId);
          final hay =
              '${localize(recipe.title, lang)} ${localize(dish?.name, lang)}'
                  .toLowerCase();
          if (!hay.contains(q)) continue;
        }
        results.add(recipe);
        if (results.length >= 50) break;
      }
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            style: AppText.body(size: 15),
            cursorColor: AppColors.coral,
            decoration: InputDecoration(
              hintText: s.t('mealplan.search_hint'),
              hintStyle: AppText.body(size: 15, color: AppColors.inkSoft),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.inkSoft,
              ),
              isDense: true,
              filled: true,
              fillColor: AppColors.paperDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: !_allLoaded
              ? Center(
                  child: Text(
                    s.t('common.loading'),
                    style: AppText.monoLabel(),
                  ),
                )
              : results.isEmpty
              ? _QuietNote(text: s.t('mealplan.no_results'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: results.length,
                  itemBuilder: (context, i) => _RecipePickTile(
                    recipe: results[i],
                    dish: widget.corpus.dishById(results[i].dishId),
                    lang: lang,
                    onTap: () => widget.onPick(results[i].id),
                  ),
                ),
        ),
      ],
    );
  }
}

class _QuietNote extends StatelessWidget {
  final String text;
  const _QuietNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppText.handwritten(size: 18),
        ),
      ),
    );
  }
}

class _RecipePickTile extends StatelessWidget {
  final Recipe recipe;
  final Dish? dish;
  final String lang;
  final VoidCallback onTap;

  const _RecipePickTile({
    required this.recipe,
    required this.dish,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.stripe(dish?.stripeColor ?? '#C4573B'),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish == null
                        ? localize(recipe.title, lang)
                        : localize(dish!.name, lang),
                    style: AppText.headline(size: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    localize(recipe.title, lang),
                    style: AppText.handwritten(size: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${recipe.timeMinutes} ${s.t('common.minutes')}',
              style: AppText.monoLabel(size: 10),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet dashed-border box for empty slots.
class _DashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  const _DashedBorder({required this.child, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;
  _DashedBorderPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.inkSoft.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, math.min(distance + 5, metric.length)),
          paint,
        );
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}
