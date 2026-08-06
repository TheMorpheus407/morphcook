import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../logic/shopping.dart';
import '../models/models.dart';
import 'widgets.dart';

String _recipeTitle(Recipe recipe, String lang) =>
    recipe.title[lang]?.toString() ??
    recipe.title['en']?.toString() ??
    recipe.id;

class ShoppingTab extends StatefulWidget {
  const ShoppingTab({super.key});

  @override
  State<ShoppingTab> createState() => _ShoppingTabState();
}

class _ShoppingTabState extends State<ShoppingTab> {
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
        final lines = svc.state.shoppingLines;
        final items = ShoppingAggregator(svc.corpus).build(lines, lang);
        final groups = <String, List<ShoppingItem>>{};
        for (final item in items) {
          groups.putIfAbsent(item.aisle, () => []).add(item);
        }
        return SingleChildScrollView(
          child: Center(
            child: ZinePage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context, svc, t),
                  if (lines.isEmpty)
                    _empty(context, t)
                  else ...[
                    for (final group in groups.entries) ...[
                      SectionHeader(
                          title: svc.corpus.labelOf(group.key, lang)),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Column(
                          children: [
                            for (var i = 0; i < group.value.length; i++)
                              _itemRow(
                                  context, svc, group.value[i], i, lang, t),
                          ],
                        ),
                      ),
                    ],
                    SectionHeader(title: t(L10n.tRecipeSources)),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        children: [
                          for (var i = 0; i < lines.length; i++)
                            _sourceRow(context, svc, lines[i], i, lang),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Services svc, String Function(String) t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: () => _addRecipes(context, svc, t),
          icon: const Icon(Icons.add_shopping_cart_outlined, size: 16),
          label: Text(t(L10n.tAddRecipes),
              style: AppText.mono(context, size: 10)),
        ),
        TextButton(
          onPressed: () => svc.state.clearCheckedShopping(),
          child: Text(t(L10n.tClearChecked),
              style: AppText.mono(context, size: 10)),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: [
          Text(
            t(L10n.tShopEmpty),
            textAlign: TextAlign.center,
            style: AppText.mono(context, size: 11, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            t(L10n.tShoppingHint),
            textAlign: TextAlign.center,
            style: AppText.mono(context, size: 9, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(BuildContext context, Services svc, ShoppingItem item, int i,
      String lang, String Function(String) t) {
    final checked = svc.state.checkedShopping.contains(item.ingredientId);
    return ZebraRow(
      index: i,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => svc.state.toggleShoppingChecked(item.ingredientId),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: checked ? AppColors.success : AppColors.inkFaint,
                  width: 1.5,
                ),
                color: checked ? AppColors.success : Colors.transparent,
              ),
              child: checked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  svc.corpus.labelOf(item.ingredientId, lang),
                  style: AppText.serif(context, size: 16).copyWith(
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: checked ? AppColors.inkFaint : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _amountLine(item, lang),
                  style: AppText.mono(context,
                      size: 10,
                      color: checked ? AppColors.inkFaint : AppColors.inkSoft),
                ),
              ],
            ),
          ),
          if (item.sourceCount > 1)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('×${item.sourceCount}',
                  style: AppText.mono(context,
                      size: 9, color: AppColors.inkFaint)),
            ),
        ],
      ),
    );
  }

  String _amountLine(ShoppingItem item, String lang) {
    final unit = UnitConverter.isCountUnit(item.unit)
        ? UnitConverter.countLabel(item.unit, lang)
        : item.unit;
    return '${_fmt(item.amount)} $unit';
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    var s = v.toString();
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }

  Widget _sourceRow(
      BuildContext context, Services svc, ShoppingLine line, int i,
      String lang) {
    final recipe = svc.corpus.recipeById(line.recipeId);
    final name = recipe == null ? line.recipeId : _recipeTitle(recipe, lang);
    final servings =
        line.servings ?? (recipe == null ? 1 : recipe.servings);
    return ZebraRow(
      index: i,
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: AppText.serif(context, size: 15)),
          ),
          const SizedBox(width: 8),
          Text(
              '$servings ${L10n.strings(lang, L10n.tServingsScale)}',
              style: AppText.mono(context, size: 10, color: AppColors.inkSoft)),
          IconButton(
            onPressed: () {
              if (servings <= 1) {
                svc.state.removeShoppingLine(line.recipeId);
              } else {
                svc.state.updateShoppingServings(
                    line.recipeId, servings - 1);
              }
            },
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            color: AppColors.error,
          ),
          TextButton(
            onPressed: () => svc.state
                .updateShoppingServings(line.recipeId, servings + 1),
            child: const Icon(Icons.add_circle_outline, size: 18),
          ),
        ],
      ),
    );
  }

  Future<void> _addRecipes(
      BuildContext context, Services svc, String Function(String) t) async {
    final lang = svc.state.lang;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paperBright,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (ctx) {
        var zebra = 0;
        final rows = <Widget>[];
        for (final dish in svc.corpus.dishesAll) {
          final recipe = _firstVisible(dish, svc);
          if (recipe == null) continue;
          rows.add(_pickRow(ctx, zebra++, _dishName(dish, lang),
              _variantLine(recipe, lang), () {
            svc.state.addShoppingLine(recipe.id);
            Navigator.pop(ctx);
          }));
        }
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(t(L10n.tAddRecipes),
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

  String _dishName(Dish dish, String lang) =>
      dish.canonicalName[lang]?.toString() ??
      dish.canonicalName['en']?.toString() ??
      dish.id;

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
              const Icon(Icons.add_shopping_cart_outlined,
                  size: 16, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}