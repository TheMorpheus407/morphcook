import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../models/ingredient_tree.dart';
import '../../models/profile.dart';
import '../theme.dart';
import 'common.dart';
import 'paper.dart';

typedef ProfileChanged = void Function(Profile);

const calorieChoices = [null, 400, 500, 600, 700, 800];
const timeChoices = [15, 30, 45, 60, 90, null];
const toleranceChoices = [150, 250, 400];

/// Compound ways of eating: vegan, vegetarian, halal …
class DietChoicesEditor extends StatelessWidget {
  const DietChoicesEditor({super.key, required this.profile, required this.onChanged});
  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final onto = context.read<CorpusRepository>().ontology;
    final lang = context.lang;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final id in onto.dietChoices)
          InkChip(
            label: onto.flagLabel(id, lang),
            selected: profile.avoidFlags.contains(id),
            onTap: () {
              final next = {...profile.avoidFlags};
              next.contains(id) ? next.remove(id) : next.add(id);
              onChanged(profile.copyWith(avoidFlags: next));
            },
          ),
      ],
    );
  }
}

/// Class avoidance: "all dairy", "all nuts", "all shellfish" …
class ClassAvoidanceEditor extends StatelessWidget {
  const ClassAvoidanceEditor({super.key, required this.profile, required this.onChanged});
  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final onto = context.read<CorpusRepository>().ontology;
    final lang = context.lang;
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final id in onto.classAvoidance)
              SizedBox(
                width: w,
                child: InkWell(
                  onTap: () => _toggle(id),
                  child: Row(
                    children: [
                      Checkbox(
                        value: profile.avoidFlags.contains(id),
                        onChanged: (_) => _toggle(id),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Expanded(child: Text(onto.flagLabel(id, lang), style: MT.serif(15))),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _toggle(String id) {
    final next = {...profile.avoidFlags};
    next.contains(id) ? next.remove(id) : next.add(id);
    onChanged(profile.copyWith(avoidFlags: next));
  }
}

/// Specific avoidance: typeahead over the ingredient tree. Picking a parent
/// avoids all its children.
class IngredientAvoidPicker extends StatefulWidget {
  const IngredientAvoidPicker({super.key, required this.profile, required this.onChanged});
  final Profile profile;
  final ProfileChanged onChanged;

  @override
  State<IngredientAvoidPicker> createState() => _IngredientAvoidPickerState();
}

class _IngredientAvoidPickerState extends State<IngredientAvoidPicker> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<IngredientNode> _results = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _search(String q) {
    final tree = context.read<CorpusRepository>().ingredients;
    setState(() => _results = tree.search(q, context.trRead.lang));
  }

  void _add(IngredientNode n) {
    widget.onChanged(widget.profile.copyWith(avoidIngredients: {...widget.profile.avoidIngredients, n.id}));
    _ctrl.clear();
    setState(() => _results = const []);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final tree = context.read<CorpusRepository>().ingredients;
    final lang = tr.lang;
    final selected = widget.profile.avoidIngredients.toList()
      ..sort((a, b) => tree.name(a, lang).compareTo(tree.name(b, lang)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('avoid-search'),
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _search,
          style: MT.serif(16),
          decoration: InputDecoration(
            hintText: tr('avoid.search.hint'),
            prefixIcon: const Icon(Icons.search, size: 20, color: MC.inkSoft),
          ),
        ),
        if (_ctrl.text.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: MC.card,
              border: Border.all(color: MC.rule),
            ),
            child: _results.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(tr('avoid.nomatch'), style: MT.serif(14, color: MC.inkSoft)),
                  )
                : Column(
                    children: [
                      for (final n in _results)
                        InkWell(
                          onTap: () => _add(n),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.name.of(lang), style: MT.serif(15)),
                                      if (tree.pathOf(n.id).length > 1)
                                        Text(
                                          tree.pathOf(n.id).map((p) => p.name.of(lang)).join(' › '),
                                          style: MT.mono(10, color: MC.inkFaint),
                                        ),
                                    ],
                                  ),
                                ),
                                if (!tree.isLeaf(n.id))
                                  MonoLabel(tr('avoid.includes', {'n': tree.descendantsOf(n.id).length - 1}), size: 10),
                                const SizedBox(width: 6),
                                const Icon(Icons.add, size: 18, color: MC.inkSoft),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 10),
        if (selected.isEmpty)
          Text(tr('avoid.none'), style: MT.hand(19, color: MC.inkFaint))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in selected)
                InputChip(
                  label: Text(tree.name(id, lang), style: MT.mono(12, color: MC.ink)),
                  backgroundColor: MC.card,
                  side: const BorderSide(color: MC.rule),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  deleteIcon: const Icon(Icons.close, size: 15),
                  onDeleted: () => widget.onChanged(
                    widget.profile.copyWith(avoidIngredients: {...widget.profile.avoidIngredients}..remove(id)),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Calories, time budget, effort mood (+ tolerance when [showTolerance]).
class LimitsEditor extends StatelessWidget {
  const LimitsEditor({super.key, required this.profile, required this.onChanged, this.showTolerance = false});
  final Profile profile;
  final ProfileChanged onChanged;
  final bool showTolerance;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    Widget group(String label, List<Widget> chips) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        group(tr('limits.calories'), [
          for (final c in calorieChoices)
            InkChip(
              label: c == null ? tr('profile.notarget') : tr('profile.kcal', {'n': c}),
              selected: profile.calorieTarget == c,
              onTap: () => onChanged(profile.copyWith(calorieTarget: () => c)),
            ),
        ]),
        if (showTolerance && profile.calorieTarget != null)
          group(tr('limits.tolerance'), [
            for (final t in toleranceChoices)
              InkChip(
                label: tr('limits.tolerance.value', {'n': t}),
                selected: profile.calorieTolerance == t,
                onTap: () => onChanged(profile.copyWith(calorieTolerance: t)),
              ),
          ]),
        group(tr('limits.time'), [
          for (final m in timeChoices)
            InkChip(
              label: m == null ? tr('profile.nolimit') : tr('profile.minutes', {'n': m}),
              selected: profile.maxTimeMinutes == m,
              onTap: () => onChanged(profile.copyWith(maxTimeMinutes: () => m)),
            ),
        ]),
        group(tr('limits.effort'), [
          for (final e in Profile.efforts)
            InkChip(
              label: tr('effort.$e'),
              selected: profile.preferredEffort == e,
              onTap: () => onChanged(profile.copyWith(preferredEffort: e)),
            ),
        ]),
      ],
    );
  }
}

class RequiredAttributesEditor extends StatelessWidget {
  const RequiredAttributesEditor({super.key, required this.profile, required this.onChanged});
  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final onto = context.read<CorpusRepository>().ontology;
    final lang = context.lang;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in onto.requirable)
          InkChip(
            label: onto.label('requirable', a, lang),
            selected: profile.requiredAttributes.contains(a),
            onTap: () {
              final next = {...profile.requiredAttributes};
              next.contains(a) ? next.remove(a) : next.add(a);
              onChanged(profile.copyWith(requiredAttributes: next));
            },
          ),
      ],
    );
  }
}

/// Index-card summary of the profile.
class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({super.key, required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final repo = context.read<CorpusRepository>();
    final lang = tr.lang;
    final ways = profile.avoidFlags
        .where(repo.ontology.compounds.containsKey)
        .map((f) => repo.ontology.flagLabel(f, lang));
    final classes = profile.avoidFlags
        .where((f) => !repo.ontology.compounds.containsKey(f))
        .map((f) => repo.ontology.flagLabel(f, lang));
    final specific = profile.avoidIngredients.map((i) => repo.ingredients.name(i, lang));
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: MonoLabel(k, size: 11)),
          Expanded(child: Text(v, style: MT.serif(15))),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
        boxShadow: [BoxShadow(color: MC.ink.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          row(tr('profile.eats'), ways.isEmpty ? tr('profile.anything') : ways.join(', ')),
          const DashedRule(),
          row(tr('profile.avoids'), classes.isEmpty ? tr('profile.nothing') : classes.join(', ')),
          const DashedRule(),
          row(tr('profile.specific'), specific.isEmpty ? tr('profile.nothing') : specific.join(', ')),
          const DashedRule(),
          row(
            tr('profile.time'),
            profile.maxTimeMinutes == null
                ? tr('profile.nolimit')
                : tr('profile.minutes', {'n': profile.maxTimeMinutes}),
          ),
          const DashedRule(),
          row(
            tr('profile.calories'),
            profile.calorieTarget == null ? tr('profile.notarget') : tr('profile.kcal', {'n': profile.calorieTarget}),
          ),
          const DashedRule(),
          row(tr('profile.effort'), tr('effort.${profile.preferredEffort}')),
        ],
      ),
    );
  }
}

/// The halal/kosher certification note, shown near those toggles.
class CertificationNote extends StatelessWidget {
  const CertificationNote({super.key, this.onMore});
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MC.mustard.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: MC.mustard.withValues(alpha: 0.9), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('settings.halal.note'), style: MT.serif(13.5, color: MC.inkSoft, height: 1.45)),
          if (onMore != null) TextLink(tr('settings.halal.more'), onTap: onMore!),
        ],
      ),
    );
  }
}
