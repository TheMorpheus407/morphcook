import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../domain/search/search_service.dart';
import '../../widgets/paper.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper_controls.dart';

/// All tag filters in one sheet: meal, diet, effort, time, cuisine, mood and
/// technique. Returns the new filters, or `null` when dismissed.
Future<SearchFilters?> showFilterSheet(BuildContext context, SearchFilters current) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.paperLight,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (context) => _FilterSheet(initial: current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SearchFilters _filters = widget.initial;

  bool _isSelected(String kind, String value) => switch (kind) {
    'meal' => _filters.meals.contains(value),
    'cuisine' => _filters.cuisines.contains(value),
    _ => _filters.attributes.contains(value),
  };

  void _toggle(String kind, String value) {
    Set<String> flip(Set<String> set) {
      final next = {...set};
      if (!next.remove(value)) next.add(value);
      return next;
    }

    setState(() {
      switch (kind) {
        case 'meal':
          _filters = _filters.copyWith(meals: flip(_filters.meals));
        case 'cuisine':
          _filters = _filters.copyWith(cuisines: flip(_filters.cuisines));
        default:
          _filters = _filters.copyWith(attributes: flip(_filters.attributes));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    return PaperBackground(
      color: Palette.paperLight,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 8, 0),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Palette.rule, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: Text(s('search.filters'), style: AppText.display(size: 30))),
                      PaperIconButton(
                        icon: Icons.close,
                        tooltip: s('common.close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                shrinkWrap: true,
                children: [
                  for (final group in ontology.filterGroups)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoLabel(group.name.resolve(s.lang)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              for (final value in group.values)
                                PaperChip(
                                  label: ontology.label(value, s.lang),
                                  style: PaperChipStyle.mono,
                                  selected: _isSelected(group.kind, value),
                                  onTap: () => _toggle(group.kind, value),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
              child: ButtonRow(
                children: [
                  PaperButton(
                    label: s('search.clearFilters'),
                    style: PaperButtonStyle.quiet,
                    onPressed: _filters.isEmpty ? null : () => setState(() => _filters = const SearchFilters()),
                  ),
                  PaperButton(
                    label: s('search.apply'),
                    icon: Icons.check,
                    onPressed: () => Navigator.of(context).pop(_filters),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
