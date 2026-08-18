import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import '../models/collections.dart';
import '../models/recipe.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late DateTime _week;

  @override
  void initState() {
    super.initState();
    _week = weekStart(DateTime.now());
  }

  String get _key => isoWeekKey(_week);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final p = LedgerScope.colors(context);
    final plan = state.mealPlan[_key] ?? const <String, String>{};
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _week = _week.subtract(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${s('mealPlan')}  ·  $_key',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _week = _week.add(const Duration(days: 7)),
                  ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            QuietButton(
              label: s('exportWeekToList'),
              filled: false,
              onPressed: () async {
                final recipes = <(Recipe, double)>[];
                for (final id in plan.values) {
                  final r = await state.corpus.recipeById(id);
                  if (r != null) recipes.add((r, 1.0));
                }
                await state.addToShoppingList(recipes);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s('weekExported'))),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Table(
                    defaultColumnWidth: const FixedColumnWidth(118),
                    children: [
                      TableRow(
                        children: [
                          const SizedBox.shrink(),
                          for (final day in weekDays)
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                s(day),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                        ],
                      ),
                      for (final slot in mealSlots)
                        TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                s(slot),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ),
                            for (final day in weekDays)
                              _cell(state, s, p, plan, '$day.$slot'),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    AppState state,
    S s,
    InkPalette p,
    Map<String, String> plan,
    String slot,
  ) {
    final id = plan[slot];
    final recipe = id == null ? null : state.corpus.loadedRecipeById(id);
    return DragTarget<String>(
      onAcceptWithDetails: (details) => state.moveMeal(_key, details.data, slot),
      builder: (context, cand, rej) {
        return LongPressDraggable<String>(
          data: id,
          feedback: Material(
            color: p.card,
            child: SizedBox(
              width: 100,
              child: Text(recipe?.title.of(state.lang) ?? '', style: const TextStyle(fontSize: 12)),
            ),
          ),
          child: InkWell(
            onTap: () => _pick(state, s, slot, id),
            child: Container(
              height: 72,
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cand.isNotEmpty ? p.linenDeep : p.card,
                border: Border.all(color: p.line),
              ),
              child: Text(
                recipe?.title.of(state.lang) ?? s('planEmptySlot'),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: LedgerTheme.playfair,
                  fontSize: 12,
                  color: recipe == null ? p.walnutFaint : p.walnut,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pick(AppState state, S s, String slot, String? current) async {
    final saved = <Widget>[];
    for (final item in state.saved) {
      final r = await state.corpus.recipeById(item.recipeId);
      if (r == null) continue;
      saved.add(
        ListTile(
          title: Text(r.title.of(state.lang)),
          onTap: () {
            state.assignMeal(_key, slot, r.id);
            Navigator.pop(context);
          },
        ),
      );
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PlanPicker(
        saved: saved,
        current: current,
        weekKey: _key,
        slot: slot,
      ),
    );
  }
}

class _PlanPicker extends StatefulWidget {
  final List<Widget> saved;
  final String? current;
  final String weekKey;
  final String slot;

  const _PlanPicker({
    required this.saved,
    required this.current,
    required this.weekKey,
    required this.slot,
  });

  @override
  State<_PlanPicker> createState() => _PlanPickerState();
}

class _PlanPickerState extends State<_PlanPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final hits = _q.trim().isEmpty
        ? const <Recipe>[]
        : state.corpus.searchIndex
            .query(_q)
            .where((r) => state.matcher.isVisible(r, state.profile))
            .take(12)
            .toList();
    return PaperBackdrop(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s('pickRecipe'), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(hintText: s('searchHint')),
            onChanged: (v) async {
              if (v.trim().isNotEmpty) {
                await state.corpus.ensureAllLoaded();
              }
              if (mounted) setState(() => _q = v);
            },
          ),
          const SizedBox(height: 12),
          SectionLabel(s('fromCookbook')),
          if (widget.saved.isEmpty) Text(s('cookbookEmpty')) else ...widget.saved,
          if (hits.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionLabel(s('fromSearch')),
            for (final r in hits)
              ListTile(
                title: Text(r.title.of(state.lang)),
                onTap: () {
                  state.assignMeal(widget.weekKey, widget.slot, r.id);
                  Navigator.pop(context);
                },
              ),
          ],
          if (widget.current != null)
            TextButton(
              onPressed: () {
                state.clearMeal(widget.weekKey, widget.slot);
                Navigator.pop(context);
              },
              child: Text(s('removeFromSlot')),
            ),
        ],
      ),
    );
  }
}
