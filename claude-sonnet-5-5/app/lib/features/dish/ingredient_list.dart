import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/ingredient_guide.dart';
import '../../data/models/ontology.dart';
import '../../data/models/recipe.dart';
import '../../domain/shopping/amounts.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../core/text_scale.dart';

/// Text of an ingredient line's amount: `2 tbsp`, `1½ cloves`, `3` (for pieces).
String ingredientAmountText(Ontology ontology, RecipeIngredient line, double scale, String lang) {
  final amount = line.amount;
  final unit = ontology.unit(line.unit);
  if (amount == null || unit == null || unit.isFree) return '';
  final scaled = amount * scale;
  final number = AmountFormatter.format(scaled, line.unit, lang);
  final plural = (AmountFormatter.roundFor(scaled, line.unit) - 1).abs() > 1e-9;
  final label = unit.label(lang, plural: plural);
  return label.isEmpty ? number : '$number $label';
}

/// Name of an ingredient line. Pieces read in plural when the amount is not 1.
String ingredientNameText(IngredientDictionary dictionary, RecipeIngredient line, double scale, String lang) {
  final amount = line.amount;
  final plural =
      line.unit == 'piece' && amount != null && (AmountFormatter.roundFor(amount * scale, 'piece') - 1).abs() > 1e-9;
  return dictionary.nameOf(line.id, lang, plural: plural);
}

/// Which ingredient lines differ from the previous variant: new ingredients and
/// changed amounts flash when the variant switches.
Set<int> changedIngredientIndexes(Recipe? previous, Recipe current) {
  if (previous == null || previous.id == current.id) return const <int>{};
  final before = {for (final l in previous.ingredients) '${l.id}|${l.amount}|${l.unit}'};
  return {
    for (var i = 0; i < current.ingredients.length; i++)
      if (!before.contains(
        '${current.ingredients[i].id}|${current.ingredients[i].amount}|${current.ingredients[i].unit}',
      ))
        i,
  };
}

/// The scaled ingredient list with group headings, "learn more" buttons and a
/// highlight flash on lines that changed with the variant.
class IngredientList extends StatelessWidget {
  const IngredientList({
    super.key,
    required this.recipe,
    required this.scale,
    required this.dictionary,
    required this.ontology,
    required this.changed,
    required this.guide,
    required this.onLearnMore,
  });

  final Recipe recipe;
  final double scale;
  final IngredientDictionary dictionary;
  final Ontology ontology;

  /// Indexes of lines to flash (see [changedIngredientIndexes]).
  final Set<int> changed;
  final IngredientGuide? guide;
  final ValueChanged<String> onLearnMore;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final rows = <Widget>[];
    String? lastGroup;
    for (var i = 0; i < recipe.ingredients.length; i++) {
      final line = recipe.ingredients[i];
      final group = line.group.resolve(s.lang);
      if (group.isNotEmpty && group != lastGroup) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(top: lastGroup == null && i == 0 ? 0 : 14, bottom: 4),
            child: Row(
              children: [
                MonoLabel(group, color: Palette.coralDeep),
                const SizedBox(width: 10),
                const Expanded(child: DashedRule(dash: 2, gap: 4)),
              ],
            ),
          ),
        );
      }
      lastGroup = group.isEmpty ? lastGroup : group;
      rows.add(
        _IngredientRow(
          key: ValueKey('${recipe.id}:$i'),
          line: line,
          amount: ingredientAmountText(ontology, line, scale, s.lang),
          name: ingredientNameText(dictionary, line, scale, s.lang),
          note: line.note.resolve(s.lang),
          flash: changed.contains(i),
          hasGuide: guide?.has(line.id) ?? false,
          learnMoreLabel: s('guide.learnMore'),
          onLearnMore: () => onLearnMore(line.id),
          optionalLabel: s('recipe.optional'),
          toTasteLabel: s('unit.toTaste'),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.line,
    required this.amount,
    required this.name,
    required this.note,
    required this.flash,
    required this.hasGuide,
    required this.learnMoreLabel,
    required this.onLearnMore,
    required this.optionalLabel,
    required this.toTasteLabel,
  });

  final RecipeIngredient line;
  final String amount;
  final String name;
  final String note;
  final bool flash;
  final bool hasGuide;
  final String learnMoreLabel;
  final VoidCallback onLearnMore;
  final String optionalLabel;
  final String toTasteLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = context.reduceMotion;
    final stacked = context.largeText;
    final shownAmount = amount.isEmpty ? toTasteLabel : amount;
    final amountText = Text(
      shownAmount,
      style: AppText.mono(size: 12.5, color: amount.isEmpty ? Palette.inkFaint : Palette.ink, weight: FontWeight.w500),
    );
    final nameText = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: name, style: AppText.serif(size: 16.5, height: 1.3)),
          if (note.isNotEmpty)
            TextSpan(
              text: ', $note',
              style: AppText.serifItalic(size: 14.5, color: Palette.inkSoft),
            ),
          if (line.optional) TextSpan(text: '  ($optionalLabel)', style: AppText.mono(size: 11)),
        ],
      ),
    );
    Widget row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.paperDeep)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // At large text the amount moves above the name, so neither has to squeeze the other.
          if (!stacked) SizedBox(width: 86, child: amountText),
          Expanded(
            child: stacked
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [amountText, nameText])
                : nameText,
          ),
          if (hasGuide)
            Semantics(
              button: true,
              label: '$learnMoreLabel: $name',
              excludeSemantics: true,
              child: InkResponse(
                onTap: onLearnMore,
                radius: 22,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.info_outline, size: 19, color: Palette.teal),
                ),
              ),
            ),
        ],
      ),
    );
    if (flash && !reduce) {
      row = row
          .animate()
          .custom(
            duration: 1100.ms,
            curve: Curves.easeOut,
            builder: (context, value, child) => DecoratedBox(
              decoration: BoxDecoration(color: Palette.mustard.withValues(alpha: 0.42 * (1 - value))),
              child: child,
            ),
          )
          .fadeIn(duration: 260.ms)
          .slideX(begin: 0.03, end: 0, duration: 300.ms, curve: Curves.easeOut);
    }
    return row;
  }
}
