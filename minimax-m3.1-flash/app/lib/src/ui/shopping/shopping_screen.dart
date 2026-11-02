import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../l10n/strings.dart';
import '../../models/recipe.dart';
import '../../models/shopping.dart';
import '../../state/app_state.dart';
import '../../state/shopping_controller.dart';
import '../dish/dish_detail_screen.dart';
import 'insights_screen.dart';

/// The smart shopping list.
class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final shopping = context.watch<ShoppingController>();

    final selectedRecipes = state.corpus.allRecipes
        .where((recipe) => shopping.isSelected(recipe.id))
        .toList();
    final items = shopping.buildItems(
      recipes: state.corpus.allRecipes,
      ingredients: state.corpus.ingredients,
      lang: strings.lang,
    );

    final grouped = <String, List<ShoppingItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.aisle, () => <ShoppingItem>[]).add(item);
    }

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 18,
              20,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        strings.shoppingTitle,
                        style: Type.display(size: 30),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const InsightsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.insights_outlined),
                      color: MC.inkSoft,
                      tooltip: strings.shoppingInsights,
                    ),
                    IconButton(
                      onPressed: items.isEmpty && shopping.notes.isEmpty
                          ? null
                          : () => _confirmClear(context),
                      icon: const Icon(Icons.backspace_outlined),
                      color: MC.inkSoft,
                      tooltip: strings.shoppingClear,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${items.length} ${strings.searchResultsCount}',
                  style: Type.scriptSmall(size: 15),
                ),
                const SizedBox(height: 12),
                const DashedRule(),
              ],
            ),
          ),
        ),
        if (items.isEmpty && shopping.notes.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              title: 'the list is empty',
              message: 'add recipes from the cookbook or export a meal plan.',
              glyph: '⌂',
            ),
          )
        else ...<Widget>[
          if (selectedRecipes.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeading(title: strings.shoppingSelectedRecipes),
                    const SizedBox(height: 10),
                    for (final recipe in selectedRecipes)
                      _SelectedRecipeRow(recipe: recipe, strings: strings),
                  ],
                ),
              ),
            ),
          for (final entry in grouped.entries)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeading(title: strings.aisleName(entry.key)),
                    const SizedBox(height: 8),
                    for (final item in entry.value)
                      _ShoppingRow(item: item, strings: strings),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeading(title: strings.shoppingNotes),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _noteController,
                          style: Type.body(size: 14.5, color: MC.ink),
                          cursorColor: MC.coral,
                          decoration: InputDecoration(
                            hintText: strings.shoppingNoteHint,
                            hintStyle: Type.body(size: 14, color: MC.inkGhost),
                            filled: true,
                            fillColor: MC.card,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3),
                              borderSide: const BorderSide(color: MC.ruleFaint),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3),
                              borderSide: const BorderSide(color: MC.ruleFaint),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(3),
                              borderSide: const BorderSide(color: MC.coral),
                            ),
                          ),
                          onSubmitted: (_) => _addNote(),
                        ),
                      ),
                      const SizedBox(width: 9),
                      GhostButton(
                        label: strings.shoppingAdd,
                        onPressed: _addNote,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final note in shopping.notes)
                    _NoteRow(note: note, strings: strings),
                ],
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  void _addNote() {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    context.read<ShoppingController>().addNote(text);
    _noteController.clear();
  }

  Future<void> _confirmClear(BuildContext context) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(state.strings.shoppingClear),
        content: Text(state.strings.shoppingEmptyBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(state.strings.genericCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(state.strings.genericDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ShoppingController>().clear();
    }
  }
}

class _ShoppingRow extends StatelessWidget {
  const _ShoppingRow({required this.item, required this.strings});

  final ShoppingItem item;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingController>();
    final quantity = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(1);

    return InkWell(
      onTap: () => shopping.toggleChecked(item.ingredientId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _CheckboxPainter(checked: item.checked),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: Type.body(
                  size: 15,
                  color: item.checked ? MC.inkGhost : MC.ink,
                ).copyWith(
                  decoration:
                      item.checked ? TextDecoration.lineThrough : null,
                  decorationColor: MC.inkGhost,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              item.unit.isEmpty ? quantity : '$quantity ${item.unit}',
              style: Type.mono(
                size: 12.5,
                color: item.checked ? MC.inkGhost : MC.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckboxPainter extends CustomPainter {
  const _CheckboxPainter({required this.checked});
  final bool checked;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final border = Paint()
      ..color = checked ? MC.teal : MC.rule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawRect(rect.deflate(0.7), border);
    if (checked) {
      final fill = Paint()..color = MC.teal.withValues(alpha: 0.16);
      canvas.drawRect(rect.deflate(1.2), fill);
      final tick = Paint()
        ..color = MC.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(size.width * 0.24, size.height * 0.52),
        Offset(size.width * 0.44, size.height * 0.72),
        tick,
      );
      canvas.drawLine(
        Offset(size.width * 0.44, size.height * 0.72),
        Offset(size.width * 0.78, size.height * 0.28),
        tick,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckboxPainter old) => old.checked != checked;
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.strings});

  final ShoppingNote note;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingController>();
    return InkWell(
      onTap: () => shopping.toggleNoteChecked(note.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(
                painter: _CheckboxPainter(checked: note.checked),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                note.name,
                style: Type.body(
                  size: 15,
                  color: note.checked ? MC.inkGhost : MC.ink,
                ),
              ),
            ),
            IconButton(
              onPressed: () => shopping.removeNote(note.id),
              icon: const Icon(Icons.close_rounded, size: 15),
              color: MC.inkGhost,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedRecipeRow extends StatelessWidget {
  const _SelectedRecipeRow({required this.recipe, required this.strings});

  final Recipe recipe;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final shopping = context.read<ShoppingController>();
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => DishDetailScreen(dishId: recipe.dishId),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    recipe.title.resolve(strings.lang),
                    style: Type.bodyStrong(size: 14.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${recipe.servings} ${strings.dishServings}',
                    style: Type.label(size: 9),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => shopping.removeRecipe(recipe.id),
              icon: const Icon(Icons.close_rounded, size: 16),
              color: MC.inkFaint,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
