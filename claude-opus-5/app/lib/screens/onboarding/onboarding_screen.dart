import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/profile.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../settings/avoidance_editor.dart';

/// language → name → diet & allergies → calorie target + time budget → confirm
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pages = PageController();
  final TextEditingController _name = TextEditingController();

  late Profile _draft = context.read<AppState>().profile;
  int _index = 0;

  static const int _stepCount = 5;

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _update(Profile next) => setState(() => _draft = next);

  void _go(int index) {
    final clamped = index.clamp(0, _stepCount - 1);
    setState(() => _index = clamped);
    unawaited(_pages.goToPage(context, clamped));
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.completeOnboarding(_draft.copyWith(name: _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_draft.lang);
    final colors = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'morphcook',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1} / $_stepCount',
                        style: MorphType.numeric(colors.inkFaint, size: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ProgressRule(index: _index, total: _stepCount),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _LanguageStep(
                    s: s,
                    draft: _draft,
                    onChanged: (lang) => _update(_draft.copyWith(lang: lang)),
                  ),
                  _NameStep(s: s, controller: _name),
                  _DietStep(s: s, draft: _draft, onChanged: _update),
                  _TargetsStep(s: s, draft: _draft, onChanged: _update),
                  _ConfirmStep(s: s, draft: _draft, name: _name.text),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Row(
                children: [
                  Flexible(
                    child: _index > 0
                        ? TextButton(
                            onPressed: () => _go(_index - 1),
                            child: Text(s.back, maxLines: 1),
                          )
                        : TextButton(
                            onPressed: _finish,
                            child: Text(s.obSkip, maxLines: 1),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _index == _stepCount - 1
                          ? _finish
                          : () {
                              // Re-render the confirm step with the latest name.
                              setState(() {});
                              _go(_index + 1);
                            },
                      child: Text(
                        _index == _stepCount - 1 ? s.obStart : s.next,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: Motion.duration(context, MorphDurations.fade),
              height: i <= index ? 2.4 : 1,
              color: i <= index ? colors.accent : colors.edge,
            ),
          ),
          if (i < total - 1) const SizedBox(width: 5),
        ],
      ],
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.body,
    required this.child,
    this.hand,
  });

  final String title;
  final String body;
  final Widget child;
  final String? hand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toLowerCase(), style: theme.textTheme.displayMedium),
          const SizedBox(height: 12),
          Text(body, style: theme.textTheme.bodyMedium),
          if (hand != null) ...[const SizedBox(height: 12), HandNote(hand!)],
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({
    required this.s,
    required this.draft,
    required this.onChanged,
  });

  final S s;
  final Profile draft;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: s.obLanguageTitle,
      body: s.obLanguageBody,
      child: Column(
        children: [
          for (final code in S.supported)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BigChoice(
                label: S.languageNames[code]!,
                sub: code == 'de' ? 'Deutsch (DE)' : 'English (EN)',
                selected: draft.lang == code,
                onTap: () => onChanged(code),
              ),
            ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.s, required this.controller});

  final S s;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: s.obNameTitle,
      body: s.obNameBody,
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(hintText: s.obNameHint),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}

class _DietStep extends StatelessWidget {
  const _DietStep({
    required this.s,
    required this.draft,
    required this.onChanged,
  });

  final S s;
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ontology = state.repository.ontology;

    // Diets first, then the EU allergen list — the two things people reach for.
    const dietShortcuts = [
      'vegan',
      'vegetarian',
      'pescatarian',
      'halal',
      'kosher',
      'gluten-free',
      'lactose-free',
      'dairy-free',
      'nut-free',
      'low-fodmap',
      'sugar-free',
      'alcohol-free',
    ];

    final allergens =
        ontology.containsFlags.values.where((f) => f.euAllergen).toList()
          ..sort((a, b) => a.label(draft.lang).compareTo(b.label(draft.lang)));

    return _StepScaffold(
      title: s.obDietTitle,
      body: s.obDietBody,
      hand: s.tagline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in dietShortcuts)
                if (ontology.compoundFlags.containsKey(id))
                  InkChip(
                    label: ontology.compoundFlags[id]!.label(draft.lang),
                    selected: draft.avoidFlags.contains(id),
                    onTap: () {
                      final next = Set<String>.from(draft.avoidFlags);
                      next.contains(id) ? next.remove(id) : next.add(id);
                      onChanged(draft.copyWith(avoidFlags: next));
                    },
                  ),
            ],
          ),
          const SizedBox(height: 26),
          Eyebrow(s.obAllergyTitle),
          const SizedBox(height: 6),
          Text(s.obAllergyBody, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final flag in allergens)
                InkChip(
                  label: flag.label(draft.lang),
                  dense: true,
                  tone: context.colors.secondary,
                  selected: draft.avoidFlags.contains(flag.id),
                  onTap: () {
                    final next = Set<String>.from(draft.avoidFlags);
                    next.contains(flag.id)
                        ? next.remove(flag.id)
                        : next.add(flag.id);
                    onChanged(draft.copyWith(avoidFlags: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 26),
          Eyebrow(s.settingsSpecificAvoidance),
          const SizedBox(height: 6),
          Text(
            s.settingsSpecificAvoidanceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          IngredientAvoidanceEditor(
            lang: draft.lang,
            selected: draft.avoidIngredients,
            onChanged: (next) =>
                onChanged(draft.copyWith(avoidIngredients: next)),
          ),
        ],
      ),
    );
  }
}

class _TargetsStep extends StatelessWidget {
  const _TargetsStep({
    required this.s,
    required this.draft,
    required this.onChanged,
  });

  final S s;
  final Profile draft;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ontology = context.watch<AppState>().repository.ontology;

    return _StepScaffold(
      title: s.obTargetsTitle,
      body: s.obTargetsBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.settingsTimeBudget),
          const SizedBox(height: 4),
          Text(
            draft.maxTimeMinutes >= 240
                ? s.all
                : s.minutes(draft.maxTimeMinutes),
            style: MorphType.numeric(
              colors.ink,
              size: 26,
              weight: FontWeight.w700,
            ),
          ),
          Slider(
            value: draft.maxTimeMinutes.toDouble().clamp(15, 240),
            min: 15,
            max: 240,
            divisions: 15,
            label: s.minutes(draft.maxTimeMinutes),
            onChanged: (v) =>
                onChanged(draft.copyWith(maxTimeMinutes: v.round())),
          ),
          Text(
            s.settingsTimeBudgetNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Eyebrow(s.settingsCalorieTarget),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                draft.calorieTarget == null
                    ? s.settingsCalorieTargetOff
                    : s.kcal(draft.calorieTarget!),
                style: MorphType.numeric(
                  colors.ink,
                  size: 26,
                  weight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Switch(
                value: draft.hasCalorieTarget,
                onChanged: (on) => onChanged(
                  on
                      ? draft.copyWith(calorieTarget: 600)
                      : draft.copyWith(clearCalorieTarget: true),
                ),
              ),
            ],
          ),
          if (draft.hasCalorieTarget) ...[
            Slider(
              value: draft.calorieTarget!.toDouble().clamp(200, 1200),
              min: 200,
              max: 1200,
              divisions: 20,
              label: s.kcal(draft.calorieTarget!),
              onChanged: (v) =>
                  onChanged(draft.copyWith(calorieTarget: v.round())),
            ),
            const SizedBox(height: 4),
            Text(
              '${s.settingsCalorieTolerance}: ± ${draft.calorieTolerance} kcal',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              value: draft.calorieTolerance.toDouble().clamp(50, 500),
              min: 50,
              max: 500,
              divisions: 9,
              onChanged: (v) =>
                  onChanged(draft.copyWith(calorieTolerance: v.round())),
            ),
          ],
          const SizedBox(height: 20),
          Eyebrow(s.settingsEffort),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final effort in ontology.efforts)
                InkChip(
                  label: effort.label(draft.lang),
                  selected: draft.preferredEffort == effort.id,
                  onTap: () =>
                      onChanged(draft.copyWith(preferredEffort: effort.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.s,
    required this.draft,
    required this.name,
  });

  final S s;
  final Profile draft;
  final String name;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ontology = state.repository.ontology;
    final colors = context.colors;

    final avoidLabels = [
      for (final id in draft.avoidFlags) ontology.labelForFlag(id)(draft.lang),
      for (final id in draft.avoidIngredients)
        state.repository.ingredients[id]?.label(draft.lang) ?? id,
    ]..sort();

    return _StepScaffold(
      title: s.obConfirmTitle,
      body: s.obConfirmBody,
      child: Polaroid(
        seed: 'confirm',
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HandNote(s.obGreeting(name.trim()), size: 26),
            const SizedBox(height: 14),
            DashedRule(color: colors.edge),
            const SizedBox(height: 14),
            _Line(
              label: s.settingsLanguage,
              value: S.languageNames[draft.lang]!,
            ),
            _Line(
              label: s.settingsTimeBudget,
              value: draft.maxTimeMinutes >= 240
                  ? s.all
                  : s.minutes(draft.maxTimeMinutes),
            ),
            _Line(
              label: s.settingsCalorieTarget,
              value: draft.calorieTarget == null
                  ? s.settingsCalorieTargetOff
                  : '${s.kcal(draft.calorieTarget!)} ± ${draft.calorieTolerance}',
            ),
            _Line(
              label: s.settingsEffort,
              value: ontology.efforts
                  .firstWhere(
                    (e) => e.id == draft.preferredEffort,
                    orElse: () => ontology.efforts.first,
                  )
                  .label(draft.lang),
            ),
            _Line(
              label: s.settingsDiet,
              value: avoidLabels.isEmpty ? s.none : avoidLabels.join(', '),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label.toUpperCase(),
              style: MorphType.eyebrow(colors.inkFaint),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.duration(context, MorphDurations.quick),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : colors.paperRaised,
          border: Border.all(
            color: selected ? colors.accent : colors.edge,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 2),
                  Text(sub, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? colors.accent : colors.inkFaint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
