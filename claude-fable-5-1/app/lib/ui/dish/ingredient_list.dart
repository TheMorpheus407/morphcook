import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../data/models/recipe.dart';
import '../../domain/shopping_aggregator.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../widgets/ingredient_guide_sheet.dart';
import '../widgets/meta.dart';

/// Ingredient rows that morph when the variant changes: new or changed
/// lines fade in with a highlight flash; unchanged lines stay put.
class IngredientList extends StatelessWidget {
  const IngredientList({super.key, required this.recipe, this.previous, this.scale = 1.0, this.dark = false});
  final Recipe recipe;
  final Recipe? previous;
  final double scale;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = context.lang;
    final s = context.s;
    final meta = RecipeMeta(app, lang);
    final prevById = {for (final i in previous?.ingredients ?? const <RecipeIngredient>[]) i.id: i};
    final reduced = Motion.reduced(context);
    final ink = dark ? Palette.nightInk : Palette.ink;
    final soft = dark ? Palette.nightInkSoft : Palette.inkSoft;
    final faint = dark ? Palette.nightInkFaint : Palette.inkFaint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < recipe.ingredients.length; i++)
          _row(context, recipe.ingredients[i], prevById[recipe.ingredients[i].id], i, meta, s, lang, reduced, ink, soft, faint),
      ],
    );
  }

  Widget _row(BuildContext context, RecipeIngredient ing, RecipeIngredient? prev, int index, RecipeMeta meta, dynamic s, String lang, bool reduced, Color ink, Color soft, Color faint) {
    final app = meta.app;
    final changed = previous != null && (prev == null || prev.amount != ing.amount || prev.unit != ing.unit);
    final amount = ing.amount == null ? '' : formatAmount(ing.amount! * scale);
    final unit = ing.unit == 'to-taste' ? s('list.toTaste') : meta.unit(ing.unit);
    final name = ing.nameOverride?.of(lang) ?? meta.ingredient(ing.id);
    final note = ing.note.of(lang);
    final hasGuide = app.repo.guide[ing.id] != null;
    final avoided = app.matchContext.avoidIngredients.contains(ing.id);
    Widget row = InkWell(
      onTap: () => showIngredientGuide(context, ing.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 86,
              child: Text(
                [amount, unit].where((x) => x.isNotEmpty).join(' ').toLowerCase(),
                style: AppText.mono(color: soft, size: 12.5, weight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppText.body(color: avoided ? Palette.terracotta : ink, size: 15.5).copyWith(decoration: avoided ? TextDecoration.lineThrough : null),
                        ),
                      ),
                      if (changed) ...[
                        const SizedBox(width: 8),
                        MonoLabel(s('dish.changed'), color: Palette.terracotta, size: 9.5),
                      ],
                    ],
                  ),
                  if (note.isNotEmpty) HandNote(note, color: faint, size: 17),
                ],
              ),
            ),
            if (hasGuide)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 2),
                child: Icon(Icons.info_outline, size: 15, color: faint),
              ),
          ],
        ),
      ),
    );
    if (changed && !reduced) {
      row = TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOut,
        builder: (context, v, child) => DecoratedBox(
          decoration: BoxDecoration(color: Palette.mustard.withValues(alpha: 0.35 * v), borderRadius: BorderRadius.circular(3)),
          child: child,
        ),
        child: row,
      );
      row = row.animate().fadeIn(duration: 320.ms, delay: (index * 25).ms).slideY(begin: 0.08, end: 0, duration: 320.ms, curve: Curves.easeOut);
    }
    return Column(
      children: [
        row,
        DashedRule(color: dark ? Palette.nightRule : Palette.rule),
      ],
    );
  }
}
