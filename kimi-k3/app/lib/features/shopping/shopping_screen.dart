import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/engine/shopping.dart';
import '../../core/l10n.dart';
import '../../core/models/local_text.dart';
import '../../core/models/recipe.dart';
import '../../core/storage/local_store.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';

/// Aisle display order; unknown aisles are appended after these.
const _aisleOrder = [
  'produce',
  'protein',
  'dairy',
  'pantry',
  'spices',
  'bakery',
  'frozen',
];

/// Amount display: integers without decimals, otherwise one decimal.
String formatAmount(double amount) {
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toStringAsFixed(1);
}

/// Profile override for reduced motion, falling back to the system setting.
bool reduceMotionOf(BuildContext context) {
  final override = context.read<ProfileStore>().profile.reduceMotion;
  return override ?? MediaQuery.of(context).disableAnimations;
}

/// The shopping list: aggregated ingredients of all list recipes, grouped
/// by aisle, with check-off state persisted in [LocalStore].
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  List<ShoppingItem> _items = const [];
  List<Recipe> _recipes = const [];
  bool _loading = true;
  String _loadedSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final corpus = context.read<CorpusRepository>();
    final store = context.read<LocalStore>();
    setState(() => _loading = true);
    await corpus.ensureAllLoaded();
    if (!mounted) return;
    final ids = store.shoppingRecipes;
    final recipes = ids.map(corpus.recipeById).whereType<Recipe>().toList();
    final items = ShoppingAggregator().aggregate(recipes);
    setState(() {
      _recipes = recipes;
      _items = items;
      _loading = false;
      _loadedSignature = ids.join('|');
    });
  }

  String _aisleLabel(AppStrings s, String aisle) {
    final key = 'shopping.aisle.$aisle';
    final value = s.t(key);
    return value == key ? aisle : value;
  }

  Map<String, List<ShoppingItem>> _groupByAisle(Set<String> checked) {
    final groups = <String, List<ShoppingItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.aisle, () => []).add(item);
    }
    // Checked lines sink to the end of their aisle group.
    for (final list in groups.values) {
      list.sort((a, b) {
        final ca = checked.contains('${a.ingredientId}|${a.unit}') ? 1 : 0;
        final cb = checked.contains('${b.ingredientId}|${b.unit}') ? 1 : 0;
        return ca - cb;
      });
    }
    return groups;
  }

  Future<void> _confirmClearAll(AppStrings s) async {
    final store = context.read<LocalStore>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.paper,
        title: Text(
          s.t('shopping.clearAll'),
          style: AppText.headline(size: 20),
        ),
        content: Text(
          s.t('shopping.clearAll.confirm'),
          style: AppText.body(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              s.t('common.cancel'),
              style: AppText.monoLabel(size: 11),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              s.t('common.delete'),
              style: AppText.monoLabel(size: 11, color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) await store.clearShoppingList();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final lang = context.watch<ProfileStore>().profile.lang;
    final store = context.watch<LocalStore>();
    final reduceMotion = reduceMotionOf(context);

    // Reload when the source-recipe set changes (e.g. a chip was removed).
    final signature = store.shoppingRecipes.join('|');
    if (!_loading && signature != _loadedSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
    }

    final checked = store.shoppingChecked;
    final groups = _groupByAisle(checked);
    final orderedAisles = [
      ..._aisleOrder.where(groups.containsKey),
      ...groups.keys.where((a) => !_aisleOrder.contains(a)),
    ];

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            if (_recipes.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: SectionRule(label: s.t('shopping.sources')),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  children: [
                    for (final recipe in _recipes)
                      _sourceChip(context, recipe, lang),
                  ],
                ),
              ),
            ],
            Expanded(
              child: _loading && _items.isEmpty
                  ? Center(
                      child: Text(
                        s.t('common.loading'),
                        style: AppText.monoLabel(),
                      ),
                    )
                  : _items.isEmpty
                  ? _buildEmpty(s)
                  : TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      builder: (context, v, child) =>
                          Opacity(opacity: v, child: child),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        children: [
                          for (final aisle in orderedAisles) ...[
                            SectionRule(label: _aisleLabel(s, aisle)),
                            const SizedBox(height: 4),
                            for (final item in groups[aisle]!)
                              _itemRow(
                                context,
                                item,
                                checked.contains(
                                  '${item.ingredientId}|${item.unit}',
                                ),
                                lang,
                              ),
                            const SizedBox(height: 18),
                          ],
                        ],
                      ),
                    ),
            ),
            if (_items.isNotEmpty) _buildFooter(s, store, checked.isNotEmpty),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppStrings s) {
    final count = _items.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('shopping.title'), style: AppText.masthead(size: 34)),
              const SizedBox(height: 2),
              Text(
                '$count ${s.t(count == 1 ? 'shopping.item' : 'shopping.items')}',
                style: AppText.monoLabel(size: 11),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: s.t('shopping.insights.tooltip'),
            icon: const Icon(
              Icons.bar_chart_rounded,
              color: AppColors.inkSoft,
              size: 22,
            ),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.insights),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(BuildContext context, Recipe recipe, String lang) {
    final corpus = context.read<CorpusRepository>();
    final dish = corpus.dishById(recipe.dishId);
    final label =
        '${localize(dish?.name, lang)} · ${localize(recipe.title, lang)}';
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.only(left: 10),
      decoration: BoxDecoration(
        color: AppColors.paperDark,
        border: Border.all(
          color: AppColors.inkSoft.withValues(alpha: 0.6),
          width: 0.6,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toLowerCase(),
            style: AppText.monoLabel(size: 10, color: AppColors.ink),
          ),
          InkWell(
            onTap: () =>
                context.read<LocalStore>().removeFromShoppingList(recipe.id),
            borderRadius: BorderRadius.circular(4),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, size: 14, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(
    BuildContext context,
    ShoppingItem item,
    bool checked,
    String lang,
  ) {
    final store = context.read<LocalStore>();
    final lineKey = '${item.ingredientId}|${item.unit}';
    return Opacity(
      opacity: checked ? 0.5 : 1,
      child: InkWell(
        onTap: () => store.toggleShoppingChecked(lineKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _SketchCheckbox(checked: checked),
              const SizedBox(width: 12),
              SizedBox(
                width: 74,
                child: Text(
                  '${formatAmount(item.amount)} ${item.unit}',
                  style: AppText.monoLabel(
                    size: 11,
                    color: checked ? AppColors.disabled : AppColors.teal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  localize(item.name, lang).toLowerCase(),
                  style: AppText.headline(size: 17).copyWith(
                    color: checked ? AppColors.disabled : AppColors.ink,
                    decoration: checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    decorationColor: AppColors.coral,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppStrings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.t('shopping.empty.title'),
              style: AppText.handwritten(size: 28, color: AppColors.inkSoft),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const DashedRule(),
            const SizedBox(height: 16),
            Text(
              s.t('shopping.empty.hint'),
              style: AppText.monoLabel(size: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(AppStrings s, LocalStore store, bool anyChecked) {
    final quietButton = ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(AppColors.inkSoft),
      textStyle: WidgetStatePropertyAll(AppText.monoLabel(size: 11)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      minimumSize: const WidgetStatePropertyAll(Size.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: DashedRule(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (anyChecked)
                TextButton(
                  style: quietButton,
                  onPressed: () => store.clearShoppingChecked(),
                  child: Text(s.t('shopping.clearChecked')),
                ),
              TextButton(
                style: quietButton,
                onPressed: () => _confirmClearAll(s),
                child: Text(s.t('shopping.clearAll')),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Hand-drawn style checkbox: a slightly sketchy square with a wobbly tick.
class _SketchCheckbox extends StatelessWidget {
  final bool checked;
  const _SketchCheckbox({required this.checked});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SketchBoxPainter(checked: checked),
      size: const Size(22, 22),
    );
  }
}

class _SketchBoxPainter extends CustomPainter {
  final bool checked;
  _SketchBoxPainter({required this.checked});

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = checked ? AppColors.teal : AppColors.inkSoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rect = Rect.fromLTWH(1.5, 1.5, size.width - 3, size.height - 3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      border,
    );
    if (checked) {
      final tick = Paint()
        ..color = AppColors.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(size.width * 0.2, size.height * 0.55)
        ..lineTo(size.width * 0.44, size.height * 0.78)
        ..lineTo(size.width * 0.85, size.height * 0.22);
      canvas.drawPath(path, tick);
    }
  }

  @override
  bool shouldRepaint(covariant _SketchBoxPainter oldDelegate) =>
      oldDelegate.checked != checked;
}
