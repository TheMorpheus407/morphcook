import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/models.dart';
import '../../l10n/strings.dart';
import '../../services/variant_matrix.dart';
import '../../state/app_state.dart';

/// One row per dimension, collapsed to the current selection. Tapping the
/// chevron reveals the alternatives; combinations nobody has written yet stay
/// visible and disabled, with a note saying so.
class VariantSwitcher extends StatefulWidget {
  const VariantSwitcher({
    super.key,
    required this.matrix,
    required this.current,
    required this.onSelect,
    required this.ignoreCalories,
    required this.onToggleCalories,
  });

  final VariantMatrix matrix;
  final Recipe current;
  final ValueChanged<Recipe> onSelect;
  final bool ignoreCalories;
  final ValueChanged<bool> onToggleCalories;

  @override
  State<VariantSwitcher> createState() => _VariantSwitcherState();
}

class _VariantSwitcherState extends State<VariantSwitcher> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    final rows = widget.matrix.rowsFor(
      widget.current,
      matcher: state.matcher,
      context: state.matchContext(ignoreCalorieTarget: widget.ignoreCalories),
      lang: s.lang,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.ink, width: 1.2),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colors.edge),
            _DimensionRow(
              row: rows[i],
              lang: s.lang,
              expanded: _expanded.contains(rows[i].dimension.id),
              onToggle: () => setState(() {
                final id = rows[i].dimension.id;
                _expanded.contains(id)
                    ? _expanded.remove(id)
                    : _expanded.add(id);
              }),
              onPick: (option) {
                final target = option.recipeId == null
                    ? null
                    : state.repository.recipe(option.recipeId!);
                if (target != null) widget.onSelect(target);
              },
            ),
          ],
          if (state.profile.hasCalorieTarget) ...[
            Divider(height: 1, color: colors.edge),
            _CalorieOverride(
              value: widget.ignoreCalories,
              onChanged: widget.onToggleCalories,
              s: s,
            ),
          ],
        ],
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  const _DimensionRow({
    required this.row,
    required this.lang,
    required this.expanded,
    required this.onToggle,
    required this.onPick,
  });

  final VariantRow row;
  final String lang;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<VariantOption> onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final s = S(lang);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: row.hasAlternatives ? onToggle : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
            child: Row(
              children: [
                Text('—', style: MorphType.numeric(colors.inkFaint, size: 12)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    row.dimension.label(lang).toLowerCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MorphType.eyebrow(colors.inkSoft),
                  ),
                ),
                const SizedBox(width: 10),
                // A minimum keeps the rule visible even when both labels are
                // long; the labels themselves ellipsise before it collapses.
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 8),
                    child: DashedRule(color: colors.edge),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  flex: 3,
                  child: Text(
                    row.selectedLabel(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: MorphType.numeric(
                      colors.ink,
                      size: 13,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: Motion.duration(context, MorphDurations.expand),
                  curve: Curves2.standard,
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: row.hasAlternatives ? colors.ink : colors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
        MotionSize(
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final option in row.options)
                            InkChip(
                              label: option.label(lang),
                              selected: option.selected,
                              enabled: option.reachable,
                              dense: true,
                              tooltip: option.reachable
                                  ? (option.hiddenByProfile
                                        ? s.dishHiddenByProfile
                                        : null)
                                  : s.dishUnreachable(
                                      row.dimension.label(lang),
                                      option.label(lang),
                                    ),
                              trailing: option.hiddenByProfile
                                  ? const Icon(Icons.visibility_off_outlined)
                                  : null,
                              onTap: () => onPick(option),
                            ),
                        ],
                      ),
                      if (row.options.any((o) => !o.reachable)) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${s.dishNoVariantYet} — ${row.options.where((o) => !o.reachable).map((o) => o.label(lang)).join(', ')}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        row.dimension.note(lang),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _CalorieOverride extends StatelessWidget {
  const _CalorieOverride({
    required this.value,
    required this.onChanged,
    required this.s,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final S s;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.dishOverrideCalories,
                  style: MorphType.numeric(colors.inkSoft, size: 11.5),
                ),
                Text(
                  s.dishOverrideCaloriesNote,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
