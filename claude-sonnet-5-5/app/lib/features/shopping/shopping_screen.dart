import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/recipe.dart';
import '../../domain/shopping/aggregator.dart';
import '../../state/controllers/shopping_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/state_views.dart';
import 'add_item_sheet.dart';
import '../../core/text_scale.dart';

/// The smart shopping list: unit-aware aggregation of the recipes on the list,
/// deduplicated and grouped by aisle.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String _signature = '';
  String _lang = '';
  List<AisleGroup> _groups = const <AisleGroup>[];
  Map<String, Recipe> _recipes = const <String, Recipe>{};
  bool _loaded = false;

  String _signatureOf(ShoppingController c, String lang) =>
      '$lang|${c.sources.map((e) => '${e.recipeId}:${e.servings}').join(',')}|${c.manualItems.map((m) => '${m.id}:${m.amount}${m.unit}').join(',')}|${c.dismissed.join(',')}';

  Future<void> _recompute(ShoppingController shopping, String lang) async {
    final corpus = context.read<Corpus>();
    final aggregator = context.read<ShoppingAggregator>();
    final sources = <ShoppingSource>[];
    final recipes = <String, Recipe>{};
    for (final entry in shopping.sources) {
      final recipe = await corpus.loadRecipe(entry.recipeId);
      if (recipe == null) continue;
      recipes[recipe.id] = recipe;
      sources.add(ShoppingSource(recipe: recipe, servings: entry.servings));
    }
    final lines = aggregator
        .aggregate(sources, manual: shopping.manualItems)
        .where((l) => !shopping.dismissed.contains(l.key))
        .toList();
    if (!mounted) return;
    setState(() {
      _recipes = recipes;
      _groups = aggregator.group(lines, lang);
      _loaded = true;
    });
  }

  /// The aggregated groups without lines that were swiped away or removed since
  /// the last recompute. Filtering here, in the same frame, keeps a dismissed
  /// [Dismissible] from lingering in the tree while the list is recomputed.
  List<AisleGroup> _visibleGroups(ShoppingController shopping) {
    final manualKeys = {for (final m in shopping.manualItems) 'manual:${m.id}'};
    bool keep(ShoppingLine line) {
      if (shopping.dismissed.contains(line.key)) return false;
      return !line.key.startsWith('manual:') || manualKeys.contains(line.key);
    }

    return [
      for (final group in _groups)
        if (group.lines.any(keep))
          AisleGroup(
            aisle: group.aisle,
            lines: [
              for (final l in group.lines)
                if (keep(l)) l,
            ],
          ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final shopping = context.watch<ShoppingController>();
    final signature = _signatureOf(shopping, s.lang);
    if (signature != _signature) {
      _signature = signature;
      _lang = s.lang;
      _recompute(shopping, s.lang);
    }
    final corpus = context.read<Corpus>();

    final hasChecked = shopping.checked.isNotEmpty;
    return SafeArea(
      bottom: false,
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabHeader(
              title: s('shopping.title'),
              note: s('shopping.note'),
              actions: [
                PaperIconButton(
                  icon: Icons.insights_outlined,
                  tooltip: s('insights.title'),
                  onPressed: () => openInsights(context),
                ),
                PaperIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: s('nav.settings'),
                  onPressed: () => openSettings(context),
                ),
              ],
            ),
            Expanded(
              child: !_loaded && !shopping.isEmpty
                  ? const SizedBox.shrink()
                  : shopping.isEmpty
                  ? EmptyState(
                      title: s('shopping.empty.title'),
                      body: s('shopping.empty.body'),
                      action: s('shopping.empty.action'),
                      icon: Icons.add,
                      onAction: () => showAddItemSheet(context),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 32),
                      children: [
                        if (shopping.sources.isNotEmpty)
                          _SourcesBlock(shopping: shopping, recipes: _recipes, lang: _lang),
                        for (final group in _visibleGroups(shopping))
                          _AisleBlock(group: group, shopping: shopping, corpus: corpus),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            PaperButton(
                              label: s('shopping.addItem'),
                              icon: Icons.add,
                              style: PaperButtonStyle.outline,
                              dense: true,
                              onPressed: () => showAddItemSheet(context),
                            ),
                            if (hasChecked)
                              PaperButton(
                                label: s('shopping.clearChecked'),
                                icon: Icons.done_all,
                                style: PaperButtonStyle.quiet,
                                dense: true,
                                onPressed: shopping.clearChecked,
                              ),
                            PaperButton(
                              label: s('shopping.startOver'),
                              style: PaperButtonStyle.quiet,
                              dense: true,
                              onPressed: () => _confirmClear(context, shopping),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ShoppingController shopping) async {
    final s = context.sRead;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(s('shopping.startOver.title')),
        content: Text(s('shopping.startOver.body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('common.cancel'))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s('shopping.startOver'))),
        ],
      ),
    );
    if (ok == true) await shopping.clearList();
  }
}

/// The recipes feeding the list, each with its servings.
class _SourcesBlock extends StatelessWidget {
  const _SourcesBlock({required this.shopping, required this.recipes, required this.lang});

  final ShoppingController shopping;
  final Map<String, Recipe> recipes;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(s('shopping.cooking')),
          for (final entry in shopping.sources)
            if (recipes[entry.recipeId] != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _sourceRow(
                  context,
                  title: Text(
                    recipes[entry.recipeId]!.title.resolve(lang),
                    maxLines: context.largeText ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.serifItalic(size: 17),
                  ),
                  controls: [
                    PaperIconButton(
                      icon: Icons.remove_circle_outline,
                      size: 20,
                      tooltip: s('dish.fewer'),
                      onPressed: entry.servings > 1
                          ? () => shopping.setServings(entry.recipeId, entry.servings - 1)
                          : null,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 62),
                      child: Center(
                        child: Text(
                          s.plural('dish.people', entry.servings.round()),
                          style: AppText.mono(size: 11.5, color: Palette.ink, weight: FontWeight.w700),
                        ),
                      ),
                    ),
                    PaperIconButton(
                      icon: Icons.add_circle_outline,
                      size: 20,
                      tooltip: s('dish.more'),
                      onPressed: () => shopping.setServings(entry.recipeId, entry.servings + 1),
                    ),
                    PaperIconButton(
                      icon: Icons.close,
                      size: 20,
                      tooltip: s('common.remove'),
                      onPressed: () => shopping.removeRecipe(entry.recipeId),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  /// The title with its servings controls beside it, or the controls under the title when text is large.
  Widget _sourceRow(BuildContext context, {required Widget title, required List<Widget> controls}) {
    if (context.largeText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          // One piece: shrinks a little at the very largest text sizes instead of overflowing.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: controls),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: title),
        ...controls,
      ],
    );
  }
}

class _AisleBlock extends StatelessWidget {
  const _AisleBlock({required this.group, required this.shopping, required this.corpus});

  final AisleGroup group;
  final ShoppingController shopping;
  final Corpus corpus;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final open = [
      for (final l in group.lines)
        if (!shopping.isChecked(l.key)) l,
    ];
    final done = [
      for (final l in group.lines)
        if (shopping.isChecked(l.key)) l,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: AmpersandText(group.aisle.name.resolve(s.lang), style: AppText.display(size: 24))),
                Text('${done.length}/${group.lines.length}', style: AppText.mono(size: 11)),
              ],
            ),
          ),
          const DashedRule(),
          for (final line in [...open, ...done]) _LineRow(line: line, shopping: shopping, corpus: corpus),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.shopping, required this.corpus});

  final ShoppingLine line;
  final ShoppingController shopping;
  final Corpus corpus;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final checked = shopping.isChecked(line.key);
    final name = line.nameText(corpus.ingredients, corpus.ontology, s.lang);
    final amount = line.amountText(corpus.ontology, corpus.ingredients, s.lang);
    final titles = [
      for (final id in line.recipeIds)
        if (corpus.dishOfRecipe(id) != null)
          corpus.recipeSync(id)?.title.resolve(s.lang) ?? corpus.dishOfRecipe(id)!.name.resolve(s.lang),
    ];
    final sourceNote = titles.isEmpty
        ? null
        : titles.length <= 2
        ? s('shopping.for', {'items': titles.join(', ')})
        : s('shopping.for', {'items': '${titles.take(2).join(', ')} +${titles.length - 2}'});
    final textColor = checked ? Palette.inkFaint : Palette.ink;

    final row = InkWell(
      onTap: () => shopping.toggleChecked(line.key),
      child: Semantics(
        checked: checked,
        label: '$name, ${amount.isEmpty ? s('unit.toTaste') : amount}',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: checked ? Palette.teal : Colors.transparent,
                    border: Border.all(color: checked ? Palette.tealDeep : Palette.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: checked ? const Icon(Icons.check, size: 16, color: Palette.paperLight) : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lower(name),
                        style: AppText.serif(size: 17.5, color: textColor).copyWith(
                          decoration: checked ? TextDecoration.lineThrough : null,
                          decorationColor: Palette.inkFaint,
                        ),
                      ),
                      if (sourceNote != null)
                        Text(
                          sourceNote,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.hand(size: 17, color: checked ? Palette.inkFaint : Palette.inkSoft),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  amount.isEmpty ? s('unit.toTaste') : amount,
                  textAlign: TextAlign.right,
                  style: AppText.mono(
                    size: 12.5,
                    color: amount.isEmpty || checked ? Palette.inkFaint : Palette.ink,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('line-${line.key}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Palette.coral.withValues(alpha: 0.18),
        child: const Icon(Icons.delete_outline, color: Palette.coralDeep),
      ),
      onDismissed: (_) {
        if (line.key.startsWith('manual:')) {
          shopping.removeManual(line.key.substring(7));
        } else {
          shopping.dismiss(line.key);
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Palette.paperDeep)),
        ),
        child: row,
      ),
    );
  }
}
