import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/models/local_state.dart';
import '../../domain/models/recipe.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({
    required this.mealPlan,
    required this.recipesById,
    required this.profile,
    required this.onPickRecipe,
    required this.onAssign,
    required this.onMove,
    required this.onRemove,
    required this.onExportWeek,
    super.key,
  });

  final MealPlan mealPlan;
  final Map<String, Recipe> recipesById;
  final UserProfile profile;
  final Future<Recipe?> Function(DateTime date, MealSlot slot) onPickRecipe;
  final Future<void> Function(DateTime date, MealSlot slot, Recipe recipe)
  onAssign;
  final Future<void> Function(
    MealPlanEntry source,
    DateTime date,
    MealSlot slot,
  )
  onMove;
  final Future<void> Function(DateTime date, MealSlot slot) onRemove;
  final Future<void> Function(List<Recipe> recipes) onExportWeek;

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen>
    with AutomaticKeepAliveClientMixin {
  late DateTime _monday = _startOfWeek(DateTime.now());
  bool _exporting = false;

  @override
  bool get wantKeepAlive => true;

  List<DateTime> get _days => [
    for (var offset = 0; offset < 7; offset++)
      _monday.add(Duration(days: offset)),
  ];

  void _changeWeek(int delta) {
    setState(() => _monday = _monday.add(Duration(days: delta * 7)));
  }

  Future<void> _pick(DateTime date, MealSlot slot) async {
    final recipe = await widget.onPickRecipe(date, slot);
    if (recipe != null) await widget.onAssign(date, slot, recipe);
  }

  Future<void> _export() async {
    if (_exporting) return;
    final recipes = widget.mealPlan
        .weekOf(_monday)
        .map((entry) => widget.recipesById[entry.recipeId])
        .whereType<Recipe>()
        .toList();
    if (recipes.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await widget.onExportWeek(recipes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings('plan.toShopping'))),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final weekEntries = widget.mealPlan.weekOf(_monday);
    return PaperSurface(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings('plan.title'),
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: () => _changeWeek(-1),
                        tooltip: context.strings('common.previousWeek'),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              _weekLabel(_monday, widget.profile.languageCode),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            TextButton(
                              onPressed: () => setState(
                                () => _monday = _startOfWeek(DateTime.now()),
                              ),
                              child: Text(context.strings('common.today')),
                            ),
                          ],
                        ),
                      ),
                      IconButton.outlined(
                        onPressed: () => _changeWeek(1),
                        tooltip: context.strings('common.nextWeek'),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final day in _days)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _DayColumn(
                            date: day,
                            profile: widget.profile,
                            entries: weekEntries,
                            recipesById: widget.recipesById,
                            onPick: _pick,
                            onMove: widget.onMove,
                            onRemove: widget.onRemove,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: InkButton(
                label: context.strings('plan.toShopping'),
                icon: Icons.shopping_basket_outlined,
                expand: true,
                onPressed: weekEntries.isEmpty || _exporting ? null : _export,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.profile,
    required this.entries,
    required this.recipesById,
    required this.onPick,
    required this.onMove,
    required this.onRemove,
  });

  final DateTime date;
  final UserProfile profile;
  final List<MealPlanEntry> entries;
  final Map<String, Recipe> recipesById;
  final Future<void> Function(DateTime, MealSlot) onPick;
  final Future<void> Function(MealPlanEntry, DateTime, MealSlot) onMove;
  final Future<void> Function(DateTime, MealSlot) onRemove;

  MealPlanEntry? _at(MealSlot slot) {
    for (final entry in entries) {
      if (_sameDay(entry.date, date) && entry.slot == slot) return entry;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final today = _sameDay(date, DateTime.now());
    return SizedBox(
      width: 154,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: today
                  ? context.morph.mustard.withValues(alpha: .36)
                  : context.morph.paperDeep.withValues(alpha: .55),
              border: Border.all(
                color: context.morph.ink.withValues(alpha: .35),
              ),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat.E(profile.languageCode).format(date).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          for (final slot in MealSlot.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 9, bottom: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.strings('plan.${slot.name}').toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            _MealSlotCard(
              date: date,
              slot: slot,
              entry: _at(slot),
              recipe: _at(slot) == null
                  ? null
                  : recipesById[_at(slot)!.recipeId],
              language: profile.languageCode,
              onTap: () => onPick(date, slot),
              onMove: (entry) => onMove(entry, date, slot),
              onRemove: () => onRemove(date, slot),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.date,
    required this.slot,
    required this.entry,
    required this.recipe,
    required this.language,
    required this.onTap,
    required this.onMove,
    required this.onRemove,
  });

  final DateTime date;
  final MealSlot slot;
  final MealPlanEntry? entry;
  final Recipe? recipe;
  final String language;
  final VoidCallback onTap;
  final ValueChanged<MealPlanEntry> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final cardHeight = (96 + (textScale.clamp(1, 2) - 1) * 60).toDouble();
    final card = DragTarget<MealPlanEntry>(
      onWillAcceptWithDetails: (details) => details.data != entry,
      onAcceptWithDetails: (details) => onMove(details.data),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: context.reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
          height: cardHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: highlighted
                ? context.morph.teal.withValues(alpha: .2)
                : context.morph.paper,
            border: Border.all(
              color: highlighted ? context.morph.teal : context.morph.inkMuted,
              width: highlighted ? 2 : 1,
            ),
          ),
          child: recipe == null
              ? InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          context.strings('plan.emptySlot'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                )
              : InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(9),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  recipe!.name.resolve(language),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              IconButton(
                                onPressed: () => _showRemove(context),
                                tooltip: context.strings('common.remove'),
                                visualDensity: VisualDensity.compact,
                                iconSize: 18,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          context.strings.format('common.recipeMinutes', {
                            'minutes': recipe!.timeMinutes,
                          }),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
    if (entry == null) return card;
    return LongPressDraggable<MealPlanEntry>(
      data: entry,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 154, child: Opacity(opacity: .9, child: card)),
      ),
      childWhenDragging: Opacity(opacity: .25, child: card),
      child: card,
    );
  }

  Future<void> _showRemove(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe!.name.resolve(language)),
        content: Text(context.strings('common.remove')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings('common.remove')),
          ),
        ],
      ),
    );
    if (remove == true) onRemove();
  }
}

DateTime _startOfWeek(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _weekLabel(DateTime monday, String language) {
  final sunday = monday.add(const Duration(days: 6));
  final month = DateFormat.MMM(language);
  if (monday.month == sunday.month) {
    return '${monday.day}–${sunday.day} ${month.format(monday)} ${sunday.year}';
  }
  return '${monday.day} ${month.format(monday)} – ${sunday.day} ${month.format(sunday)}';
}
