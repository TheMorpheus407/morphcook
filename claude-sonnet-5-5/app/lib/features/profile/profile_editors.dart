import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/profile.dart';
import '../../widgets/help_link.dart';
import '../../widgets/paper_controls.dart';

/// Reusable profile controls. Onboarding and Settings share them, so a diet
/// chip behaves the same wherever it appears.
typedef ProfileChanged = void Function(Profile profile);

Set<String> _toggled(Set<String> set, String id) {
  final next = {...set};
  if (!next.remove(id)) next.add(id);
  return next;
}

/// Language picker: one tile per language in the ontology.
class LanguageEditor extends StatelessWidget {
  const LanguageEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final language in corpus.ontology.languages)
          PaperChip(
            label: language.name,
            selected: profile.lang == language.code,
            onTap: () => onChanged(profile.copyWith(lang: language.code)),
          ),
      ],
    );
  }
}

/// Diet shortcuts (`vegan`, `halal`, ...) that expand into avoid-flags.
class DietEditor extends StatelessWidget {
  const DietEditor({super.key, required this.profile, required this.onChanged, this.showHelp = true});

  final Profile profile;
  final ProfileChanged onChanged;
  final bool showHelp;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final id in ontology.uiDiets)
              PaperChip(
                label: ontology.label(id, s.lang),
                selected: profile.avoidFlags.contains(id),
                onTap: () => onChanged(profile.copyWith(avoidFlags: _toggled(profile.avoidFlags, id))),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 8),
              child: Icon(Icons.info_outline, size: 15, color: Palette.inkSoft),
            ),
            Expanded(child: Text(s('profile.halalNote'), style: AppText.mono(size: 11, height: 1.5))),
          ],
        ),
        if (showHelp) ...[
          const SizedBox(height: 8),
          HelpLink(entryId: 'dietary-matching', label: s('help.howMatchingWorks')),
        ],
      ],
    );
  }
}

/// Class avoidance: one checkbox per allergen or dislike group.
class AvoidFlagsEditor extends StatelessWidget {
  const AvoidFlagsEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in ontology.avoidGroups) ...[
          Padding(padding: const EdgeInsets.only(top: 6, bottom: 4), child: MonoLabel(group.name.resolve(s.lang))),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 360;
              final width = wide ? (constraints.maxWidth - 8) / 2 : constraints.maxWidth;
              return Wrap(
                spacing: 8,
                children: [
                  for (final id in group.flags)
                    SizedBox(
                      width: width,
                      child: _CheckRow(
                        label: ontology.label(id, s.lang),
                        value: profile.avoidFlags.contains(id),
                        onChanged: (_) => onChanged(profile.copyWith(avoidFlags: _toggled(profile.avoidFlags, id))),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      label: label,
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Checkbox(value: value, onChanged: onChanged, visualDensity: VisualDensity.compact),
              ),
              const SizedBox(width: 2),
              Expanded(child: Text(label, style: AppText.serif(size: 15.5))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Specific avoidance: type an ingredient ("apple", "cilantro"), pick any level
/// of the dictionary tree and avoidance propagates to its children.
class IngredientAvoidEditor extends StatefulWidget {
  const IngredientAvoidEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ProfileChanged onChanged;

  @override
  State<IngredientAvoidEditor> createState() => _IngredientAvoidEditorState();
}

class _IngredientAvoidEditorState extends State<IngredientAvoidEditor> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _add(String id) {
    widget.onChanged(widget.profile.copyWith(avoidIngredients: {...widget.profile.avoidIngredients, id}));
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final dictionary = context.read<Corpus>().ingredients;
    final suggestions = dictionary.search(_text.text, s.lang, exclude: widget.profile.avoidIngredients, limit: 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _text,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s('profile.ingredientHint'),
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _text.text.isEmpty
                ? null
                : IconButton(
                    tooltip: s('common.clear'),
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(_text.clear),
                  ),
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Palette.paperLight,
              border: Border.all(color: Palette.rule),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              children: [
                for (final node in suggestions)
                  InkWell(
                    onTap: () => _add(node.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(node.name.resolve(s.lang), style: AppText.serif(size: 16)),
                                if (dictionary.ancestorsOf(node.id).isNotEmpty)
                                  Text(
                                    dictionary
                                        .ancestorsOf(node.id)
                                        .reversed
                                        .map((a) => dictionary.nameOf(a, s.lang))
                                        .join(' › '),
                                    style: AppText.mono(size: 10.5),
                                  ),
                              ],
                            ),
                          ),
                          if (dictionary.descendantsOf(node.id).length > 1)
                            Text(
                              s('profile.includesMore', {'n': dictionary.descendantsOf(node.id).length - 1}),
                              style: AppText.mono(size: 10.5, color: Palette.coralDeep),
                            ),
                          const SizedBox(width: 8),
                          const Icon(Icons.add, size: 18, color: Palette.ink),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (widget.profile.avoidIngredients.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              for (final id in (widget.profile.avoidIngredients.toList()..sort()))
                _RemovableChip(
                  label: dictionary.nameOf(id, s.lang),
                  removeLabel: s('common.remove'),
                  onRemoved: () => widget.onChanged(
                    widget.profile.copyWith(avoidIngredients: {...widget.profile.avoidIngredients}..remove(id)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.removeLabel, required this.onRemoved});

  final String label;
  final String removeLabel;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $removeLabel',
      excludeSemantics: true,
      onTap: onRemoved,
      child: GestureDetector(
        onTap: onRemoved,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.only(left: 12, right: 8, top: 7, bottom: 7),
              decoration: BoxDecoration(color: Palette.ink, borderRadius: BorderRadius.circular(3)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppText.serifItalic(size: 15, color: Palette.paperLight)),
                  const SizedBox(width: 6),
                  const Icon(Icons.close, size: 15, color: Palette.paperLight),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Positive requirements (`keto`, `high-protein`, ...).
class RequiredAttributesEditor extends StatelessWidget {
  const RequiredAttributesEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final id in ontology.requiredAttributeChoices)
          PaperChip(
            label: ontology.label(id, s.lang),
            style: PaperChipStyle.mono,
            selected: profile.requiredAttributes.contains(id),
            onTap: () => onChanged(profile.copyWith(requiredAttributes: _toggled(profile.requiredAttributes, id))),
          ),
      ],
    );
  }
}

/// Calorie target: a per-meal hard filter with an adjustable tolerance.
class CalorieEditor extends StatelessWidget {
  const CalorieEditor({super.key, required this.profile, required this.onChanged, this.showTolerance = false});

  final Profile profile;
  final ProfileChanged onChanged;
  final bool showTolerance;

  static const int minKcal = 250;
  static const int maxKcal = 1200;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final target = profile.calorieTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(s('profile.calorieSwitch'), style: AppText.serif(size: 16))),
            Switch(
              value: target != null,
              onChanged: (on) => onChanged(profile.copyWith(calorieTarget: on ? 600 : null)),
            ),
          ],
        ),
        if (target != null) ...[
          Row(
            children: [
              Text('~$target', style: AppText.display(size: 34)),
              const SizedBox(width: 8),
              Flexible(child: Text(s('profile.kcalPerMeal'), style: AppText.mono(size: 12))),
            ],
          ),
          Slider(
            value: target.toDouble().clamp(minKcal.toDouble(), maxKcal.toDouble()),
            min: minKcal.toDouble(),
            max: maxKcal.toDouble(),
            divisions: (maxKcal - minKcal) ~/ 50,
            label: '$target',
            semanticFormatterCallback: (v) => s('unit.kcal', {'n': v.round()}),
            onChanged: (v) => onChanged(profile.copyWith(calorieTarget: (v / 50).round() * 50)),
          ),
          if (showTolerance) ...[
            const SizedBox(height: 4),
            MonoLabel(s('profile.tolerance')),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final tol in const [100, 150, 250, 400])
                  PaperChip(
                    label: '± $tol',
                    style: PaperChipStyle.mono,
                    selected: profile.calorieTolerance == tol,
                    onTap: () => onChanged(profile.copyWith(calorieTolerance: tol)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(s('profile.calorieExplain'), style: AppText.hand(size: 19, color: Palette.inkSoft)),
        ],
      ],
    );
  }
}

/// Time budget in minutes, or no limit.
class TimeBudgetEditor extends StatelessWidget {
  const TimeBudgetEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ProfileChanged onChanged;

  static const List<int> options = <int>[15, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final minutes in options)
          PaperChip(
            label: s.minutes(minutes),
            style: PaperChipStyle.mono,
            selected: profile.maxTimeMinutes == minutes,
            onTap: () => onChanged(profile.copyWith(maxTimeMinutes: minutes)),
          ),
        PaperChip(
          label: s('profile.noLimit'),
          style: PaperChipStyle.mono,
          selected: profile.maxTimeMinutes == null,
          onTap: () => onChanged(profile.copyWith(maxTimeMinutes: null)),
        ),
      ],
    );
  }
}

/// Effort mood: easy, medium or hard.
class EffortEditor extends StatelessWidget {
  const EffortEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final ProfileChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ontology = context.read<Corpus>().ontology;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final id in const ['easy', 'medium', 'hard'])
          PaperChip(
            label: ontology.label(id, s.lang),
            selected: profile.preferredEffort == id,
            onTap: () => onChanged(profile.copyWith(preferredEffort: id)),
          ),
      ],
    );
  }
}

/// Small helper for screens: opens the Help Center from any editor.
void openHelp(BuildContext context, String entryId) => openFaq(context, entryId: entryId);
