import 'package:flutter/material.dart';

import '../../localization/i18n.dart';
import '../../matching/matching.dart';
import '../../models/ingredient.dart';
import '../../models/ontology.dart';
import '../../models/profile.dart';
import '../../models/recipe.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/tag_chip.dart';

/// The "money shot" widget. Three collapsed rows by default — diet, effort,
/// calorie level — each showing only the currently-selected variant. Tap the
/// chevron to expand and reveal alternatives. Unreachable combos render as
/// disabled chips with a hairline tooltip.
class DimensionSwitcher extends StatefulWidget {
  final List<Recipe> variants;
  final Recipe current;
  final ValueChanged<Recipe> onSelect;
  final Profile profile;
  final Ontology ontology;
  final IngredientTree ingredients;
  final bool ignoreCalories;

  const DimensionSwitcher({
    super.key,
    required this.variants,
    required this.current,
    required this.onSelect,
    required this.profile,
    required this.ontology,
    required this.ingredients,
    required this.ignoreCalories,
  });

  @override
  State<DimensionSwitcher> createState() => _DimensionSwitcherState();
}

class _DimensionSwitcherState extends State<DimensionSwitcher> {
  final _expanded = <String, bool>{
    'diet': false,
    'effort': false,
    'calories': false,
  };

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final lang = widget.profile.lang;

    return Column(
      children: [
        _Row(
          axisLabel: s.diet,
          currentLabel: widget.current.variantLabel.resolve(lang),
          expanded: _expanded['diet']!,
          onToggle: () => setState(() => _expanded['diet'] = !_expanded['diet']!),
          chips: _buildDietChips(lang),
        ),
        const DashedRule(),
        _Row(
          axisLabel: s.effort,
          currentLabel: widget.current.effort,
          expanded: _expanded['effort']!,
          onToggle: () =>
              setState(() => _expanded['effort'] = !_expanded['effort']!),
          chips: _buildEffortChips(lang),
        ),
        const DashedRule(),
        _Row(
          axisLabel: s.calorieLevel,
          currentLabel: '~${widget.current.caloriesPerServing} kcal',
          expanded: _expanded['calories']!,
          onToggle: () =>
              setState(() => _expanded['calories'] = !_expanded['calories']!),
          chips: _buildCalorieChips(lang),
        ),
      ],
    );
  }

  List<Widget> _buildDietChips(String lang) {
    final out = <Widget>[];
    for (final v in widget.variants) {
      final visible = isVisible(
        v,
        widget.profile,
        ontology: widget.ontology,
        ingredients: widget.ingredients,
        ignoreCalorieFilter: widget.ignoreCalories,
      );
      out.add(
        TagChip(
          label: v.variantLabel.resolve(lang),
          selected: v.id == widget.current.id,
          accent: MCColors.coral,
          disabled: !visible && v.id != widget.current.id,
          onTap: () => widget.onSelect(v),
        ),
      );
    }
    return out;
  }

  List<Widget> _buildEffortChips(String lang) {
    final effortValues = const ['easy', 'medium', 'hard'];
    final out = <Widget>[];
    for (final eff in effortValues) {
      // pick a variant with this effort closest to current diet
      final candidate = widget.variants
          .where((v) => v.effort == eff)
          .toList()
        ..sort((a, b) {
          final pa = a.dietLabel == widget.current.dietLabel ? 0 : 1;
          final pb = b.dietLabel == widget.current.dietLabel ? 0 : 1;
          return pa.compareTo(pb);
        });
      if (candidate.isEmpty) {
        out.add(TagChip(label: eff, disabled: true, accent: MCColors.teal));
      } else {
        final visible = isVisible(
          candidate.first,
          widget.profile,
          ontology: widget.ontology,
          ingredients: widget.ingredients,
          ignoreCalorieFilter: widget.ignoreCalories,
        );
        out.add(TagChip(
          label: eff,
          selected: candidate.first.id == widget.current.id,
          accent: MCColors.teal,
          disabled: !visible,
          onTap: () => widget.onSelect(candidate.first),
        ));
      }
    }
    return out;
  }

  List<Widget> _buildCalorieChips(String lang) {
    final buckets = const ['≤400', '≤600', '≤800', '>800'];
    final out = <Widget>[];
    for (final b in buckets) {
      final candidate = widget.variants
          .where((v) => v.calorieBucket == b)
          .toList()
        ..sort((a, b) {
          final pa = a.dietLabel == widget.current.dietLabel ? 0 : 1;
          final pb = b.dietLabel == widget.current.dietLabel ? 0 : 1;
          return pa.compareTo(pb);
        });
      if (candidate.isEmpty) {
        out.add(TagChip(label: b, disabled: true, accent: MCColors.olive));
      } else {
        final visible = isVisible(
          candidate.first,
          widget.profile,
          ontology: widget.ontology,
          ingredients: widget.ingredients,
          ignoreCalorieFilter: widget.ignoreCalories,
        );
        out.add(TagChip(
          label: b,
          selected: candidate.first.id == widget.current.id,
          accent: MCColors.olive,
          disabled: !visible,
          onTap: () => widget.onSelect(candidate.first),
        ));
      }
    }
    return out;
  }
}

class _Row extends StatelessWidget {
  final String axisLabel;
  final String currentLabel;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> chips;

  const _Row({
    required this.axisLabel,
    required this.currentLabel,
    required this.expanded,
    required this.onToggle,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    '— ${axisLabel.toLowerCase()}',
                    style: MCTypography.eyebrow(),
                  ),
                ),
                Expanded(
                  child: Text(
                    currentLabel.toLowerCase(),
                    style: MCTypography.italic(size: 17),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  turns: expanded ? 0.5 : 0,
                  child: const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: MCColors.inkFaded),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
            ),
          ],
        ),
      ),
    );
  }
}
