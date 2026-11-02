import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/chips.dart';
import '../../design/widgets/rules.dart';
import '../../domain/variant_switcher.dart';
import '../../l10n/strings.dart';
import '../../models/ontology.dart';
import '../../models/profile.dart';
import '../../models/recipe.dart';

/// The per-dimension variant switcher.
///
/// Each row is one axis — diet, effort, calorie level. Collapsed, a row
/// shows only the currently selected value. Tapping a row opens it and
/// reveals the alternatives. Combinations that have no recipe are shown
/// disabled, with a note — never hidden.
class VariantSwitcherPanel extends StatefulWidget {
  const VariantSwitcherPanel({
    required this.variants,
    required this.profile,
    required this.strings,
    required this.onChanged,
    super.key,
    this.ontology,
    this.enabledValues = const <String, Set<String>>{},
  });

  /// Every variant of the dish.
  final List<Recipe> variants;

  final Profile profile;

  /// The taxonomy — it tells the panel every value a dimension could have,
  /// so an unreachable one can be shown disabled instead of hidden.
  final Ontology? ontology;

  final Strings strings;

  /// Called with the newly selected recipe whenever the selection changes.
  final ValueChanged<Recipe> onChanged;

  /// Values that exist as a recipe but are outside the user's filters.
  /// They are shown as available-but-restricted rather than disabled.
  final Map<String, Set<String>> enabledValues;

  @override
  State<VariantSwitcherPanel> createState() => _VariantSwitcherPanelState();
}

class _VariantSwitcherPanelState extends State<VariantSwitcherPanel> {
  late VariantSwitcher _switcher;
  Map<String, String> _selection = <String, String>{};
  final Set<String> _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _rebuild(switcher: true);
  }

  @override
  void didUpdateWidget(covariant VariantSwitcherPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variants.length != widget.variants.length) {
      _rebuild(switcher: true);
    }
  }

  void _rebuild({bool switcher = false}) {
    _switcher = VariantSwitcher(
      variants: widget.variants,
      profile: widget.profile,
      ontology: widget.ontology,
    );
    if (switcher) {
      _selection = _switcher.defaultSelection();
      _expanded.clear();
    }
  }

  void _select(String dimensionId, String valueId) {
    final next = _switcher.select(dimensionId, valueId, _selection);
    setState(() => _selection = next);
    final recipe = _switcher.resolve(next);
    if (recipe != null) {
      HapticFeedback.selectionClick();
      widget.onChanged(recipe);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dimensions = _switcher.dimensions;
    if (dimensions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final dimension in dimensions)
          _DimensionRow(
            dimensionId: dimension,
            label: _labelFor(dimension),
            valueLabel: _valueLabel(dimension, _selection[dimension] ?? ''),
            options: _switcher.optionsFor(dimension, _selection),
            expanded: _expanded.contains(dimension),
            strings: widget.strings,
            onToggle: () {
              setState(() {
                if (!_expanded.remove(dimension)) _expanded.add(dimension);
              });
            },
            onSelect: (value) => _select(dimension, value),
          ),
      ],
    );
  }

  String _labelFor(String dimension) {
    switch (dimension) {
      case 'diet':
        return widget.strings.dimensionDiet;
      case 'effort':
        return widget.strings.dimensionEffort;
      case 'calorie_level':
        return widget.strings.dimensionCalorie;
      default:
        return dimension.replaceAll('_', ' ');
    }
  }

  String _valueLabel(String dimension, String value) {
    switch (dimension) {
      case 'diet':
        return widget.strings.dietLabel(value);
      case 'effort':
        return widget.strings.effortLabel(value);
      case 'calorie_level':
        return widget.strings.calorieBucketLabel(value);
      default:
        return value;
    }
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.dimensionId,
    required this.label,
    required this.valueLabel,
    required this.options,
    required this.expanded,
    required this.strings,
    required this.onToggle,
    required this.onSelect,
  });

  final String dimensionId;
  final String label;
  final String valueLabel;
  final List<DimensionOption> options;
  final bool expanded;
  final Strings strings;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final duration = MotionScope.dur(context, Motion.fast);
    final selected = options.where((option) => option.selected).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  Text('— $label ', style: Type.label(size: 10)),
                  const Expanded(child: DashedRule()),
                  const SizedBox(width: 12),
                  Text(
                    valueLabel,
                    style: Type.label(size: 10, weight: FontWeight.w700, color: MC.ink),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: duration,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: MC.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        for (final option in options)
                          VariantChip(
                            label: _chipLabel(option),
                            selected: option.selected,
                            enabled: option.enabled,
                            accent: MC.coral,
                            onTap: () => onSelect(option.valueId),
                            note: option.enabled ? null : _noteFor(option),
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          if (expanded && selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                strings.dishNotForYou,
                style: Type.scriptSmall(size: 14),
              ),
            ),
        ],
      ),
    );
  }

  String _chipLabel(DimensionOption option) {
    switch (option.dimensionId) {
      case 'diet':
        return strings.dietLabel(option.valueId);
      case 'effort':
        return strings.effortLabel(option.valueId);
      case 'calorie_level':
        return strings.calorieBucketLabel(option.valueId);
      default:
        return option.valueId;
    }
  }

  String? _noteFor(DimensionOption option) {
    if (option.conflicts.isEmpty) return null;
    final parts = <String>[];
    option.conflicts.forEach((dimension, value) {
      switch (dimension) {
        case 'diet':
          parts.add(strings.dietLabel(value));
        case 'effort':
          parts.add(strings.effortLabel(value));
        default:
          parts.add(value);
      }
    });
    if (parts.isEmpty) return null;
    return strings.dishNoVariantYet(
      parts.join(' × '),
      _chipLabel(option),
    );
  }
}
