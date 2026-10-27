import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/recipe.dart';
import '../models/user_data.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key, this.onOpenRecipe, this.onGoShopping});

  final void Function(String recipeId)? onOpenRecipe;
  final VoidCallback? onGoShopping;

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  static const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _meals = ['breakfast', 'lunch', 'dinner'];

  late final PageController _pages;
  late final List<DateTime> _weeks;
  final Set<String> _loadingRecipes = {};
  final Set<String> _failedRecipes = {};
  int _currentPage = 1;
  bool _rolling = false;
  bool _navigating = false;
  String? _exportingWeek;

  @override
  void initState() {
    super.initState();
    unawaited(initializeDateFormatting());
    final currentMonday = mondayForWeek(context.read<AppState>().clock());
    _weeks = [
      currentMonday.subtract(const Duration(days: 7)),
      currentMonday,
      currentMonday.add(const Duration(days: 7)),
      currentMonday.add(const Duration(days: 14)),
    ];
    _pages = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      body: Paper(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: SectionHeading(
                  context.l10n.t('planner_title'),
                  kicker: context.l10n.t('nav_plan'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.t('drag_hint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _weeks.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) =>
                      _buildWeekPage(context, index, appState),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekPage(BuildContext context, int index, AppState appState) {
    final monday = _weeks[index];
    final week = weekKey(monday);
    final plan = appState.snapshot.mealPlan[week] ?? const <String, String>{};
    for (final recipeId in plan.values) {
      if (appState.repository.recipes[recipeId] == null &&
          !_loadingRecipes.contains(recipeId) &&
          !_failedRecipes.contains(recipeId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_ensureRecipe(recipeId));
        });
      }
    }

    return SingleChildScrollView(
      key: PageStorageKey<String>('planner-$week'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeekHeader(monday),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: plan.isEmpty || _exportingWeek != null
                    ? null
                    : () => unawaited(_exportWeek(week)),
                icon: _exportingWeek == week
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.playlist_add_outlined, size: 18),
                label: Text(context.l10n.t('export_week')),
              ),
              TextButton.icon(
                onPressed: plan.isEmpty
                    ? null
                    : () => unawaited(_confirmClearWeek(week)),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(context.l10n.t('clear_week')),
              ),
            ],
          ),
          if (plan.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.coral),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n.t('planner_empty'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 12),
          _buildWeekGrid(context, appState, week, monday, plan),
        ],
      ),
    );
  }

  Widget _buildWeekHeader(DateTime monday) {
    final locale = Localizations.localeOf(context);
    final date = DateFormat.yMMMd(locale.toString()).format(monday);
    return Row(
      children: [
        _weekNavigationButton(-1),
        Expanded(
          child: Text(
            context.l10n.t('week_of', {'date': date}),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        _weekNavigationButton(1),
      ],
    );
  }

  Widget _weekNavigationButton(int delta) {
    return DragTarget<_MealDragData>(
      onWillAcceptWithDetails: (_) {
        unawaited(_goRelative(delta));
        return false;
      },
      onMove: (_) => unawaited(_goRelative(delta)),
      builder: (context, candidateData, rejectedData) => IconButton(
        tooltip: context.l10n.t(delta < 0 ? 'back' : 'next'),
        onPressed: () => unawaited(_goRelative(delta)),
        icon: Icon(delta < 0 ? Icons.chevron_left : Icons.chevron_right),
      ),
    );
  }

  Widget _buildWeekGrid(
    BuildContext context,
    AppState appState,
    String week,
    DateTime monday,
    Map<String, String> plan,
  ) {
    const labelWidth = 88.0;
    const dayWidth = 148.0;
    final locale = Localizations.localeOf(context);
    final localeName = locale.toString();
    final weekdayFormat = DateFormat.E(localeName);
    final fullWeekdayFormat = DateFormat.EEEE(localeName);
    final dateFormat = DateFormat.Md(localeName);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = math.max(
          constraints.maxWidth,
          labelWidth + dayWidth * 7,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              children: [
                _gridRow(
                  height: 62,
                  labelWidth: labelWidth,
                  label: const SizedBox.shrink(),
                  cells: List.generate(7, (dayIndex) {
                    final date = monday.add(Duration(days: dayIndex));
                    return Semantics(
                      label: fullWeekdayFormat.format(date),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: AppColors.coral),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weekdayFormat.format(date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              dateFormat.format(date),
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                for (final meal in _meals)
                  _gridRow(
                    height: 150,
                    labelWidth: labelWidth,
                    label: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.l10n.t(meal),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.handwritten
                              .copyWith(fontSize: 21),
                        ),
                      ),
                    ),
                    cells: List.generate(7, (dayIndex) {
                      final slot = '${_weekdays[dayIndex]}.$meal';
                      return _buildSlot(
                        appState,
                        week: week,
                        slot: slot,
                        recipeId: plan[slot],
                      );
                    }),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gridRow({
    required double height,
    required double labelWidth,
    required Widget label,
    required List<Widget> cells,
  }) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: labelWidth, child: label),
          for (final cell in cells) Expanded(child: cell),
        ],
      ),
    );
  }

  Widget _buildSlot(
    AppState appState, {
    required String week,
    required String slot,
    required String? recipeId,
  }) {
    final recipe = recipeId == null
        ? null
        : appState.repository.recipes[recipeId];
    final failed = recipeId != null && _failedRecipes.contains(recipeId);
    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => unawaited(_openPicker(week, slot)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _slotContent(
            appState,
            week: week,
            slot: slot,
            recipeId: recipeId,
            recipe: recipe,
            failed: failed,
          ),
        ),
      ),
    );

    if (recipeId != null && recipe != null) {
      final dragData = _MealDragData(week: week, slot: slot);
      content = Draggable<_MealDragData>(
        data: dragData,
        maxSimultaneousDrags: 1,
        feedback: _dragFeedback(recipe),
        childWhenDragging: Opacity(opacity: 0.25, child: content),
        child: content,
      );
    }

    return DragTarget<_MealDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.week != week || details.data.slot != slot,
      onAcceptWithDetails: (details) {
        appState.moveSlot(
          sourceWeek: details.data.week,
          sourceSlot: details.data.slot,
          targetWeek: week,
          targetSlot: slot,
        );
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: motionDuration(context, const Duration(milliseconds: 160)),
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.teal.withValues(alpha: 0.18)
                : AppColors.paperLight.withValues(alpha: 0.76),
            border: Border.all(
              color: highlighted
                  ? AppColors.teal
                  : AppColors.muted.withValues(alpha: 0.3),
              width: highlighted ? 1.5 : 0.8,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: content,
        );
      },
    );
  }

  Widget _slotContent(
    AppState appState, {
    required String week,
    required String slot,
    required String? recipeId,
    required Recipe? recipe,
    required bool failed,
  }) {
    if (recipeId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 19, color: AppColors.coral),
            const SizedBox(height: 5),
            Text(
              context.l10n.t('empty_slot'),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.handwritten
                  .copyWith(fontSize: 17, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final locale = Localizations.localeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: failed
              ? Center(
                  child: Text(
                    context.l10n.t('list_error'),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : recipe == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.t('loading'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        recipe.title.of(locale),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontSize: 15, height: 1.18),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.t('minutes', {
                        'count': '${recipe.timeMinutes}',
                      }),
                      style: Theme.of(
                        context,
                      ).textTheme.labelMedium?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (failed)
              _slotIconButton(
                tooltip: context.l10n.t('retry'),
                icon: Icons.refresh,
                onPressed: () => _retryRecipe(recipeId),
              ),
            if (recipe != null && widget.onOpenRecipe != null)
              _slotIconButton(
                tooltip: context.l10n.t('back_to_dish'),
                icon: Icons.open_in_new,
                onPressed: () => widget.onOpenRecipe!(recipeId),
              ),
            _slotIconButton(
              tooltip: context.l10n.t('clear'),
              icon: Icons.close,
              onPressed: () => appState.clearSlot(week, slot),
            ),
          ],
        ),
      ],
    );
  }

  Widget _slotIconButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _dragFeedback(Recipe recipe) {
    final locale = Localizations.localeOf(context);
    return Material(
      elevation: 5,
      color: AppColors.paperLight,
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        width: 180,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title.of(locale),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 7),
              Text(
                context.l10n.t('minutes', {'count': '${recipe.timeMinutes}'}),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ensureRecipe(String recipeId) async {
    final repository = context.read<AppState>().repository;
    if (repository.recipes.containsKey(recipeId) ||
        _loadingRecipes.contains(recipeId)) {
      return;
    }
    _loadingRecipes.add(recipeId);
    try {
      await repository.ensureRecipe(recipeId);
      _failedRecipes.remove(recipeId);
      if (repository.recipes[recipeId] == null) _failedRecipes.add(recipeId);
    } catch (_) {
      _failedRecipes.add(recipeId);
    } finally {
      _loadingRecipes.remove(recipeId);
      if (mounted) setState(() {});
    }
  }

  void _retryRecipe(String recipeId) {
    setState(() => _failedRecipes.remove(recipeId));
    unawaited(_ensureRecipe(recipeId));
  }

  Future<void> _openPicker(String week, String slot) async {
    final recipeId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.paperLight,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Paper(child: SafeArea(top: false, child: const _RecipePicker())),
      ),
    );
    if (!mounted || recipeId == null) return;
    context.read<AppState>().assignRecipe(week, slot, recipeId);
  }

  Future<void> _exportWeek(String week) async {
    if (_exportingWeek != null) return;
    final appState = context.read<AppState>();
    setState(() => _exportingWeek = week);
    try {
      await appState.exportWeekToShopping(week);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.t('week_exported')),
          action: widget.onGoShopping == null
              ? null
              : SnackBarAction(
                  label: context.l10n.t('nav_shopping'),
                  onPressed: widget.onGoShopping!,
                ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.t('list_error'))));
    } finally {
      if (mounted) setState(() => _exportingWeek = null);
    }
  }

  Future<void> _confirmClearWeek(String week) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.paperLight,
        title: Text(l10n.t('clear_week')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('clear')),
          ),
        ],
      ),
    );
    if (mounted && confirmed == true) context.read<AppState>().clearWeek(week);
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    if (index == 0) {
      _rollWindow(previous: true);
    } else if (index == _weeks.length - 1) {
      _rollWindow(previous: false);
    }
  }

  void _rollWindow({required bool previous}) {
    if (_rolling) return;
    _rolling = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        if (previous) {
          _weeks.insert(0, _weeks.first.subtract(const Duration(days: 7)));
          _weeks.removeLast();
          _currentPage = 1;
        } else {
          _weeks.add(_weeks.last.add(const Duration(days: 7)));
          _weeks.removeAt(0);
          _currentPage = _weeks.length - 2;
        }
      });
      if (_pages.hasClients) _pages.jumpToPage(_currentPage);
      _rolling = false;
    });
  }

  Future<void> _goRelative(int delta) async {
    if (_rolling || _navigating || !_pages.hasClients) return;
    final target = _currentPage + delta;
    if (target < 0 || target >= _weeks.length) return;
    _navigating = true;
    final reduceAnimations =
        context.read<AppState>().profile.reduceMotion ??
        MediaQuery.of(context).disableAnimations;
    try {
      await _pages.animateToPage(
        target,
        duration: reduceAnimations
            ? Duration.zero
            : const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _navigating = false;
    }
  }
}

class _MealDragData {
  const _MealDragData({required this.week, required this.slot});

  final String week;
  final String slot;
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker();

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _query = TextEditingController();
  List<Recipe> _savedRecipes = const [];
  List<Recipe> _searchRecipes = const [];
  bool _savedLoading = true;
  bool _savedError = false;
  bool _searchStarted = false;
  bool _searchLoading = false;
  bool _searchError = false;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    unawaited(_loadSaved());
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.t('assign_recipe'),
                  style: Theme.of(context).textTheme.headlineSmall?.handwritten,
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
          controller: _tabs,
          tabs: [
            Tab(text: context.l10n.t('from_cookbook')),
            Tab(text: context.l10n.t('from_search')),
          ],
        ),
        const DashedRule(height: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_buildSavedTab(), _buildSearchTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedTab() {
    if (_savedLoading) return _loadingMessage();
    if (_savedRecipes.isEmpty) {
      if (_savedError) return _errorMessage(_retrySaved);
      return EmptyState(
        title: context.l10n.t('cookbook_empty'),
        body: context.l10n.t('cookbook_empty_body'),
      );
    }
    return Column(
      children: [
        if (_savedError) _inlineError(_retrySaved),
        Expanded(child: _recipeList(_savedRecipes)),
      ],
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.l10n.t('search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: context.l10n.t('clear'),
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (value) => unawaited(_search(value)),
            onSubmitted: (value) => unawaited(_search(value)),
          ),
        ),
        if (!_searchLoading && !_searchError && _searchRecipes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.t('search_results', {
                  'count': '${_searchRecipes.length}',
                }),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
        Expanded(child: _buildSearchResults()),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (!_searchStarted || _searchLoading) return _loadingMessage();
    if (_searchError) return _errorMessage(_retrySearch);
    if (_searchRecipes.isEmpty) {
      return EmptyState(
        title: context.l10n.t('search_empty'),
        body: context.l10n.t('search_empty_body'),
      );
    }
    return _recipeList(_searchRecipes);
  }

  Widget _recipeList(List<Recipe> recipes) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        return _PickerRecipeTile(
          recipe: recipe,
          onTap: () => Navigator.of(context).pop(recipe.id),
        );
      },
    );
  }

  Widget _loadingMessage() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 1.5),
          const SizedBox(height: 16),
          Text(context.l10n.t('loading')),
        ],
      ),
    );
  }

  Widget _errorMessage(VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.t('list_error'), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.t('retry')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inlineError(VoidCallback onRetry) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.t('list_error'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(context.l10n.t('retry'))),
        ],
      ),
    );
  }

  void _onTabChanged() {
    if (_tabs.index == 1 && !_searchStarted) unawaited(_search(_query.text));
  }

  Future<void> _loadSaved() async {
    final appState = context.read<AppState>();
    final saved = [...appState.snapshot.saved]
      ..sort((a, b) {
        final byDate = b.savedAt.compareTo(a.savedAt);
        return byDate != 0 ? byDate : a.recipeId.compareTo(b.recipeId);
      });
    var failed = false;
    await Future.wait(
      saved.map((item) async {
        try {
          await appState.repository.ensureRecipe(item.recipeId);
        } catch (_) {
          failed = true;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _savedRecipes = saved
          .map((item) => appState.repository.recipes[item.recipeId])
          .whereType<Recipe>()
          .toList();
      _savedError = failed;
      _savedLoading = false;
    });
  }

  void _retrySaved() {
    setState(() {
      _savedLoading = true;
      _savedError = false;
    });
    unawaited(_loadSaved());
  }

  Future<void> _search(String query) async {
    final generation = ++_searchGeneration;
    final appState = context.read<AppState>();
    setState(() {
      _searchStarted = true;
      _searchLoading = true;
      _searchError = false;
      _searchRecipes = const [];
    });
    try {
      final page = await appState.repository.search(
        query,
        const <String>{},
        appState.profile,
        now: appState.clock(),
        lastCooked: appState.lastCooked,
        limit: 20,
      );
      if (!mounted || generation != _searchGeneration) return;
      if (page.recipes.isEmpty) appState.recordContentRequest(query);
      setState(() {
        _searchRecipes = page.recipes;
        _searchLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searchLoading = false;
        _searchError = true;
      });
    }
  }

  void _retrySearch() => unawaited(_search(_query.text));

  void _clearSearch() {
    _query.clear();
    unawaited(_search(''));
  }
}

class _PickerRecipeTile extends StatelessWidget {
  const _PickerRecipeTile({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.paperLight.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.muted.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        onTap: onTap,
        leading: const Icon(Icons.restaurant_outlined, color: AppColors.teal),
        title: Text(
          recipe.title.of(locale),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            context.l10n.t('minutes', {'count': '${recipe.timeMinutes}'}),
          ),
        ),
        trailing: const Icon(Icons.add_circle_outline, color: AppColors.coral),
      ),
    );
  }
}
