import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/stripes.dart';
import '../logic/shopping_aggregator.dart';
import '../models/recipe.dart';
import '../models/shopping.dart';
import '../state/app_state.dart';

/// Meal planner — weekly grid (Mon–Sun × breakfast/lunch/dinner).
/// Tap to assign, drag-drop between slots, one-tap export to shopping list.
class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late String _week;

  @override
  void initState() {
    super.initState();
    _week = IsoWeek.of(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final plan = store.mealPlan[_week] ?? const <String, String>{};

    return PaperBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Masthead(
                subtitle: context.t('plTitle'),
                trailing: _weekNav(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Text(
                context.t('plHint'),
                style: TextStyle(
                  fontFamily: 'Caveat',
                  fontSize: 16,
                  color: MC.inkSoft,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _grid(context, plan),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: plan.isEmpty
                      ? null
                      : () {
                          _exportWeek(context, plan);
                        },
                  icon: const Icon(Icons.shopping_basket_outlined, size: 16),
                  label: Text(context.t('plExport')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weekNav(BuildContext context) {
    final monday = IsoWeek.mondayOf(_week);
    final sunday = monday.add(const Duration(days: 6));
    String d(DateTime t) => '${t.day}.${t.month}.';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () => setState(() => _week = IsoWeek.previous(_week)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${context.t('plWeek')} ${_week.split('-W')[1]}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                letterSpacing: 1,
                color: MC.inkSoft,
              ),
            ),
            Text(
              '${d(monday)}–${d(sunday)}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 9,
                color: MC.inkFaint,
              ),
            ),
          ],
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: () => setState(() => _week = IsoWeek.next(_week)),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, Map<String, String> plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 66),
            for (final day in mealPlanWeekdays)
              Expanded(
                child: Center(
                  child: Text(
                    context.t('weekday.$day'),
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                      color: MC.inkSoft,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final meal in mealPlanMeals)
          Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 66,
                    child: Text(
                      context.t('meal.$meal'),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 10,
                        letterSpacing: 0.6,
                        color: MC.inkFaint,
                      ),
                    ),
                  ),
                  for (final day in mealPlanWeekdays)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2.5),
                        child: _Slot(
                          weekId: _week,
                          slot: '$day.$meal',
                          recipeId: plan['$day.$meal'],
                          onAssign: () => _assign(context, '$day.$meal'),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
      ],
    );
  }

  Future<void> _assign(BuildContext context, String slot) async {
    final corpus = context.read<Corpus>();
    final store = context.read<AppStore>();
    final matcher = context.read<Matcher>();
    await corpus.loadPartition('extended');

    final cookbook = matcher
        .filter(
          [for (final id in store.savedIds) if (corpus.recipe(id) != null) corpus.recipe(id)!],
          store.profile,
        )
        .toList();
    if (!context.mounted) return;
    final all = matcher.filter(corpus.allRecipes, store.profile).toList()
      ..sort((a, b) => context.recipeName(a).compareTo(context.recipeName(b)));

    showModalBottomSheet(
      context: context,
      backgroundColor: MC.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) => _SlotPicker(
        slotLabel: '${context.t('weekday.${slot.split('.').first}')} · ${context.t('meal.${slot.split('.').last}')}',
        cookbook: cookbook,
        all: all,
        onPick: (recipe) {
          store.assignSlot(_week, slot, recipe.id);
          Navigator.pop(sheetContext);
        },
        onClear: () {
          store.clearSlot(_week, slot);
          Navigator.pop(sheetContext);
        },
        hasRecipe: store.plannedRecipe(_week, slot) != null,
      ),
    );
  }

  void _exportWeek(BuildContext context, Map<String, String> plan) {
    final corpus = context.read<Corpus>();
    final store = context.read<AppStore>();
    final recipes = <Recipe>[
      for (final id in plan.values.toSet())
        if (corpus.recipe(id) != null) corpus.recipe(id)!,
    ];
    store.addShoppingEntries(ShoppingAggregator.entriesFromRecipes(recipes));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('plExported'))),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.weekId,
    required this.slot,
    required this.recipeId,
    required this.onAssign,
  });

  final String weekId;
  final String slot;
  final String? recipeId;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final store = context.read<AppStore>();
    final recipe = recipeId != null ? corpus.recipe(recipeId!) : null;

    Widget content;
    if (recipe == null) {
      content = InkWell(
        onTap: onAssign,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: MC.card.withValues(alpha: 0.5),
            border: Border.all(color: MC.rule, width: 1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Text(
              '+',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 16,
                color: MC.inkFaint,
              ),
            ),
          ),
        ),
      );
    } else {
      final slotTile = Container(
        height: 56,
        decoration: BoxDecoration(
          color: MC.card,
          border: Border.all(color: MC.ink.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              context.recipeName(recipe),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 8.5,
                height: 1.2,
                color: MC.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${recipe.caloriesPerServing}',
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 8,
                color: MC.coralDeep,
              ),
            ),
          ],
        ),
      );
      content = DragTarget<String>(
        onAcceptWithDetails: (details) {
          final from = details.data.split('|');
          store.assignSlot(weekId, slot, from[1]);
          store.clearSlot(from[0], slot);
        },
        builder: (context, candidate, rejected) => InkWell(
          onTap: onAssign,
          borderRadius: BorderRadius.circular(3),
          child: candidate.isNotEmpty
              ? Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: MC.flashTeal.withValues(alpha: 0.25),
                    border: Border.all(color: MC.teal, width: 1.4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                )
              : slotTile,
        ),
      );
      content = LongPressDraggable<String>(
        data: '$weekId|${recipe.id}',
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.85,
            child: Container(
              width: 100,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: MC.card,
                border: Border.all(color: MC.coral),
                borderRadius: BorderRadius.circular(3),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 8),
                ],
              ),
              child: Text(
                context.recipeName(recipe),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9,
                  color: MC.ink,
                ),
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: slotTile),
        child: content,
      );
    }
    return content;
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.slotLabel,
    required this.cookbook,
    required this.all,
    required this.onPick,
    required this.onClear,
    required this.hasRecipe,
  });

  final String slotLabel;
  final List<Recipe> cookbook;
  final List<Recipe> all;
  final void Function(Recipe) onPick;
  final VoidCallback onClear;
  final bool hasRecipe;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${context.t('plAssign')} — $slotLabel',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    if (hasRecipe)
                      TextButton(
                        onPressed: onClear,
                        child: Text(context.t('plClearSlot')),
                      ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: MC.coralDeep,
                unselectedLabelColor: MC.inkFaint,
                indicatorColor: MC.coral,
                tabs: [
                  Tab(
                    child: Text('cookbook',
                        style: TextStyle(
                            fontFamily: 'JetBrainsMono', fontSize: 11)),
                  ),
                  Tab(
                    child: Text('search',
                        style: TextStyle(
                            fontFamily: 'JetBrainsMono', fontSize: 11)),
                  ),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _list(context, cookbook, emptyText: 'cbEmpty'),
                    _list(context, all, emptyText: 'searchNoResults'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Recipe> recipes,
      {required String emptyText}) {
    if (recipes.isEmpty) {
      return Center(
        child: Text(
          context.t(emptyText),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, i) {
        final r = recipes[i];
        return ListTile(
          dense: true,
          leading: StripeThumb(colors: r.stripeColors, size: 38),
          title: Text(
            context.recipeName(r),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.5,
              color: MC.ink,
            ),
          ),
          subtitle: Text(
            '${r.caloriesPerServing} ${context.t('kcal')} · ${r.timeMinutes} ${context.t('minutes')}',
            style: const TextStyle(fontSize: 10.5, color: MC.inkFaint),
          ),
          onTap: () => onPick(r),
        );
      },
    );
  }
}
