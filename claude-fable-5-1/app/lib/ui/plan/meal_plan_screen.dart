import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/week.dart';
import '../../data/models/meal_plan.dart';
import '../../data/models/recipe.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../shell/app_shell.dart';
import '../widgets/meta.dart';
import 'slot_picker.dart';

/// Payload for dragging a planned meal between slots.
class MealDragData {
  const MealDragData(this.weekKey, this.slot);
  final String weekKey;
  final String slot;
}

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  /// Offset in weeks from the current week: -1 … +2.
  int _offset = 0;
  static const _minOffset = -1;
  static const _maxOffset = 2;

  /// Recipes we asked the repository to load on demand.
  final Set<String> _requested = {};

  String get _weekKey =>
      shiftWeekKey(context.read<AppController>().currentWeekKey, _offset);

  void _ensureLoaded(AppController app, String recipeId) {
    if (app.recipeIfLoaded(recipeId) != null || !_requested.add(recipeId)) {
      return;
    }
    app.recipe(recipeId).then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _assign(String weekKey, String slot) async {
    final app = context.read<AppController>();
    final id = await pickRecipeForSlot(context);
    if (id == null) return;
    await app.assignMeal(weekKey, slot, id);
  }

  Future<void> _showFilledSheet(
    String weekKey,
    String slot,
    Recipe recipe,
  ) async {
    final s = context.s;
    final app = context.read<AppController>();
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: Text(
                recipe.title.of(context.lang),
                style: AppText.display(size: 24),
              ),
            ),
            const DashedRule(padding: EdgeInsets.symmetric(horizontal: 22)),
            ListTile(
              leading: const Icon(Icons.auto_stories_outlined),
              title: Text(
                recipe.title.of(context.lang),
                style: AppText.body(size: 15),
              ),
              subtitle: MonoLabel(
                app.dish(recipe.dishId)?.name.of(context.lang) ?? '',
              ),
              onTap: () => Navigator.of(ctx).pop('open'),
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(s('plan.pick.title'), style: AppText.body(size: 15)),
              onTap: () => Navigator.of(ctx).pop('replace'),
            ),
            ListTile(
              leading: const Icon(Icons.clear),
              title: Text(s('plan.clearSlot'), style: AppText.body(size: 15)),
              onTap: () => Navigator.of(ctx).pop('clear'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await Routes.openDish(context, recipe.dishId, recipeId: recipe.id);
      case 'replace':
        await _assign(weekKey, slot);
      case 'clear':
        await app.clearMeal(weekKey, slot);
    }
  }

  Future<void> _export() async {
    final app = context.read<AppController>();
    final s = context.s;
    final messenger = ScaffoldMessenger.of(context);
    final tabs = ShellTabs.maybeOf(context);
    final n = await app.exportWeekToShopping(_weekKey);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    if (n == 0) {
      messenger.showSnackBar(SnackBar(content: Text(s('plan.exportNothing'))));
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(s('plan.exported', {'n': '$n'})),
        action: SnackBarAction(
          label: s('nav.list'),
          onPressed: () => tabs?.select(ShellTabs.list),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final weekKey = _weekKey;
    final monday = mondayOfWeekKey(weekKey);
    final isCurrent = _offset == 0;
    final atEdge = _offset == _minOffset || _offset == _maxOffset;
    final week = app.mealPlan.week(weekKey);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          SectionHeader(
            title: s('plan.title'),
            kicker: s('plan.kicker'),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _offset > _minOffset
                      ? () => setState(() => _offset--)
                      : null,
                  tooltip: s('common.back'),
                ),
                Expanded(
                  child: Column(
                    children: [
                      MonoLabel(
                        s('plan.weekOf', {'date': s.shortDate(monday)}),
                        color: Palette.ink,
                        align: TextAlign.center,
                      ),
                      if (isCurrent)
                        MonoLabel(s('plan.thisWeek'), align: TextAlign.center),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _offset < _maxOffset
                      ? () => setState(() => _offset++)
                      : null,
                  tooltip: s('common.next'),
                ),
              ],
            ),
          ),
          if (atEdge)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: HandNote(
                s('plan.limit'),
                color: Palette.inkFaint,
                size: 17,
                align: TextAlign.center,
              ),
            ),
          const DashedRule(padding: EdgeInsets.fromLTRB(20, 8, 20, 4)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              children: [
                const SizedBox(width: 44),
                for (final meal in mealsOfDay)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 6,
                      ),
                      child: MonoLabel(
                        s('plan.meal.$meal'),
                        align: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (var d = 1; d <= 7; d++)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              // IntrinsicHeight bounds the stretched row inside the scroll view.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoLabel(
                            s.weekday(d, short: true),
                            color: Palette.ink,
                          ),
                          MonoLabel(
                            '${monday.add(Duration(days: d - 1)).day}.',
                          ),
                        ],
                      ),
                    ),
                    for (final meal in mealsOfDay)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _SlotTile(
                            weekKey: weekKey,
                            slot: slotKey(d, meal),
                            recipeId: week[slotKey(d, meal)],
                            ensureLoaded: (id) => _ensureLoaded(app, id),
                            onTapEmpty: () =>
                                _assign(weekKey, slotKey(d, meal)),
                            onTapFilled: (r) =>
                                _showFilledSheet(weekKey, slotKey(d, meal), r),
                            onDrop: (from) => app.moveMeal(
                              from.weekKey,
                              from.slot,
                              weekKey,
                              slotKey(d, meal),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            child: HandNote(
              s('plan.dragHint'),
              color: Palette.inkFaint,
              size: 17,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: PaperButton(
              label: s('plan.export'),
              icon: Icons.shopping_basket_outlined,
              expand: true,
              onPressed: _export,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  const _SlotTile({
    required this.weekKey,
    required this.slot,
    required this.recipeId,
    required this.ensureLoaded,
    required this.onTapEmpty,
    required this.onTapFilled,
    required this.onDrop,
  });

  final String weekKey;
  final String slot;
  final String? recipeId;
  final void Function(String) ensureLoaded;
  final VoidCallback onTapEmpty;
  final void Function(Recipe) onTapFilled;
  final void Function(MealDragData) onDrop;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final id = recipeId;
    Recipe? recipe;
    if (id != null) {
      recipe = app.recipeIfLoaded(id);
      if (recipe == null) ensureLoaded(id);
    }
    return DragTarget<MealDragData>(
      onWillAcceptWithDetails: (d) =>
          !(d.data.weekKey == weekKey && d.data.slot == slot),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        final Widget body;
        if (id == null) {
          body = _EmptySlot(hovering: hovering, onTap: onTapEmpty);
        } else if (recipe == null) {
          body = const SizedBox(
            height: 82,
            child: Center(child: SkeletonBox(height: 60, width: 60)),
          );
        } else {
          final r = recipe;
          final card = _MiniCard(recipe: r, hovering: hovering);
          final reduced = Motion.reduced(context);
          body = LongPressDraggable<MealDragData>(
            data: MealDragData(weekKey, slot),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 100,
                child: Transform.rotate(
                  angle: reduced ? 0 : -0.04,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Palette.paperShadow,
                          offset: Offset(2, 5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: _MiniCard(recipe: r, hovering: false),
                  ),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: card),
            child: GestureDetector(onTap: () => onTapFilled(r), child: card),
          );
        }
        return AnimatedContainer(
          duration: Motion.duration(context, const Duration(milliseconds: 140)),
          decoration: BoxDecoration(
            color: hovering
                ? Palette.mustard.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: body,
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.hovering, required this.onTap});
  final bool hovering;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 82,
        decoration: BoxDecoration(
          border: Border.all(color: hovering ? Palette.mustard : Palette.rule),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: MonoLabel(
              s('plan.emptySlot'),
              size: 9.5,
              align: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.recipe, required this.hovering});
  final Recipe recipe;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = context.lang;
    final dish = app.dish(recipe.dishId);
    final meta = RecipeMeta(app, lang);
    final color = Color(dish?.stripeColor ?? 0xFFC9A27E);
    return Container(
      height: 82,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Palette.paperLight,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: hovering
              ? Palette.mustard
              : Palette.ink.withValues(alpha: 0.12),
        ),
        boxShadow: const [
          BoxShadow(
            color: Palette.paperShadow,
            offset: Offset(1, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 22,
            width: double.infinity,
            child: StripedPlaceholder(
              color: color,
              seed: recipe.id.hashCode,
              aspectRatio: 4,
              dense: true,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              recipe.title.of(lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(size: 12.5).copyWith(height: 1.15),
            ),
          ),
          Text(
            '${meta.time(recipe)} · ${meta.kcal(recipe)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.mono(color: Palette.inkFaint, size: 8.5),
          ),
        ],
      ),
    );
  }
}
