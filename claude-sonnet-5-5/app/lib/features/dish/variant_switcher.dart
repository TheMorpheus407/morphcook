import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/ontology.dart';
import '../../data/models/recipe.dart';
import '../../domain/variants.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';

/// Per-dimension variant switchers: one row per dimension (diet, effort,
/// calorie level, any future axis), collapsed to the current value; tapping a
/// row reveals its alternatives. Combinations that do not exist stay visible,
/// disabled, with a note.
class VariantSwitcher extends StatelessWidget {
  const VariantSwitcher({
    super.key,
    required this.resolver,
    required this.selection,
    required this.recipe,
    required this.expandedAxis,
    required this.onToggle,
    required this.onSelect,
    required this.ontology,
  });

  final VariantResolver resolver;
  final Map<String, String> selection;

  /// The variant the current selection resolves to.
  final Recipe recipe;
  final String? expandedAxis;
  final ValueChanged<String> onToggle;
  final void Function(String axisId, String value) onSelect;
  final Ontology ontology;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Column(
      children: [
        for (final axis in resolver.axes(selection))
          _AxisRow(
            axis: axis,
            expanded: expandedAxis == axis.dimension.id,
            recipe: recipe,
            resolver: resolver,
            selection: selection,
            ontology: ontology,
            s: s,
            onToggle: () => onToggle(axis.dimension.id),
            onSelect: (value) => onSelect(axis.dimension.id, value),
          ),
      ],
    );
  }
}

class _AxisRow extends StatelessWidget {
  const _AxisRow({
    required this.axis,
    required this.expanded,
    required this.recipe,
    required this.resolver,
    required this.selection,
    required this.ontology,
    required this.s,
    required this.onToggle,
    required this.onSelect,
  });

  final AxisView axis;
  final bool expanded;
  final Recipe recipe;
  final VariantResolver resolver;
  final Map<String, String> selection;
  final Ontology ontology;
  final AppStrings s;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  String _valueLabel() {
    final dimension = axis.dimension;
    if (dimension.showsApproxCalories) return '~${roundKcal(recipe.caloriesPerServing)}';
    final value = axis.selected;
    return value == null ? '–' : ontology.label(value, s.lang);
  }

  String _optionLabel(AxisOption option) => ontology.label(option.value, s.lang);

  String? _note(AxisOption option) {
    if (option.enabled) return null;
    if (option.conflictValue != null) {
      return s('variant.noCombo', {'a': _optionLabel(option), 'b': ontology.label(option.conflictValue!, s.lang)});
    }
    return s('variant.noComboGeneric', {'a': _optionLabel(option)});
  }

  @override
  Widget build(BuildContext context) {
    final dimension = axis.dimension;
    final label = dimension.name.resolve(s.lang);
    final value = _valueLabel();
    final canOpen = axis.hasAlternatives;
    final disabledNotes = [
      for (final o in axis.options)
        if (_note(o) != null) _note(o)!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: canOpen,
          expanded: canOpen ? expanded : null,
          label: canOpen
              ? s('variant.rowSemantics', {'axis': label, 'value': value})
              : s('variant.rowOnly', {'axis': label, 'value': value}),
          excludeSemantics: true,
          child: InkWell(
            onTap: canOpen ? onToggle : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              // Label and value each take at most 40 percent of the row and wrap
              // inside that, so large text never pushes the row past its edge.
              child: LayoutBuilder(
                builder: (context, box) => Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.4),
                      child: Text('— ${label.toUpperCase()}', style: AppText.label(size: 10.5, color: Palette.inkSoft)),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: DashedRule(color: Palette.rule, dash: 2, gap: 5)),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.4),
                      child: AnimatedSwitcher(
                        duration: context.motion(const Duration(milliseconds: 220)),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
                            child: child,
                          ),
                        ),
                        child: FittedBox(
                          key: ValueKey('$label-$value'),
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(value, style: AppText.display(size: 23, color: Palette.ink)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (canOpen)
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: context.motion(const Duration(milliseconds: 200)),
                        child: const Icon(Icons.keyboard_arrow_down, size: 24, color: Palette.ink),
                      )
                    else
                      const SizedBox(width: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
        MotionSize(
          child: expanded && canOpen
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          for (final option in axis.options)
                            PaperChip(
                              label: _optionLabel(option),
                              selected: option.selected,
                              enabled: option.enabled,
                              semanticHint: _note(option),
                              onTap: () => onSelect(option.value),
                              onDisabledTap: () => ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  SnackBar(content: Text(_note(option) ?? ''), duration: const Duration(seconds: 3)),
                                ),
                            ),
                        ],
                      ),
                      if (disabledNotes.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        for (final note in disabledNotes.take(3))
                          HandNote(note, size: 19, color: Palette.inkSoft, angle: -0.01),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
