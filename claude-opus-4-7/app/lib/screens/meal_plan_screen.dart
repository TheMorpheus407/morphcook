import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../data/corpus.dart';
import '../data/cookbook_store.dart';
import '../data/meal_plan_store.dart';
import '../data/shopping_list_store.dart';
import '../l10n/strings.dart';
import '../models/dish.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/ink_button.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key});
  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  DateTime _weekStart = startOfIsoWeek(DateTime.now());

  String get _weekKey => isoWeekKey(_weekStart);

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final lang = l.lang;
    final store = context.watch<MealPlanStore>();
    final corpus = context.watch<Corpus>();
    final week = store.week(_weekKey);

    final days = const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayLabels = days.map((d) => l.t('plan.$d')).toList();
    final formatter = DateFormat('d MMM', lang);

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Masthead(
                title: 'week',
                edition: l.t('plan.title'),
                leftMeta: _weekKey,
                rightMeta:
                    '${formatter.format(_weekStart)} — ${formatter.format(_weekStart.add(const Duration(days: 6)))}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() {
                              _weekStart = _weekStart
                                  .subtract(const Duration(days: 7));
                            })),
                    const Spacer(),
                    Text(_weekKey, style: MorphType.smallCaps()),
                    const Spacer(),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() {
                              _weekStart = _weekStart
                                  .add(const Duration(days: 7));
                            })),
                  ],
                ),
              ),
              const DashedRule(),
              Expanded(
                child: ListView.builder(
                  itemCount: 7,
                  itemBuilder: (ctx, di) {
                    final dayKey = days[di];
                    final date = _weekStart.add(Duration(days: di));
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(dayLabels[di].toUpperCase(),
                                  style: MorphType.smallCaps()),
                              const SizedBox(width: 8),
                              Text(formatter.format(date),
                                  style: MorphType.body(
                                      size: 12,
                                      color: MorphColors.inkMuted)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          for (final slot in MealSlot.values)
                            _Slot(
                              weekKey: _weekKey,
                              slotKey: '$dayKey.${slot.name}',
                              slotLabel: l.t('plan.${slot.name}'),
                              entry: week['$dayKey.${slot.name}'],
                              lang: lang,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const DashedRule(),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    InkButton(
                      label: l.t('plan.add.shop'),
                      icon: Icons.add_shopping_cart,
                      onPressed: store.entriesForWeek(_weekKey).isEmpty
                          ? null
                          : () async {
                              final entries =
                                  store.entriesForWeek(_weekKey);
                              final recipes = <Recipe>[];
                              final servingsByRecipe = <String, int>{};
                              for (final e in entries) {
                                final r = corpus.recipesById[e.recipeId];
                                if (r != null) {
                                  recipes.add(r);
                                  servingsByRecipe[r.id] = e.servings;
                                }
                              }
                              final n = await context
                                  .read<ShoppingListStore>()
                                  .addRecipes(recipes,
                                      servingsByRecipe: servingsByRecipe);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '+$n ingredients to shopping list')));
                            },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  final String weekKey;
  final String slotKey;
  final String slotLabel;
  final MealPlanEntry? entry;
  final String lang;
  const _Slot({
    required this.weekKey,
    required this.slotKey,
    required this.slotLabel,
    required this.entry,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final Recipe? recipe = entry == null
        ? null
        : corpus.recipesById[entry!.recipeId];
    final Dish? dish = recipe == null ? null : corpus.dishesById[recipe.dishId];
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) async {
        final store = context.read<MealPlanStore>();
        await store.moveSlot(weekKey, details.data.slotKey, slotKey);
      },
      builder: (ctx, _, __) {
        final tile = InkWell(
          onTap: () => _pickRecipe(context),
          onLongPress: entry == null
              ? null
              : () =>
                  context.read<MealPlanStore>().setSlot(weekKey, slotKey, null),
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: MorphColors.inkFaint),
              color: MorphColors.paper,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(slotLabel.toUpperCase(),
                      style: MorphType.smallCaps(size: 10)),
                ),
                Expanded(
                  child: recipe == null
                      ? Text('— ${L10n(lang).t('plan.empty')} —',
                          style: MorphType.body(
                              size: 13, color: MorphColors.inkMuted))
                      : Text(
                          recipe.name.get(lang).toLowerCase(),
                          style: MorphType.headline(size: 17),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                if (dish != null)
                  Container(
                    width: 14,
                    height: 14,
                    color: MorphColors.parseHex(dish.stripeColor),
                  ),
              ],
            ),
          ),
        );
        if (entry == null) return tile;
        return LongPressDraggable<_DragPayload>(
          data: _DragPayload(slotKey: slotKey),
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.85, child: SizedBox(width: 240, child: tile)),
          ),
          child: tile,
        );
      },
    );
  }

  Future<void> _pickRecipe(BuildContext context) async {
    final corpus = context.read<Corpus>();
    final cookbook = context.read<CookbookStore>();
    final l = L10n.read(context);
    final source = cookbook.savedRecipeIds.isNotEmpty
        ? cookbook.savedRecipeIds
            .map((id) => corpus.recipesById[id])
            .whereType<Recipe>()
            .toList()
        : corpus.recipes;

    final r = await showModalBottomSheet<Recipe>(
      context: context,
      backgroundColor: MorphColors.paper,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('— ${l.t('cookbook.title').toUpperCase()} —',
                  style: MorphType.smallCaps()),
            ),
            for (final rec in source)
              ListTile(
                title: Text(rec.name.get(l.lang)),
                subtitle: Text(
                    '${rec.variantTag.get(l.lang)} · ${rec.timeMinutes} min'),
                onTap: () => Navigator.of(context).pop(rec),
              ),
            if (entry != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l.t('app.delete')),
                onTap: () => Navigator.of(context).pop(null),
              ),
          ],
        ),
      ),
    );
    final store = context.read<MealPlanStore>();
    if (r != null) {
      await store.setSlot(
          weekKey, slotKey, MealPlanEntry(recipeId: r.id, servings: r.servings));
    }
  }
}

class _DragPayload {
  final String slotKey;
  const _DragPayload({required this.slotKey});
}
