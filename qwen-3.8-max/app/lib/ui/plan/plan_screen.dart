import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/week.dart';
import '../../data/corpus_repository.dart';
import '../../data/models.dart';
import '../../domain/shopping.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../dish/dish_screen.dart';
import '../widgets.dart';

/// Meal planning: weekly grid (Mon–Sun × breakfast/lunch/dinner), tap to
/// assign, drag-drop between slots, one-tap export to shopping list.
/// Natural weekly pagination (max a handful of weeks rendered at once).
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  static const _basePage = 1000;
  late final PageController _weeks =
      PageController(initialPage: _basePage, keepPage: true);
  int _currentPage = _basePage;

  DateTime _mondayForPage(int page) =>
      mondayOf(DateTime.now()).add(Duration(days: 7 * (page - _basePage)));

  @override
  void dispose() {
    _weeks.dispose();
    super.dispose();
  }

  Future<void> _exportWeek(String week) async {
    final library = context.read<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final assignments = library.weekAssignments(week);
    if (assignments.isEmpty) return;
    final aggregator = ShoppingAggregator(corpus.ingredients);
    final lines = <({String id, double qty, String unit})>[];
    for (final recipeId in assignments.values) {
      final recipe = corpus.recipe(recipeId);
      if (recipe == null) continue;
      lines.addAll(aggregator.scaleRecipe(recipe, recipe.servings));
    }
    await library.addItemsToShopping(aggregator.aggregate(lines));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).get('added'),
            style: Type.mono(size: 12, color: Paper.white)),
        backgroundColor: Paper.teal,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final s = app.strings;
    final monday = _mondayForPage(_currentPage);
    final week = isoWeekKey(monday);
    final range =
        '${DateFormat('d.MM').format(monday)} – ${DateFormat('d.MM').format(monday.add(const Duration(days: 6)))}';

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.get('plan'), style: Type.displayBold(size: 30)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _weeks.previousPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut),
                      child: Text('←', style: Type.mono(size: 16)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.get('week')} $week',
                              style: Type.mono(size: 12)),
                          Text(range,
                              style: Type.mono(
                                  size: 10.5, color: Paper.inkSoft)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _exportWeek(week),
                      child: Text('⛋ ${s.get('exportWeek')}',
                          style: Type.mono(size: 10, color: Paper.teal)),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: () => _weeks.nextPage(
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut),
                      child: Text('→', style: Type.mono(size: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const DashedLine(),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _weeks,
              onPageChanged: (page) =>
                  setState(() => _currentPage = page),
              itemBuilder: (context, page) {
                final pageMonday = _mondayForPage(page);
                final pageWeek = isoWeekKey(pageMonday);
                return _WeekGrid(
                  week: pageWeek,
                  monday: pageMonday,
                  onExport: () => _exportWeek(pageWeek),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final String week;
  final DateTime monday;
  final VoidCallback onExport;

  const _WeekGrid({
    required this.week,
    required this.monday,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
      child: Column(
        children: [
          // header row: day labels with dates
          Row(
            children: [
              const SizedBox(width: 46),
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Column(
                    children: [
                      Text(s.get(weekDays[d]),
                          style: Type.label(
                              color: d >= 5 ? Paper.coral : Paper.inkSoft)),
                      Text(
                        '${monday.add(Duration(days: d)).day}',
                        style: Type.mono(size: 10, color: Paper.inkFaint),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (final slot in mealSlots)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(s.get(slot),
                        style: Type.label(color: Paper.inkSoft)),
                  ),
                ),
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _PlanSlot(
                      week: week,
                      day: weekDays[d],
                      slot: slot,
                      recipeId: library.planAt(week, weekDays[d], slot),
                      corpus: corpus,
                      lang: lang,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlanSlot extends StatelessWidget {
  final String week;
  final String day;
  final String slot;
  final String? recipeId;
  final CorpusRepository corpus;
  final AppLang lang;

  const _PlanSlot({
    required this.week,
    required this.day,
    required this.slot,
    required this.recipeId,
    required this.corpus,
    required this.lang,
  });

  void _assign(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Paper.card,
      builder: (sheetContext) => _AssignSheet(
        onPick: (id) {
          context.read<LibraryModel>().setPlanSlot(week, day, slot, id);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipe = recipeId == null ? null : corpus.recipe(recipeId!);

    final cell = Container(
      height: 64,
      margin: const EdgeInsets.all(2.5),
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: recipe != null ? Paper.white : Colors.transparent,
        border: Border.all(
          color: recipe != null
              ? Paper.ink.withValues(alpha: 0.5)
              : Paper.rule.withValues(alpha: 0.6),
        ),
      ),
      child: recipe == null
          ? Center(
              child: Text('+',
                  style: Type.mono(size: 13, color: Paper.inkFaint)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tx(recipe.title, lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Type.mono(size: 9),
                ),
                Text('${recipe.timeMinutes}′',
                    style: Type.mono(size: 8, color: Paper.inkSoft)),
              ],
            ),
    );

    return DragTarget<Map<String, String>>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final from = details.data;
        final lib = context.read<LibraryModel>();
        final moving =
            lib.planAt(from['week']!, from['day']!, from['slot']!);
        if (moving == null) return;
        lib.setPlanSlot(week, day, slot, moving);
        lib.clearPlanSlot(from['week']!, from['day']!, from['slot']!);
      },
      builder: (context, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;
        return GestureDetector(
          onTap: () {
            if (recipe == null) {
              _assign(context);
            } else {
              _slotMenu(context);
            }
          },
          child: recipe == null
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: highlighted ? Paper.coral : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: cell,
                )
              : LongPressDraggable<Map<String, String>>(
                  data: {'week': week, 'day': day, 'slot': slot},
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(width: 110, child: cell),
                  ),
                  childWhenDragging: Container(
                    height: 64,
                    margin: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      border: Border.all(color: Paper.rule),
                    ),
                  ),
                  child: cell,
                ),
        );
      },
    );
  }

  void _slotMenu(BuildContext context) {
    final library = context.read<LibraryModel>();
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Paper.card,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tx(corpus.recipe(recipeId!)?.title, lang),
                style: Type.display(size: 20)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PaperButton(
                  label: s.get('cook'),
                  primary: false,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => DishScreen(
                        dishId: corpus.recipe(recipeId!)!.dishId,
                        initialRecipeId: recipeId,
                      ),
                    ));
                  },
                ),
                const SizedBox(width: 12),
                PaperButton(
                  label: s.get('removeFromPlan'),
                  primary: false,
                  onTap: () {
                    library.clearPlanSlot(week, day, slot);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Assignment sheet: pick from cookbook (saved) or search.
class _AssignSheet extends StatefulWidget {
  final ValueChanged<String> onPick;
  const _AssignSheet({required this.onPick});

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final lang = context.watch<AppModel>().lang;
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();

    final q = _query.text.trim().toLowerCase();
    List<Recipe> candidates;
    if (q.isEmpty) {
      candidates = [
        for (final id in library.savedByDateDesc())
          if (corpus.recipe(id) != null) corpus.recipe(id)!
      ];
    } else {
      candidates = corpus.loadedRecipes.where((r) {
        return tx(r.title, AppLang.en).toLowerCase().contains(q) ||
            tx(r.title, AppLang.de).toLowerCase().contains(q) ||
            r.tags.any((t) => t.toLowerCase().contains(q));
      }).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.get('assignRecipe'), style: Type.displayBold(size: 22)),
            const SizedBox(height: 12),
            PaperField(
              controller: _query,
              hint: s.get('searchPlaceholder'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: candidates.isEmpty
                  ? EmptyNote(title: s.get('empty'), note: s.get('emptyCookbook'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final recipe = candidates[index];
                        return GestureDetector(
                          onTap: () => widget.onPick(recipe.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 4),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Paper.rule)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(tx(recipe.title, lang),
                                      style: Type.mono(size: 12)),
                                ),
                                Text('${recipe.timeMinutes}′',
                                    style: Type.mono(
                                        size: 10, color: Paper.inkSoft)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
