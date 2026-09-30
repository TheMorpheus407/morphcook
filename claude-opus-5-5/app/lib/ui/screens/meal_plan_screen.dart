import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/dates.dart';
import '../../i18n/strings.dart';
import '../../logic/calendar.dart';
import '../../logic/pagination.dart';
import '../../models/recipe.dart';
import '../../state/library_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';
import 'cookbook_screen.dart';
import 'search_screen.dart';

class _SlotRef {
  const _SlotRef(this.week, this.slot);
  final String week;
  final String slot;
}

/// Weekly grid (Mon–Sun × breakfast/lunch/dinner). Weekly pagination:
/// one week per page, at most four weeks rendered.
class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  late final PaginationController<IsoWeek> _weeks = PaginationController<IsoWeek>(
    config: PaginationConfig.mealPlan,
    fetcher: (token, n) => context.read<LibraryStore>().weekPage(token, n),
  );

  @override
  void initState() {
    super.initState();
    // start with this week and next
    _weeks.loadMore().then((_) => _weeks.loadMore());
    // make sure planned recipes can render even if their partition is lazy
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lib = context.read<LibraryStore>();
      context.read<CorpusRepository>().ensureRecipes(lib.plan.values.expand((w) => w.values));
    });
  }

  @override
  void dispose() {
    _weeks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: _weeks,
        builder: (context, _) {
          final weeks = _weeks.items;
          return ListView.builder(
            key: const Key('plan-list'),
            padding: const EdgeInsets.only(bottom: 40),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('plan.title'), style: MT.display(38)),
                      const SizedBox(height: 4),
                      HandNote(tr('plan.drag'), size: 19, color: MC.inkSoft),
                      if (_weeks.hasPrevious)
                        TextLink(tr('plan.earlier'), icon: Icons.expand_less, onTap: _weeks.loadPrevious),
                    ],
                  ),
                );
              }
              final idx = i - 1;
              if (idx < weeks.length) {
                return _WeekCard(week: weeks[idx]);
              }
              if (idx == weeks.length) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: PaperButton(
                      key: const Key('plan-later'),
                      label: tr('plan.later'),
                      icon: Icons.expand_more,
                      onPressed: _weeks.isLoading ? null : _weeks.loadMore,
                    ),
                  ),
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});
  final IsoWeek week;

  Future<void> _exportWeek(BuildContext context) async {
    final library = context.read<LibraryStore>();
    final repo = context.read<CorpusRepository>();
    final slots = library.week(week.key);
    await repo.ensureRecipes(slots.values);
    final items = <(Recipe, int, String?)>[];
    for (final e in slots.entries) {
      final r = repo.recipe(e.value);
      if (r != null) items.add((r, r.servings, '${week.key} · ${e.key}'));
    }
    if (items.isEmpty) return;
    await library.addManyToShopping(items);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.trRead('plan.added', {'n': items.length}))));
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final library = context.watch<LibraryStore>();
    final slots = library.week(week.key);
    final monday = week.monday;
    final isThisWeek = IsoWeek.of(DateTime.now()) == week;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: MC.card,
          border: Border.all(color: MC.rule),
          boxShadow: [BoxShadow(color: MC.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isThisWeek ? tr('plan.thisWeek') : tr('plan.week', {'w': week.week}), style: MT.display(22)),
                      MonoLabel(
                        '${week.key} · ${dayRange(monday, monday.add(const Duration(days: 6)), lang)}',
                        size: 10,
                      ),
                    ],
                  ),
                ),
                PaperButton(
                  key: Key('export-${week.key}'),
                  dense: true,
                  icon: Icons.checklist_rtl_outlined,
                  label: tr('plan.toList'),
                  onPressed: slots.isEmpty ? null : () => _exportWeek(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 44),
                for (final m in mealSlots) Expanded(child: Center(child: MonoLabel(tr('meal.$m'), size: 9.5))),
              ],
            ),
            const SizedBox(height: 4),
            for (var d = 0; d < 7; d++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('day.${weekdayKeys[d]}'), style: MT.display(16)),
                          Text('${monday.add(Duration(days: d)).day}', style: MT.mono(9)),
                        ],
                      ),
                    ),
                    for (final m in mealSlots)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _SlotCell(week: week, slot: slotKey(d, m), recipeId: slots[slotKey(d, m)]),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({required this.week, required this.slot, required this.recipeId});
  final IsoWeek week;
  final String slot;
  final String? recipeId;

  String _slotLabel(BuildContext context) {
    final tr = context.trRead;
    final p = slot.split('.');
    return '${tr('day.${p[0]}')} · ${tr('meal.${p[1]}')}';
  }

  Future<void> _pick(BuildContext context) async {
    final recipe = await showRecipePicker(context, title: context.trRead('plan.pick', {'slot': _slotLabel(context)}));
    if (recipe == null || !context.mounted) return;
    await context.read<LibraryStore>().assign(week.key, slot, recipe.id);
  }

  Future<void> _menu(BuildContext context, Recipe r) async {
    final tr = context.trRead;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(r.title.of(tr.lang).toLowerCase(), style: MT.display(24)),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(tr('plan.open'), style: MT.serif(16)),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(tr('plan.change'), style: MT.serif(16)),
              onTap: () => Navigator.pop(context, 'swap'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: Text(tr('plan.clear'), style: MT.serif(16)),
              onTap: () => Navigator.pop(context, 'clear'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'open':
        await openDish(context, r.dishId, recipeId: r.id);
      case 'swap':
        await _pick(context);
      case 'clear':
        await context.read<LibraryStore>().clearSlot(week.key, slot);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CorpusRepository>();
    final library = context.read<LibraryStore>();
    final recipe = recipeId == null ? null : repo.recipe(recipeId!);
    final dish = recipe == null ? null : repo.dishes[recipe.dishId];
    return DragTarget<_SlotRef>(
      onWillAcceptWithDetails: (d) => d.data.week != week.key || d.data.slot != slot,
      onAcceptWithDetails: (d) => library.moveSlot(d.data.week, d.data.slot, week.key, slot),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final Widget content;
        if (recipe == null || dish == null) {
          content = Semantics(
            button: true,
            label: context.tr('plan.pick', {'slot': _slotLabel(context)}),
            child: InkWell(
              key: Key('slot-${week.key}-$slot'),
              onTap: () => _pick(context),
              child: DashedBorderBox(
                color: hovering ? MC.coral : MC.rule,
                child: const SizedBox(
                  height: 52,
                  child: Center(child: Icon(Icons.add, size: 16, color: MC.inkFaint)),
                ),
              ),
            ),
          );
        } else {
          final tile = _FilledSlot(dish: dish, recipe: recipe, highlighted: hovering);
          content = LongPressDraggable<_SlotRef>(
            data: _SlotRef(week.key, slot),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 110,
                child: Transform.rotate(
                  angle: 0.05,
                  child: _FilledSlot(dish: dish, recipe: recipe, highlighted: true),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.3, child: tile),
            child: InkWell(key: Key('slot-${week.key}-$slot'), onTap: () => _menu(context, recipe), child: tile),
          );
        }
        return content;
      },
    );
  }
}

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({required this.dish, required this.recipe, required this.highlighted});
  final Dish dish;
  final Recipe recipe;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Color.lerp(dish.stripeColor, MC.card, 0.72),
        border: Border.all(color: highlighted ? MC.coral : Color.lerp(dish.stripeColor, MC.card, 0.3)!),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          recipe.title.of(context.lang).toLowerCase(),
          style: MT.display(12.5),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Bottom sheet: pick a recipe from the cookbook or from search.
Future<Recipe?> showRecipePicker(BuildContext context, {required String title}) {
  return showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, _) => _RecipePicker(title: title),
    ),
  );
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker({required this.title});
  final String title;

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  late int _tab = context.read<LibraryStore>().savedCount > 0 ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    void pick(Recipe r) => Navigator.of(context).pop(r);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(widget.title, style: MT.display(24)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              InkChip(label: tr('plan.fromCookbook'), selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              InkChip(
                key: const Key('picker-search'),
                label: tr('plan.fromSearch'),
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _tab == 0 ? SavedRecipesList(onPick: pick) : RecipeSearchView(onPick: pick),
        ),
      ],
    );
  }
}
