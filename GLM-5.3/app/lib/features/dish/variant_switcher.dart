import 'package:flutter/material.dart';

import '../../core/matching/variant_matrix.dart';
import '../../core/models/ontology.dart';
import '../../core/models/recipe.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';

/// Which dimension a switcher row represents.
enum VariantDimension { diet, effort, calorie }

/// The per-dimension variant switcher (SPEC): one row per dimension,
/// collapsed by default showing only the selected variant; tap reveals the
/// chips; unreachable combinations are disabled with a note, not hidden.
class VariantSwitcher extends StatefulWidget {
  const VariantSwitcher({
    super.key,
    required this.matrix,
    required this.selected,
    required this.ontology,
    required this.lang,
    required this.labels,
    required this.onSelect,
    this.disabledReason,
    this.reduceMotion = false,
  });

  final VariantMatrix matrix;
  final Recipe selected;
  final Ontology ontology;
  final String lang;

  /// Localized row labels, keyed by dimension.
  final Map<VariantDimension, String> labels;

  final void Function(VariantDimension dimension, String value) onSelect;

  /// Optional per-value reason it is off-limits for this profile (e.g.
  /// "contains dairy") — chips with a reason render disabled with the note.
  final String? Function(String value, VariantDimension dim)? disabledReason;

  final bool reduceMotion;

  @override
  State<VariantSwitcher> createState() => _VariantSwitcherState();
}

class _VariantSwitcherState extends State<VariantSwitcher> {
  VariantDimension? _expanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(VariantDimension.diet),
        _row(VariantDimension.effort),
        _row(VariantDimension.calorie),
      ],
    );
  }

  List<String> _valuesFor(VariantDimension dim) {
    switch (dim) {
      case VariantDimension.diet:
        return widget.matrix.diets;
      case VariantDimension.effort:
        return widget.matrix.efforts;
      case VariantDimension.calorie:
        return widget.matrix.calorieBuckets;
    }
  }

  String _selectedFor(VariantDimension dim) {
    switch (dim) {
      case VariantDimension.diet:
        return widget.selected.diet;
      case VariantDimension.effort:
        return widget.selected.effort;
      case VariantDimension.calorie:
        return widget.selected.calorieBucket;
    }
  }

  bool _reachable(VariantDimension dim, String value) {
    switch (dim) {
      case VariantDimension.diet:
        return widget.matrix
            .dietReachable(value, widget.selected.effort, widget.selected.calorieBucket);
      case VariantDimension.effort:
        return widget.matrix
            .effortReachable(value, widget.selected.diet, widget.selected.calorieBucket);
      case VariantDimension.calorie:
        return widget.matrix
            .calorieReachable(value, widget.selected.diet, widget.selected.effort);
    }
  }

  String _labelFor(VariantDimension dim, String value) {
    if (dim == VariantDimension.calorie) {
      // Approximate calories of the variant that combination resolves to.
      final recipe =
          widget.matrix.resolve(widget.selected.diet, widget.selected.effort, value);
      if (recipe != null) return '~${recipe.cal}';
      return widget.ontology.attrLabel(value, widget.lang);
    }
    return widget.ontology.attrLabel(value, widget.lang);
  }
  Widget _row(VariantDimension dim) {
    final expanded = _expanded == dim;
    final selectedValue = _selectedFor(dim);
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = expanded ? null : dim),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Text(
                  '— ${widget.labels[dim]} —',
                  style: AppFonts.mono(size: 11, color: AppColors.inkSoft),
                ),
                Expanded(child: _flexDashes()),
                Text(
                  _labelFor(dim, selectedValue),
                  style: AppFonts.mono(size: 13, color: AppColors.teal, weight: FontWeight.w700),
                ),
                const SizedBox(width: 6),
                Icon(
                  expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: AppColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration:
              widget.reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final value in _valuesFor(dim))
                          _chip(dim, value, value == selectedValue),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _flexDashes() {
    return LayoutBuilder(builder: (context, constraints) {
      const dash = 5.0;
      const gap = 4.0;
      final count = (constraints.maxWidth / (dash + gap)).floor();
      return Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            Container(width: dash, height: 1, color: AppColors.inkFaint),
            const SizedBox(width: gap),
          ],
        ],
      );
    });
  }

  Widget _chip(VariantDimension dim, String value, bool selected) {
    final reachable = _reachable(dim, value);
    final profileReason = widget.disabledReason?.call(value, dim);
    final enabled = reachable && profileReason == null;
    final reason = !reachable ? _unreachableNote(dim, value) : profileReason ?? '';
    return SelectablePill(
      label: _labelFor(dim, value),
      selected: selected,
      enabled: enabled,
      note: reason,
      onTap: enabled ? () => widget.onSelect(dim, value) : null,
    );
  }

  /// "no vegan × hard version yet" — the SPEC's exact note shape.
  String _unreachableNote(VariantDimension dim, String value) {
    final label = _labelFor(dim, value);
    final other = dim == VariantDimension.diet
        ? widget.ontology.attrLabel(widget.selected.effort, widget.lang)
        : widget.ontology.attrLabel(widget.selected.diet, widget.lang);
    if (widget.lang == 'de') return 'noch keine $label × $other version';
    return 'no $label × $other version yet';
  }
}
