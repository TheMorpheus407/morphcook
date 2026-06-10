import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../models/dish.dart';
import '../../models/ontology.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';

/// One collapsible row per variant dimension (diet, effort, calorie…). Collapsed
/// shows your current variant; tapping reveals the alternatives as chips.
/// Unreachable combinations are disabled with a note, never hidden.
class VariantSwitcher extends StatefulWidget {
  const VariantSwitcher({
    super.key,
    required this.dish,
    required this.variants,
    required this.selected,
    required this.ignoreCalories,
    required this.onSelect,
    required this.onToggleCalorieOverride,
  });

  final Dish dish;
  final List<Recipe> variants;
  final Recipe selected;
  final bool ignoreCalories;
  final ValueChanged<Recipe> onSelect;
  final ValueChanged<bool> onToggleCalorieOverride;

  @override
  State<VariantSwitcher> createState() => _VariantSwitcherState();
}

class _VariantSwitcherState extends State<VariantSwitcher> {
  final Set<String> _expanded = {};

  /// Axes present across this dish's variants, in ontology order.
  List<VariantAxis> get _axes {
    final present = <String>{};
    for (final r in widget.variants) {
      present.addAll(r.variantAxes.keys);
    }
    return context.scope.corpus.ontology.variantAxes
        .where((a) => present.contains(a.id))
        .toList();
  }

  /// Distinct values for an axis across variants, ordered by the ontology.
  List<String> _valuesFor(VariantAxis axis) {
    final ontologyOrder = <String>[];
    if (axis.valuesFrom == 'effort') {
      ontologyOrder.addAll(context.scope.corpus.ontology.effort.map((e) => e.id));
    } else if (axis.valuesFrom == 'calorie_bucket') {
      ontologyOrder
          .addAll(context.scope.corpus.ontology.calorieBuckets.map((e) => e.id));
    } else {
      ontologyOrder.addAll(axis.values.map((v) => v.id));
    }
    final present =
        widget.variants.map((r) => r.variantAxes[axis.id]).whereType<String>().toSet();
    final ordered = ontologyOrder.where(present.contains).toList();
    // include any present value not in ontology order (defensive)
    for (final v in present) {
      if (!ordered.contains(v)) ordered.add(v);
    }
    return ordered;
  }

  /// The recipe you'd land on by choosing [value] on [axis], keeping the other
  /// currently-selected axes fixed. Null when that combination doesn't exist.
  Recipe? _targetFor(String axisId, String value) {
    final sel = widget.selected.variantAxes;
    final candidates = widget.variants.where((r) {
      if (r.variantAxes[axisId] != value) return false;
      for (final entry in sel.entries) {
        if (entry.key == axisId) continue;
        if (r.variantAxes[entry.key] != entry.value) return false;
      }
      return true;
    }).toList();
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.scope.services.profile.profile;
    final matcher = context.scope.matcherFor(profile);
    final showCalorieOverride =
        profile.calorieFilterEnabled && profile.calorieTarget != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Column(
        children: [
          for (final axis in _axes)
            _axisRow(axis, matcher: matcher),
          if (showCalorieOverride) ...[
            const SizedBox(height: 6),
            _calorieOverrideRow(),
          ],
        ],
      ),
    );
  }

  Widget _axisRow(VariantAxis axis, {required matcher}) {
    final expanded = _expanded.contains(axis.id);
    final currentValue = widget.selected.variantAxes[axis.id] ?? '';
    final currentLabel =
        context.scope.corpus.axisValueLabel(axis.id, currentValue, context.lang);

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            expanded ? _expanded.remove(axis.id) : _expanded.add(axis.id);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                MonoLabel(context.loc(axis.label)),
                const SizedBox(width: 8),
                const Expanded(child: DashedRule()),
                const SizedBox(width: 8),
                Text(currentLabel,
                    style: const TextStyle(
                        fontFamily: Fonts.display,
                        fontStyle: FontStyle.italic,
                        fontSize: 18,
                        color: AppColors.ink)),
                const SizedBox(width: 4),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: AppColors.inkSoft),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in _valuesFor(axis))
                    _chip(axis, value, matcher),
                ],
              ),
            ),
          ),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: _dur,
        ),
      ],
    );
  }

  Widget _chip(VariantAxis axis, String value, matcher) {
    final selected = widget.selected.variantAxes[axis.id] == value;
    final target = _targetFor(axis.id, value);
    final exists = target != null;
    final fitsProfile = exists &&
        matcher.isVisible(target, ignoreCalories: widget.ignoreCalories);
    final label =
        context.scope.corpus.axisValueLabel(axis.id, value, context.lang);

    final Color border;
    final Color text;
    if (selected) {
      border = AppColors.terracotta;
      text = AppColors.terracotta;
    } else if (!exists) {
      border = AppColors.inkFaint.withValues(alpha: 0.4);
      text = AppColors.inkFaint;
    } else {
      border = AppColors.inkSoft;
      text = AppColors.ink;
    }

    return Tooltip(
      message: !exists
          ? context.tr('dish.no_combo')
          : (!fitsProfile ? context.tr('dish.variant_unavailable') : label),
      child: GestureDetector(
        onTap: exists && !selected ? () => widget.onSelect(target) : null,
        child: AnimatedContainer(
          duration: _dur,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.terracotta.withValues(alpha: 0.10) : null,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.circle, size: 7, color: AppColors.terracotta),
                ),
              Text(label,
                  style: TextStyle(
                    fontFamily: Fonts.mono,
                    fontSize: 13,
                    color: text,
                    decoration:
                        !exists ? TextDecoration.lineThrough : TextDecoration.none,
                  )),
              if (exists && !fitsProfile && !selected)
                const Padding(
                  padding: EdgeInsets.only(left: 5),
                  child: Icon(Icons.info_outline, size: 13, color: AppColors.dustyBlue),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calorieOverrideRow() {
    return Row(
      children: [
        const Icon(Icons.tune, size: 16, color: AppColors.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(context.tr('dish.show_outside_calories'),
              style: const TextStyle(
                  fontFamily: Fonts.mono, fontSize: 12, color: AppColors.inkSoft)),
        ),
        Switch(
          value: widget.ignoreCalories,
          activeThumbColor: AppColors.terracotta,
          onChanged: widget.onToggleCalorieOverride,
        ),
      ],
    );
  }

  Duration get _dur {
    final reduce = context.scope.services.profile.profile.reduceMotion ??
        MediaQuery.maybeOf(context)?.disableAnimations ??
        false;
    return reduce ? Duration.zero : const Duration(milliseconds: 240);
  }
}
