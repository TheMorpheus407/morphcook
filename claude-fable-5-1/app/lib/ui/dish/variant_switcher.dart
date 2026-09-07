import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/recipe.dart';
import '../../domain/matching.dart';
import '../../domain/variant_lattice.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../widgets/meta.dart';

/// One collapsed row per dimension; tap to reveal the alternatives.
///
///   — diet ———————————————— vegan  ⌄
///   — effort ——————————————— easy  ⌄
///   — calorie level ———————— ~520  ⌄
class VariantSwitcher extends StatefulWidget {
  const VariantSwitcher({
    super.key,
    required this.lattice,
    required this.selection,
    required this.matchContext,
    required this.calorieOverride,
    required this.onSelect,
  });

  final VariantLattice lattice;
  final Map<String, String> selection;
  final MatchContext matchContext;
  final bool calorieOverride;
  final ValueChanged<Recipe> onSelect;

  @override
  State<VariantSwitcher> createState() => _VariantSwitcherState();
}

class _VariantSwitcherState extends State<VariantSwitcher> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final current = widget.lattice.recipeFor(widget.selection);
    return Column(
      children: [
        for (final dim in widget.lattice.dimensions)
          _DimensionRow(
            dimension: dim,
            label: widget.lattice.ontology.dimensionById[dim]?.label.of(lang) ?? dim,
            value: _valueLabel(dim, current, lang),
            open: _open == dim,
            onToggle: () => setState(() => _open = _open == dim ? null : dim),
            options: widget.lattice.optionsFor(dim, widget.selection, widget.matchContext, calorieOverride: widget.calorieOverride),
            lattice: widget.lattice,
            selection: widget.selection,
            onSelect: widget.onSelect,
          ),
      ],
    );
  }

  String _valueLabel(String dim, Recipe? r, String lang) {
    if (r == null) return '';
    if (dim == 'calorie_level') return '~${r.caloriesPerServing} kcal';
    return widget.lattice.labelOf(dim, r.variant[dim] ?? '').of(lang);
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimension,
    required this.label,
    required this.value,
    required this.open,
    required this.onToggle,
    required this.options,
    required this.lattice,
    required this.selection,
    required this.onSelect,
  });

  final String dimension;
  final String label;
  final String value;
  final bool open;
  final VoidCallback onToggle;
  final List<DimensionOption> options;
  final VariantLattice lattice;
  final Map<String, String> selection;
  final ValueChanged<Recipe> onSelect;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final lang = context.lang;
    final app = context.read<AppController>();
    final meta = RecipeMeta(app, lang);
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                MonoLabel('— $label', color: Palette.inkSoft),
                const SizedBox(width: 10),
                const Expanded(child: DashedRule()),
                const SizedBox(width: 10),
                Text(value.toLowerCase(), style: AppText.title(size: 16, italic: true)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: Motion.duration(context, const Duration(milliseconds: 180)),
                  child: const Icon(Icons.expand_more, size: 18, color: Palette.inkSoft),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.duration(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(0, 2, 0, 10),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in options) _chip(context, o, s, lang, meta),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, DimensionOption o, dynamic s, String lang, RecipeMeta meta) {
    var label = o.label.of(lang);
    if (dimension == 'calorie_level' && o.recipe != null) label = '$label · ~${o.recipe!.caloriesPerServing}';
    switch (o.state) {
      case OptionState.available:
        return PaperChip(label: label, selected: o.selected, onTap: () => onSelect(o.recipe!));
      case OptionState.conflicts:
        return PaperChip(
          label: label,
          selected: o.selected,
          muted: true,
          leading: const Icon(Icons.warning_amber_rounded, size: 13, color: Palette.mustard),
          onTap: () {
            onSelect(o.recipe!);
            final what = [
              ...o.conflictingFlags.map(meta.flag),
              ...o.conflictingIngredients.map(meta.ingredient),
            ].join(', ');
            if (what.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('dish.conflict', {'what': what}))));
            }
          },
        );
      case OptionState.outsideCalories:
        return PaperChip(
          label: label,
          selected: o.selected,
          disabled: true,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('dish.outsideCalories')))),
        );
      case OptionState.unreachable:
        final others = [
          for (final d in lattice.dimensions)
            if (d != dimension && d != 'calorie_level') lattice.labelOf(d, selection[d] ?? '').of(lang),
        ];
        final combo = [o.label.of(lang), ...others].join(' × ');
        return PaperChip(
          label: label,
          disabled: true,
          onTap: () {
            final alt = o.alternative;
            final altCombo = alt == null
                ? null
                : [
                    for (final d in lattice.dimensions)
                      if (d != 'calorie_level') lattice.labelOf(d, alt.variant[d] ?? '').of(lang),
                  ].join(' × ');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(s('dish.unreachable', {'combo': combo})),
              action: alt == null ? null : SnackBarAction(label: s('dish.unreachable.try', {'combo': altCombo!}), onPressed: () => onSelect(alt)),
            ));
          },
        );
    }
  }
}
