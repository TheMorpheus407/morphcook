import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../logic/calendar.dart';
import '../models/models.dart';
import 'dish_detail.dart';
import 'widgets.dart';

const _calendarMonthsEn = [
  'jan', 'feb', 'mar', 'apr', 'may', 'jun',
  'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
];
const _calendarMonthsDe = [
  'jan', 'feb', 'mär', 'apr', 'mai', 'jun',
  'jul', 'aug', 'sep', 'okt', 'nov', 'dez',
];

String _dishName(Dish dish, String lang) =>
    dish.canonicalName[lang]?.toString() ??
    dish.canonicalName['en']?.toString() ??
    dish.id;

String _recipeTitle(Recipe recipe, String lang) =>
    recipe.title[lang]?.toString() ??
    recipe.title['en']?.toString() ??
    recipe.id;

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  CalendarWeek _week = CalendarWeek.of(DateTime.now());
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadStarted) return;
    _loadStarted = true;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final svc = Services.of(context);
    await svc.corpus.ensureAllLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return ListenableBuilder(
      listenable: svc.state,
      builder: (context, _) {
        final slots = svc.state.week(_week.key);
        final distinct = _orderedDistinct(slots);
        final shared = _sharedCount(slots);
        return SingleChildScrollView(
          child: Center(
            child: ZinePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _navRow(context, lang, t),
                  const SizedBox(height: 12),
                  _weekGrid(context, svc, slots, lang, t),
                  if (shared > 0) _sharedNote(context, shared, t),
                  const SizedBox(height: 12),
                  _summary(context, svc, slots, distinct, t),
                  if (distinct.isNotEmpty) ...[
                    SectionHeader(title: t(L10n.tWeekAlbum), kicker: 'album'),
                    _weekAlbum(context, svc, distinct, lang),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- week nav -------------------------------------------------------------

  Widget _navRow(BuildContext context, String lang, String Function(String) t) {
    final start = _week.start;
    final end = start.add(const Duration(days: 6));
    final months = lang == 'de' ? _calendarMonthsDe : _calendarMonthsEn;
    final dateRange = start.month == end.month
        ? '${start.day.toString().padLeft(2, '0')}'
            '–${end.day.toString().padLeft(2, '0')}'
            ' ${months[start.month - 1]} ${start.year}'
        : '${start.day.toString().padLeft(2, '0')} ${months[start.month - 1]}'
            ' – ${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]}'
            ' ${end.year}';
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() => _week = _week.previous),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.chevron_left),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                t(L10n.tThisWeek).toUpperCase(),
                style: AppText.mono(context, size: 9, color: AppColors.accent)
                    .copyWith(letterSpacing: 1.4),
              ),
              const SizedBox(height: 2),
              Text(
                t(L10n.tWeek).replaceFirst('{w}', '${_week.weekNumber}'),
                style: AppText.serif(context, size: 18, weight: FontWeight.w700),
              ),
              Text(dateRange,
                  style: AppText.mono(context,
                      size: 9, color: AppColors.inkSoft)),
            ],
          ),
        ),
        InkWell(
          onTap: () => setState(() => _week = _week.next),
          child: const Padding(
            padding: EdgeInsets.all(6),
            child: Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }

  // --- grid ------------------------------------------------------------------

  Widget _weekGrid(BuildContext context, Services svc,
      Map<String, String> slots, String lang, String Function(String) t) {
    return Table(
      border: TableBorder.all(color: AppColors.lineDotted, width: 0.6),
      columnWidths: const {
        0: FixedColumnWidth(58),
      },
      defaultColumnWidth: const FlexColumnWidth(),
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (final d in dayNames) _dayHeader(context, lang, d),
          ],
        ),
        for (final m in mealNames)
          TableRow(
            children: [
              _mealHeader(context, lang, m),
              for (final d in dayNames)
                _dayCell(context, svc, slots, slotKey(d, m), lang, t),
            ],
          ),
      ],
    );
  }

  Widget _dayHeader(BuildContext context, String lang, String day) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        dayLabel(lang, day).toUpperCase(),
        textAlign: TextAlign.center,
        style: AppText.mono(context, size: 9, color: AppColors.accent)
            .copyWith(letterSpacing: 0.5, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _mealHeader(BuildContext context, String lang, String meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        mealLabel(lang, meal).toUpperCase(),
        textAlign: TextAlign.center,
        style: AppText.mono(context, size: 8, color: AppColors.inkFaint),
      ),
    );
  }

  Widget _dayCell(BuildContext context, Services svc,
      Map<String, String> slots, String slot, String lang,
      String Function(String) t) {
    final rid = slots[slot];
    final recipe = rid == null ? null : svc.corpus.recipeById(rid);
    return GestureDetector(
      onTap:
          recipe == null ? () => _showPicker(context, svc, slot, lang, t) : null,
      onLongPress: recipe == null
          ? null
          : () => _showSlotSheet(context, svc, slot, recipe, lang, t),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.lineDotted, width: 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _slotBody(context, recipe, lang),
      ),
    );
  }

  Widget _slotBody(BuildContext context, Recipe? recipe, String lang) {
    if (recipe == null) {
      return Center(
        child: Text('+',
            style: AppText.mono(context, size: 13, color: AppColors.inkFaint)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Center(
        child: Text(
          _recipeTitle(recipe, lang).toUpperCase(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: AppText.mono(context, size: 8, color: AppColors.ink)
              .copyWith(height: 1.25, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _sheetLabelRow(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: AppText.mono(context, size: 9, color: AppColors.accent)
            .copyWith(letterSpacing: 1.4),
      ),
    );
  }

  Widget _pickRow(BuildContext context, int index, String title, String sub,
      VoidCallback onTap) {
    return Material(
      color: AppColors.zebraB[index % AppColors.zebraB.length],
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.serif(context, size: 15)),
                    if (sub.isNotEmpty)
                      Text(sub,
                          style: AppText.mono(context,
                              size: 9, color: AppColors.inkFaint)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.add_box_outlined, size: 16, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }

  Recipe? _firstVisible(Dish dish, Services svc) {
    for (final r in svc.corpus.recipesForDish(dish.id)) {
      if (svc.matcher.visible(r, svc.state.profile)) return r;
    }
    return null;
  }

  String _variantLine(Recipe recipe, String lang) {
    String t(String k) => L10n.strings(lang, k);
    return '${recipe.diet} · ${recipe.calories} kcal · '
        '${recipe.timeMinutes} ${t(L10n.tMinutes).toLowerCase()}';
  }

  // --- slot actions -----------------------------------------------------------

  Future<void> _showSlotSheet(BuildContext context, Services svc,
      String slot, Recipe recipe, String lang, String Function(String) t) async {
    final dish = svc.corpus.dishById(recipe.dishId);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.paperBright,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(_recipeTitle(recipe, lang),
                  style: AppText.serif(context, size: 16)),
            ),
            ListTile(
              title: Text(t(L10n.tViewRecipe),
                  style: AppText.mono(context, size: 12)),
              leading: const Icon(Icons.restaurant_menu, size: 18),
              onTap: () {
                Navigator.pop(ctx);
                if (dish == null) return;
                _open(context, dish, recipe);
              },
            ),
            ListTile(
              title: Text(t(L10n.tClearSlot),
                  style: AppText.mono(context, size: 12)),
              leading: const Icon(Icons.delete_outline, size: 18),
              onTap: () {
                svc.state.setSlot(_week.key, slot, null);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(
      BuildContext context, Services svc, String slot, String lang,
      String Function(String) t) async {
    final saved = svc.state.savedEntries;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperBright,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        var zebra = 0;
        final rows = <Widget>[];
        if (saved.isNotEmpty) {
          rows.add(_sheetLabelRow(ctx, t(L10n.tFromCookbookMine)));
          for (final e in saved) {
            final recipe = svc.corpus.recipeById(e.recipeId);
            if (recipe == null) continue;
            rows.add(_pickRow(ctx, zebra++, _recipeTitle(recipe, lang),
                '${t(L10n.tSaved)} · ${_variantLine(recipe, lang)}', () {
              svc.state.setSlot(_week.key, slot, e.recipeId);
              Navigator.pop(ctx);
            }));
          }
          rows.add(const Divider(
              height: 22, thickness: 4, color: AppColors.paperDark));
        }
rows.add(_sheetLabelRow(ctx, t(L10n.tBrowseAll)));
        for (final dish in svc.corpus.dishesAll) {
          final recipe = _firstVisible(dish, svc);
          if (recipe == null) continue;
          rows.add(_pickRow(ctx, zebra++, _dishName(dish, lang),
              _variantLine(recipe, lang), () {
            svc.state.setSlot(_week.key, slot, recipe.id);
            Navigator.pop(ctx);
          }));
        }
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(t(L10n.tAssign),
                            style: AppText.serif(
                                context, size: 18, weight: FontWeight.w700)),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                ),
                Expanded(child: ListView(children: rows)),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- share / summary / album --------------------------------------------------

  int _sharedCount(Map<String, String> slots) {
    final counts = <String, int>{};
    for (final rid in slots.values) {
      if (rid.isEmpty) continue;
      counts[rid] = (counts[rid] ?? 0) + 1;
    }
    return counts.values.where((c) => c > 1).length;
  }

  List<String> _orderedDistinct(Map<String, String> slots) {
    final out = <String>[];
    for (final d in dayNames) {
      for (final m in mealNames) {
        final rid = slots[slotKey(d, m)];
        if (rid == null || rid.isEmpty) continue;
        if (!out.contains(rid)) out.add(rid);
      }
    }
    return out;
  }

  int _filledCount(List<String> distinct, Map<String, String> slots) {
    var n = 0;
    for (final rid in distinct) {
      for (final k in slots.keys) {
        if (slots[k] == rid) n++;
      }
    }
    return n;
  }

  Widget _sharedNote(BuildContext context, int n, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Icon(Icons.compare_arrows, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              t(L10n.tSharedServingsNote).replaceFirst('{n}', '$n'),
              style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, Services svc,
      Map<String, String> slots, List<String> distinct,
      String Function(String) t) {
    final filled = _filledCount(distinct, slots);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            PressChip(label: '$filled ${t(L10n.tSlotsFilled)}'),
            PressChip(
                label: '${distinct.length} ${t(L10n.tRecipes)}',
                color: AppColors.inkSoft),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed:
              filled == 0 ? null : () => _exportWeek(context, svc, slots, t),
          icon: const Icon(Icons.shopping_cart_outlined, size: 16),
          label: Text(t(L10n.tExportWeek),
              style: AppText.mono(context, size: 11)),
        ),
      ],
    );
  }

  void _exportWeek(
      BuildContext context, Services svc, Map<String, String> slots,
      String Function(String) t) {
    final counts = <String, int>{};
    for (final rid in slots.values) {
      if (rid.isEmpty) continue;
      counts[rid] = (counts[rid] ?? 0) + 1;
    }
    counts.forEach((rid, count) {
      final recipe = svc.corpus.recipeById(rid);
      final base = math.max(2, recipe?.servings ?? 2);
      svc.state.addShoppingLine(rid, servings: base * count);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          t(L10n.tWeekExported).replaceFirst('{n}', '${counts.length}')),
    ));
  }

  Widget _weekAlbum(
      BuildContext context, Services svc, List<String> distinct, String lang) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final rid in distinct.take(7))
            _albumCard(context, svc, rid, lang),
        ],
      ),
    );
  }

  Widget _albumCard(BuildContext context, Services svc, String rid, String lang) {
    final recipe = svc.corpus.recipeById(rid);
    if (recipe == null) return const SizedBox.shrink();
    final dish = svc.corpus.dishById(recipe.dishId);
    if (dish == null) return const SizedBox.shrink();
    return PolaroidCard(
      dish: dish,
      caption: _dishName(dish, lang),
      width: 84,
      onTap: () => _open(context, dish, recipe),
    );
  }

  void _open(BuildContext context, Dish dish, Recipe recipe) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DishDetailPage(dish: dish, initialRecipe: recipe),
      ),
    );
  }
}