import 'package:flutter/material.dart';

import '../core/palette.dart';
import '../core/paper.dart';

/// One selectable option in a dimension.
class VariantOption {
  const VariantOption({
    required this.key,
    required this.label,
    this.selected = false,
    this.enabled = true,
    this.note,
  });

  final String key;
  final String label;
  final bool selected;
  final bool enabled;

  /// Why this option is unreachable given current selections
  /// (e.g. "no vegan × pro version yet").
  final String? note;
}

/// One dimension row (diet, effort, calorie level, …).
class VariantDimension {
  const VariantDimension({
    required this.key,
    required this.label,
    required this.options,
  });

  final String key;
  final String label;
  final List<VariantOption> options;
}

/// The per-dimension variant switcher.
/// Rows are collapsed by default, showing only the currently-selected
/// variant. Tapping a chevron reveals alternative chips. Unreachable
/// combinations are disabled with a note, never hidden.
class VariantSwitcher extends StatefulWidget {
  const VariantSwitcher({
    super.key,
    required this.dimensions,
    required this.onSelect,
    this.dark = false,
  });

  final List<VariantDimension> dimensions;
  final void Function(String dimensionKey, String optionKey) onSelect;
  final bool dark;

  @override
  State<VariantSwitcher> createState() => _VariantSwitcherState();
}

class _VariantSwitcherState extends State<VariantSwitcher> {
  final Set<String> _expanded = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final d in widget.dimensions) _row(context, d),
      ],
    );
  }

  Widget _row(BuildContext context, VariantDimension d) {
    final ink = widget.dark ? MC.nightInk : MC.ink;
    final rule = widget.dark ? MC.nightRule : MC.rule;
    final expanded = _expanded.contains(d.key);
    final selected = d.options.where((o) => o.selected).firstOrNull;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expanded.remove(d.key);
            } else {
              _expanded.add(d.key);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Text(
                  d.label,
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: ink,
                  ),
                ),
                const Spacer(),
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          selected?.label ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.dark ? MC.flashCoral : MC.coralDeep,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: widget.dark ? MC.inkFaint : MC.inkSoft,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final o in d.options) _chip(context, d, o),
                        ],
                      ),
                      // Notes for disabled options
                      for (final o in d.options)
                        if (!o.enabled && o.note != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              o.note!,
                              style: TextStyle(
                                fontFamily: 'Caveat',
                                fontSize: 15,
                                color: widget.dark ? MC.inkFaint : MC.inkSoft,
                              ),
                            ),
                          ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        CustomPaint(
          painter: DashedRulePainter(color: rule),
          size: const Size(double.infinity, 1),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, VariantDimension d, VariantOption o) {
    final card = widget.dark ? MC.nightRaised : MC.card;
    final ink = widget.dark ? MC.nightInk : MC.ink;
    return Opacity(
      opacity: o.enabled ? 1 : 0.45,
      child: InkWell(
        onTap: o.enabled
            ? () => widget.onSelect(d.key, o.key)
            : o.note == null
                ? null
                : () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(o.note!)),
                    ),
        borderRadius: BorderRadius.circular(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: o.selected ? ink : card,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: o.selected ? ink : (widget.dark ? MC.nightRule : MC.rule),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (o.selected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: o.selected ? MC.flashCoral : Colors.transparent,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                o.label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: o.selected
                      ? (widget.dark ? MC.night : MC.card)
                      : ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
