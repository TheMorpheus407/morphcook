import 'package:flutter/material.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/ingredient.dart';
import '../../data/models/ontology.dart';
import '../../data/models/profile.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';

/// The profile as a taped index card: what the cookbook will do for this person.
class ProfileSummary extends StatelessWidget {
  const ProfileSummary({
    super.key,
    required this.profile,
    required this.ontology,
    required this.dictionary,
    this.onEdit,
  });

  final Profile profile;
  final Ontology ontology;
  final IngredientDictionary dictionary;

  /// Called with the onboarding step that edits a row: 0 language, 1 name, 2 diet, 3 pace.
  final ValueChanged<int>? onEdit;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final diets = profile.avoidFlags.where(ontology.isCompound).map((id) => ontology.label(id, s.lang)).toList();
    final avoids = profile.avoidFlags
        .where((id) => !ontology.isCompound(id))
        .map((id) => ontology.label(id, s.lang))
        .toList();
    final ingredients = profile.avoidIngredients.map((id) => dictionary.nameOf(id, s.lang)).toList()..sort();
    final required = profile.requiredAttributes.map((id) => ontology.label(id, s.lang)).toList();
    final language = ontology.languages
        .firstWhere((l) => l.code == profile.lang, orElse: () => ontology.languages.first)
        .name;

    final rows = <_Row>[
      _Row(s('profile.summary.language'), [language], 0),
      _Row(s('profile.summary.name'), profile.name.isEmpty ? [s('profile.summary.noName')] : [profile.name], 1),
      _Row(s('profile.summary.eats'), diets.isEmpty ? [s('profile.summary.everything')] : diets, 2),
      _Row(
        s('profile.summary.skips'),
        [...avoids, ...ingredients].isEmpty ? [s('profile.summary.nothing')] : [...avoids, ...ingredients],
        2,
      ),
      if (required.isNotEmpty) _Row(s('profile.summary.mustBe'), required, 2),
      _Row(s('profile.summary.calories'), [
        profile.calorieTarget == null
            ? s('profile.summary.noTarget')
            : '~${profile.calorieTarget} kcal  ± ${profile.calorieTolerance}',
      ], 3),
      _Row(s('profile.summary.time'), [
        profile.maxTimeMinutes == null
            ? s('profile.noLimit')
            : s('profile.summary.upTo', {'time': s.minutes(profile.maxTimeMinutes!)}),
      ], 3),
      _Row(s('profile.summary.effort'), [ontology.label(profile.preferredEffort, s.lang)], 3),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(18, 22, 12, 12),
          decoration: BoxDecoration(
            color: Palette.paperLight,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: Palette.paperEdge),
            boxShadow: [
              BoxShadow(color: Palette.ink.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                _SummaryRow(
                  row: rows[i],
                  onEdit: onEdit == null ? null : () => onEdit!(rows[i].step),
                  editLabel: s('common.edit'),
                ),
                if (i < rows.length - 1) const DashedRule(),
              ],
            ],
          ),
        ),
        const Positioned(top: 0, left: 0, right: 0, child: Center(child: TapeStrip(width: 72))),
      ],
    );
  }
}

class _Row {
  const _Row(this.label, this.values, this.step);
  final String label;
  final List<String> values;
  final int step;
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.row, required this.onEdit, required this.editLabel});

  final _Row row;
  final VoidCallback? onEdit;
  final String editLabel;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Padding(padding: const EdgeInsets.only(top: 4), child: MonoLabel(row.label)),
            ),
            Expanded(child: Text(row.values.join(' · '), style: AppText.serifItalic(size: 17, height: 1.3))),
            if (onEdit != null)
              Semantics(
                button: true,
                label: '$editLabel ${row.label}',
                excludeSemantics: true,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8, top: 3),
                  child: Icon(Icons.edit_outlined, size: 16, color: Palette.inkFaint),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
