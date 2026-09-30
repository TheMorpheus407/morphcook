import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/ingredient.dart';
import '../../domain/shopping/aggregator.dart';
import '../../state/controllers/shopping_controller.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';

/// Add a line by hand: type an ingredient (the dictionary suggests matches,
/// so it merges with recipe lines and lands in the right aisle) or write free text.
Future<void> showAddItemSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.paperLight,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (context) => const _AddItemSheet(),
  );
}

class _AddItemSheet extends StatefulWidget {
  const _AddItemSheet();

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  IngredientNode? _picked;
  String _unit = 'piece';

  static const List<String> _units = <String>['piece', 'g', 'kg', 'ml', 'l', 'tbsp', 'tsp', 'pack'];

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final label = _text.text.trim();
    if (label.isEmpty) return;
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    final item = ManualItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      label: label,
      ingredientId: _picked?.id,
      amount: amount,
      unit: amount == null ? null : _unit,
    );
    await context.read<ShoppingController>().addManual(item);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final corpus = context.read<Corpus>();
    final suggestions = _picked != null
        ? const <IngredientNode>[]
        : corpus.ingredients.search(_text.text, s.lang, limit: 5);
    return PaperBackground(
      color: Palette.paperLight,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Palette.rule, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(s('shopping.add.title'), style: AppText.display(size: 30)),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: AppText.serifItalic(size: 20),
                decoration: InputDecoration(hintText: s('shopping.add.hint')),
                onChanged: (_) => setState(() => _picked = null),
              ),
              for (final node in suggestions)
                InkWell(
                  onTap: () => setState(() {
                    _picked = node;
                    _text.text = node.name.resolve(s.lang);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(node.name.resolve(s.lang), style: AppText.serif(size: 16.5))),
                        Text(
                          corpus.ontology.aisles
                              .firstWhere(
                                (a) => a.id == corpus.ingredients.aisleOf(node.id),
                                orElse: () => corpus.ontology.aisles.last,
                              )
                              .name
                              .resolve(s.lang),
                          style: AppText.mono(size: 10.5),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppText.mono(size: 15, color: Palette.ink),
                      decoration: InputDecoration(hintText: s('shopping.add.amount')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 0,
                      children: [
                        for (final unit in _units)
                          PaperChip(
                            label: unit == 'piece' ? '×' : (corpus.ontology.unit(unit)?.label(s.lang) ?? unit),
                            dense: true,
                            style: PaperChipStyle.mono,
                            selected: _unit == unit,
                            onTap: () => setState(() => _unit = unit),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: PaperButton(label: s('shopping.add.confirm'), icon: Icons.add, onPressed: _submit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
