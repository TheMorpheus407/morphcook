import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/text_scale.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/recipe.dart';
import '../../widgets/paper_controls.dart';

/// Calories and macros per serving, with each macro's share of the energy.
class MacrosView extends StatelessWidget {
  const MacrosView({super.key, required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final m = recipe.macros;
    final kcal = recipe.caloriesPerServing;
    final total = (m.protein * 4 + m.carbs * 4 + m.fat * 9);
    double share(double energy) => total == 0 ? 0 : energy / total;
    final rows = [
      (s('macros.protein'), m.protein, share(m.protein * 4), Palette.coral),
      (s('macros.carbs'), m.carbs, share(m.carbs * 4), Palette.mustard),
      (s('macros.fat'), m.fat, share(m.fat * 9), Palette.teal),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${roundKcal(kcal)}', style: AppText.display(size: 64)),
            const SizedBox(width: 10),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(s('macros.kcalPerServing'), style: AppText.mono(size: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final (label, grams, fraction, color) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              label: '$label: ${grams.round()} g, ${(fraction * 100).round()}%',
              excludeSemantics: true,
              child: context.largeText
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(label, style: AppText.serifItalic(size: 17))),
                            const SizedBox(width: 8),
                            Text(
                              '${grams.round()} g  ·  ${(fraction * 100).round()}%',
                              style: AppText.mono(size: 13, color: Palette.ink, weight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _bar(fraction, color),
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(width: 78, child: Text(label, style: AppText.serifItalic(size: 17))),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${grams.round()} g',
                            style: AppText.mono(size: 13, color: Palette.ink, weight: FontWeight.w500),
                          ),
                        ),
                        Expanded(child: _bar(fraction, color)),
                        SizedBox(
                          width: 46,
                          child: Text(
                            '${(fraction * 100).round()}%',
                            textAlign: TextAlign.right,
                            style: AppText.mono(size: 12),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        const SizedBox(height: 12),
        HandNote(s('macros.note'), size: 20, color: Palette.inkSoft),
      ],
    );
  }

  /// The share of the energy as a bar.
  Widget _bar(double fraction, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Stack(
        children: [
          Container(height: 10, color: Palette.paperDeep),
          FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(height: 10, color: color),
          ),
        ],
      ),
    );
  }
}
