import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/nav_requests.dart';
import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/pagination/pagination_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/recipe.dart';
import '../../domain/plan/meal_plan.dart';
import '../../state/catalog.dart';
import '../../state/controllers/meal_plan_controller.dart';
import '../../state/controllers/shopping_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/skeleton.dart';
import 'week_grid.dart';
import '../../core/text_scale.dart';

/// The weekly meal plan. Weeks are pages (one week each, at most four in
/// memory); swipe to move between them.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  late final Catalog _catalog = context.read<Catalog>();
  late final WeekKey _thisWeek = WeekKey.fromDate(_catalog.clock());

  late final PaginationController<WeekKey> _weeks = PaginationController<WeekKey>.weekly(
    loader: (offset) async => _thisWeek.plusWeeks(offset),
  );

  PageController? _pages;
  int _page = 0;
  int _lastTrimmed = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _weeks.refresh();
    // One week either side of the current one, so swiping works straight away.
    await _weeks.loadMore();
    await _weeks.loadPrevious();
    if (!mounted) return;
    _lastTrimmed = _weeks.trimmedFront;
    _page = _weeks.items.indexOf(_thisWeek);
    _pages = PageController(initialPage: _page);
    _weeks.addListener(_onWeeksChanged);
    setState(() => _ready = true);
  }

  /// Pages that were added before or dropped from the front move every index.
  void _onWeeksChanged() {
    final pages = _pages;
    if (pages == null || !pages.hasClients) return;
    final trimmed = _weeks.trimmedFront;
    if (trimmed != _lastTrimmed) {
      final shift = _lastTrimmed - trimmed; // positive when pages were prepended
      _lastTrimmed = trimmed;
      final target = (pages.page?.round() ?? _page) + shift;
      pages.jumpToPage(target.clamp(0, _weeks.items.length - 1));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _weeks.removeListener(_onWeeksChanged);
    _weeks.dispose();
    _pages?.dispose();
    super.dispose();
  }

  void _onPage(int index) {
    _page = index;
    if (_weeks.shouldLoadMore(index)) _weeks.loadMore();
    if (_weeks.shouldLoadPrevious(index)) _weeks.loadPrevious();
    setState(() {});
  }

  void _goTo(int index) {
    final pages = _pages;
    if (pages == null || index < 0 || index >= _weeks.items.length) return;
    pages.animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _exportWeek(WeekKey week) async {
    final s = context.sRead;
    final messenger = ScaffoldMessenger.of(context);
    final nav = context.read<NavRequests>();
    final corpus = context.read<Corpus>();
    final shopping = context.read<ShoppingController>();
    final ids = context.read<MealPlanController>().plan.recipeIdsOf(week);
    final recipes = <Recipe>[];
    for (final id in ids) {
      final recipe = await corpus.loadRecipe(id);
      if (recipe != null) recipes.add(recipe);
    }
    if (recipes.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s('plan.export.empty'))));
      return;
    }
    await shopping.addRecipes(recipes);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(s.plural('plan.export.done', recipes.length)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: s('dish.viewList'),
            textColor: Palette.mustard,
            onPressed: () => nav.showTab(4),
          ),
        ),
      );
  }

  /// Title, week switcher and export button of one week. It scrolls with the
  /// grid, so large text and short screens never squeeze the grid out of view.
  Widget _header(BuildContext context, WeekKey week, {required int filled, int? index}) {
    final s = context.s;
    final weeks = _weeks.items;
    final canGoBack = _ready && index != null && index > 0;
    final canGoForward = _ready && index != null && index < weeks.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TabHeader(
          title: s('plan.title'),
          note: s('plan.note'),
          actions: [
            PaperIconButton(
              icon: Icons.settings_outlined,
              tooltip: s('nav.settings'),
              onPressed: () => openSettings(context),
            ),
          ],
        ),
        Row(
          children: [
            PaperIconButton(
              icon: Icons.chevron_left,
              tooltip: s('plan.previous'),
              onPressed: canGoBack ? () => _goTo(index - 1) : null,
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    week == _thisWeek ? s('plan.thisWeek') : s('plan.weekN', {'n': week.week}),
                    style: AppText.display(size: 24),
                  ),
                  Text(
                    '${s.shortDate(week.monday)} – ${s.shortDate(week.dateOf('sun'))}'.toUpperCase(),
                    style: AppText.label(size: 10),
                  ),
                ],
              ),
            ),
            PaperIconButton(
              icon: Icons.chevron_right,
              tooltip: s('plan.next'),
              onPressed: canGoForward ? () => _goTo(index + 1) : null,
            ),
          ],
        ),
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: _hintAndExport(context, week, filled)),
        const SizedBox(height: 4),
      ],
    );
  }

  /// The drag hint beside the export button, or above it when the text is large.
  Widget _hintAndExport(BuildContext context, WeekKey week, int filled) {
    final s = context.s;
    final hint = HandNote(s('plan.dragHint'), size: 19, color: Palette.inkSoft);
    final export = PaperButton(
      label: s('plan.export'),
      icon: Icons.add_shopping_cart,
      dense: true,
      style: PaperButtonStyle.outline,
      onPressed: filled == 0 ? null : () => _exportWeek(week),
    );
    if (context.largeText) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [hint, const SizedBox(height: 6), export]);
    }
    return Row(
      children: [
        Expanded(child: hint),
        export,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<MealPlanController>().plan;
    final weeks = _weeks.items;

    return SafeArea(
      bottom: false,
      child: !_ready
          ? SingleChildScrollView(
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, _thisWeek, filled: plan.recipeIdsOf(_thisWeek).length),
                    const SkeletonList(count: 5, rowHeight: 76),
                  ],
                ),
              ),
            )
          : PageView.builder(
              controller: _pages,
              itemCount: weeks.length,
              onPageChanged: _onPage,
              itemBuilder: (context, index) => WeekGrid(
                key: ValueKey(weeks[index]),
                week: weeks[index],
                header: _header(context, weeks[index], filled: plan.recipeIdsOf(weeks[index]).length, index: index),
              ),
            ),
    );
  }
}
