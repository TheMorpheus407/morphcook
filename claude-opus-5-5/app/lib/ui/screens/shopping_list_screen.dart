import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../logic/quantities.dart';
import '../../logic/shopping.dart';
import '../../state/library_store.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final _add = TextEditingController();
  bool _showSources = false;

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final repo = context.watch<CorpusRepository>();
    final library = context.watch<LibraryStore>();
    final sources = library.shoppingSources;
    final missing = sources.where((s) => repo.recipe(s.recipeId) == null).map((s) => s.recipeId).toSet();
    if (missing.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => repo.ensureRecipes(missing));
    }
    final agg = ShoppingAggregator(repo.ontology, repo.ingredients);
    final lines = agg.aggregate(sources, repo.recipe);
    final parts = agg.groupByAisle(lines, lang);
    final manual = library.manualItems;
    final checked = library.checked;
    final isEmpty = sources.isEmpty && manual.isEmpty;

    return SafeArea(
      bottom: false,
      child: ListView(
        key: const Key('shopping-list'),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: Text(tr('list.title'), style: MT.display(38))),
                IconButton(
                  key: const Key('open-insights'),
                  tooltip: tr('list.insights'),
                  onPressed: () => openInsights(context),
                  icon: const Icon(Icons.insights_outlined, color: MC.inkSoft),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: MC.inkSoft),
                  color: MC.card,
                  onSelected: (v) async {
                    if (v == 'checked') {
                      await library.clearChecked();
                    } else if (v == 'all') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(tr('list.clearAll.confirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(tr('common.cancel')),
                            ),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('list.clearAll'))),
                          ],
                        ),
                      );
                      if (ok == true) await library.clearShopping();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'checked',
                      child: Text(tr('list.clearChecked'), style: MT.mono(12, color: MC.ink)),
                    ),
                    PopupMenuItem(
                      value: 'all',
                      child: Text(tr('list.clearAll'), style: MT.mono(12, color: MC.coralDeep)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: TextField(
              key: const Key('list-add'),
              controller: _add,
              style: MT.serif(16),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: tr('list.add.hint'),
                prefixIcon: const Icon(Icons.add, color: MC.inkSoft),
              ),
              onSubmitted: (v) {
                library.addManual(v);
                _add.clear();
              },
            ),
          ),
          if (isEmpty)
            EmptyState(title: tr('list.empty.title'), body: tr('list.empty.body'))
          else ...[
            if (sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: InkWell(
                  onTap: () => setState(() => _showSources = !_showSources),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        MonoLabel('${tr('list.recipes')} · ${sources.length}'),
                        const SizedBox(width: 4),
                        Icon(_showSources ? Icons.expand_less : Icons.expand_more, size: 18, color: MC.inkSoft),
                      ],
                    ),
                  ),
                ),
              ),
            if (_showSources)
              for (final s in sources)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${repo.recipe(s.recipeId)?.title.of(lang).toLowerCase() ?? s.recipeId} · ${tr('list.servings', {'n': s.servings})}',
                          style: MT.hand(19, color: MC.ink),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('common.remove'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 16, color: MC.inkFaint),
                        onPressed: () => library.removeSource(s.id),
                      ),
                    ],
                  ),
                ),
            for (final part in parts) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repo.ontology.aisleLabel(part.aisle, lang), style: MT.display(20, color: MC.tealDeep)),
                    const SizedBox(height: 4),
                    const DashedRule(),
                  ],
                ),
              ),
              for (final line in part.lines)
                _LineRow(
                  key: Key('line-${line.key}'),
                  name: repo.ingredients.name(line.ingredientId, lang),
                  amount: _amount(agg, line, repo, lang),
                  checked: checked.contains(line.key),
                  onToggle: () => library.toggleChecked(line.key),
                  detail: line.recipeIds.length > 1 ? '×${line.recipeIds.length}' : null,
                ),
            ],
            if (manual.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('list.manual'), style: MT.display(20, color: MC.tealDeep)),
                    const SizedBox(height: 4),
                    const DashedRule(),
                  ],
                ),
              ),
              for (final m in manual)
                Dismissible(
                  key: ValueKey('manual-${m.id}'),
                  onDismissed: (_) => library.removeManual(m.id),
                  child: _LineRow(
                    name: m.text,
                    amount: '',
                    checked: checked.contains('manual|${m.id}'),
                    onToggle: () => library.toggleChecked('manual|${m.id}'),
                    hand: true,
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  String _amount(ShoppingAggregator agg, ShoppingLine line, CorpusRepository repo, String lang) {
    final (qty, unit) = agg.display(line);
    return formatAmount(qty, unit, repo.ontology, lang);
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.name,
    required this.amount,
    required this.checked,
    required this.onToggle,
    this.detail,
    this.hand = false,
  });

  final String name;
  final String amount;
  final bool checked;
  final VoidCallback onToggle;
  final String? detail;
  final bool hand;

  @override
  Widget build(BuildContext context) {
    final color = checked ? MC.inkFaint : MC.ink;
    final deco = checked ? TextDecoration.lineThrough : null;
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 20, 2),
        child: Row(
          children: [
            Checkbox(value: checked, onChanged: (_) => onToggle()),
            Expanded(
              child: Text(
                name,
                style: (hand ? MT.hand(20, color: color) : MT.serif(16, color: color)).copyWith(decoration: deco),
              ),
            ),
            if (detail != null) ...[Text(detail!, style: MT.mono(9.5, color: MC.coral)), const SizedBox(width: 8)],
            Text(
              amount,
              style: MT.mono(12, color: checked ? MC.inkFaint : MC.inkSoft).copyWith(decoration: deco),
            ),
          ],
        ),
      ),
    );
  }
}
