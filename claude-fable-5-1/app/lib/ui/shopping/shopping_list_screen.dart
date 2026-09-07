import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/shopping.dart';
import '../../domain/shopping_aggregator.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import '../shell/app_shell.dart';
import '../widgets/ingredient_guide_sheet.dart';
import '../widgets/meta.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  String _signature = '';
  final _manual = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _ensureLoaded() async {
    final app = context.read<AppController>();
    final sig = app.shopping.sources.map((s) => s.recipeId).join(',');
    if (sig == _signature) return;
    _signature = sig;
    await app.ensureShoppingRecipesLoaded();
    if (mounted) setState(() {});
  }

  Future<void> _addManual() async {
    final app = context.read<AppController>();
    final text = _manual.text;
    if (text.trim().isEmpty) return;
    _manual.clear();
    await app.addManualItem(text);
  }

  Future<void> _clearAll() async {
    final app = context.read<AppController>();
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s('list.clearAll.confirm')),
        actions: [
          PaperButton(label: s('common.cancel'), kind: PaperButtonKind.quiet, onPressed: () => Navigator.of(ctx).pop(false)),
          PaperButton(label: s('common.clear'), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      ),
    );
    if (ok == true) await app.clearShopping();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final meta = RecipeMeta(app, lang);
    final shopping = app.shopping;
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());

    final header = SectionHeader(
      title: s('list.title'),
      kicker: s('list.kicker'),
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 8),
      trailing: IconButton(
        icon: const Icon(Icons.insights_outlined),
        tooltip: s('list.insights'),
        onPressed: () => Routes.openInsights(context),
      ),
    );

    if (shopping.sources.isEmpty && shopping.manual.isEmpty) {
      return SafeArea(
        bottom: false,
        child: ListView(
          children: [
            header,
            EmptyState(
              title: s('list.empty.title'),
              note: s('list.empty.note'),
              icon: Icons.shopping_basket_outlined,
              action: PaperButton(
                label: s('nav.plan'),
                kind: PaperButtonKind.secondary,
                icon: Icons.calendar_view_week_outlined,
                onPressed: () => ShellTabs.maybeOf(context)?.select(ShellTabs.plan),
              ),
            ),
          ],
        ),
      );
    }

    final groups = app.shoppingByAisle();
    final children = <Widget>[header];

    if (shopping.sources.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
        child: MonoLabel(s('list.recipes')),
      ));
      for (final src in shopping.sources) {
        children.add(_SourceRow(source: src));
      }
      children.add(const DashedRule(padding: EdgeInsets.fromLTRB(20, 10, 20, 4)));
    }

    for (final g in groups) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [MonoLabel(meta.aisle(g.aisle.id), color: Palette.ink), const SizedBox(height: 4), const DashedRule()],
        ),
      ));
      for (final line in g.lines) {
        children.add(_LineRow(line: line, checked: shopping.checked.contains(line.key)));
      }
    }

    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [MonoLabel(s('list.manual'), color: Palette.ink), const SizedBox(height: 4), const DashedRule()],
      ),
    ));
    for (final m in shopping.manual) {
      children.add(_ManualRow(item: m, checked: shopping.checked.contains(m.id)));
    }
    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _manual,
              onSubmitted: (_) => _addManual(),
              textInputAction: TextInputAction.done,
              style: AppText.body(size: 14.5),
              decoration: InputDecoration(hintText: s('list.manualHint')),
            ),
          ),
          const SizedBox(width: 8),
          PaperButton(label: s('list.addManual'), kind: PaperButtonKind.secondary, icon: Icons.add, onPressed: _addManual),
        ],
      ),
    ));

    children.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Row(
        children: [
          Expanded(
            child: PaperButton(
              label: s('list.clearChecked'),
              kind: PaperButtonKind.secondary,
              icon: Icons.checklist,
              expand: true,
              onPressed: shopping.checked.isEmpty ? null : () => app.clearChecked(),
            ),
          ),
          const SizedBox(width: 8),
          PaperButton(label: s('list.clearAll'), kind: PaperButtonKind.quiet, onPressed: _clearAll),
        ],
      ),
    ));

    return SafeArea(bottom: false, child: ListView(children: children));
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});
  final ShoppingSource source;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = context.lang;
    final s = context.s;
    final recipe = app.recipeIfLoaded(source.recipeId);
    final title = recipe?.title.of(lang) ?? source.recipeId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 8, 2),
      child: Row(
        children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(size: 14))),
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: source.servings > 1 ? () => app.setShoppingServings(source.recipeId, source.servings - 1) : null,
          ),
          Text('${source.servings}', style: AppText.mono(color: Palette.ink, size: 12.5, weight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: source.servings < 24 ? () => app.setShoppingServings(source.recipeId, source.servings + 1) : null,
          ),
          MonoLabel(s('list.servings'), size: 9.5),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: s('common.remove'),
            onPressed: () => app.removeFromShopping(source.recipeId),
          ),
        ],
      ),
    );
  }
}

class _CheckSquare extends StatelessWidget {
  const _CheckSquare({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: Motion.duration(context, const Duration(milliseconds: 140)),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: checked ? Palette.ink : Colors.transparent,
          border: Border.all(color: checked ? Palette.ink : Palette.ruleStrong, width: 1.2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: checked ? const Icon(Icons.check, size: 13, color: Palette.paper) : null,
      );
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.checked});
  final AggregatedLine line;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = context.lang;
    final s = context.s;
    final meta = RecipeMeta(app, lang);
    final toTaste = line.displayUnit == 'to-taste' || line.displayAmount == null;
    final amount = toTaste ? '' : formatAmount(line.displayAmount);
    final unit = toTaste ? '' : meta.unit(line.displayUnit);
    final name = meta.ingredient(line.ingredientId);
    final color = checked ? Palette.inkFaint : Palette.ink;
    final textStyle = AppText.body(size: 15, color: color).copyWith(
      decoration: checked ? TextDecoration.lineThrough : null,
      decorationColor: Palette.inkFaint,
    );
    return InkWell(
      onTap: () => app.toggleChecked(line.key),
      onLongPress: () => showIngredientGuide(context, line.ingredientId),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 3), child: _CheckSquare(checked: checked)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: textStyle,
                      children: [
                        if (!toTaste) TextSpan(text: '$amount $unit ', style: AppText.mono(color: color, size: 12.5, weight: FontWeight.w600).copyWith(decoration: textStyle.decoration, decorationColor: Palette.inkFaint)),
                        TextSpan(text: name),
                        if (toTaste) TextSpan(text: '  ${s('list.toTaste')}', style: AppText.mono(color: Palette.inkFaint, size: 11)),
                        if (line.sourceRecipeIds.length > 1)
                          TextSpan(text: '  ${s('list.from', {'n': '${line.sourceRecipeIds.length}'})}', style: AppText.mono(color: Palette.inkFaint, size: 10.5)),
                      ],
                    ),
                  ),
                  if (line.notes.isNotEmpty) HandNote(line.notes.join(' · '), size: 16, color: Palette.inkFaint, maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualRow extends StatelessWidget {
  const _ManualRow({required this.item, required this.checked});
  final ManualItem item;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final s = context.s;
    final color = checked ? Palette.inkFaint : Palette.ink;
    return InkWell(
      onTap: () => app.toggleChecked(item.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
        child: Row(
          children: [
            _CheckSquare(checked: checked),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.text,
                style: AppText.body(size: 15, color: color).copyWith(decoration: checked ? TextDecoration.lineThrough : null, decorationColor: Palette.inkFaint),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              visualDensity: VisualDensity.compact,
              tooltip: s('common.remove'),
              onPressed: () => app.removeManualItem(item.id),
            ),
          ],
        ),
      ),
    );
  }
}
