import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../localization/strings.dart';
import '../../models/profile.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/tag_chip.dart';
import '../home/home_shell.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  late Profile _draft;
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _draft = AppScope.of(context).profileRepo.profile;
    _seeded = true;
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 4));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 4));

  Future<void> _finish() async {
    final state = AppScope.of(context);
    final notifier = I18n.notifierOf(context);
    final navigator = Navigator.of(context);
    await state.profileRepo.save(_draft.copyWith(onboarded: true));
    notifier.setLang(_draft.lang);
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);

    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.appName.toLowerCase(),
                        style: MCTypography.masthead(color: MCColors.ink)
                            .copyWith(fontSize: 28)),
                    Text('${_step + 1} / 5', style: MCTypography.eyebrow()),
                  ],
                ),
                const SizedBox(height: 8),
                const DashedRule(),
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: _stepWidget(),
                  ),
                ),
                _navBar(s),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepWidget() {
    switch (_step) {
      case 0:
        return _LanguageStep(
          key: const ValueKey('lang'),
          draft: _draft,
          onChange: (d) => setState(() => _draft = d),
        );
      case 1:
        return _NameStep(
          key: const ValueKey('name'),
          draft: _draft,
          onChange: (d) => setState(() => _draft = d),
        );
      case 2:
        return _DietStep(
          key: const ValueKey('diet'),
          draft: _draft,
          onChange: (d) => setState(() => _draft = d),
        );
      case 3:
        return _TargetStep(
          key: const ValueKey('target'),
          draft: _draft,
          onChange: (d) => setState(() => _draft = d),
        );
      default:
        return _ConfirmStep(
          key: const ValueKey('confirm'),
          draft: _draft,
        );
    }
  }

  Widget _navBar(Strings s) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          if (_step > 0)
            TextButton(
              onPressed: _back,
              child: Text(s.back),
            ),
          const Spacer(),
          if (_step < 4)
            ElevatedButton(onPressed: _next, child: Text(s.next))
          else
            ElevatedButton(onPressed: _finish, child: Text(s.done)),
        ],
      ),
    );
  }
}

// === Step 1: Language ====================================================

class _LanguageStep extends StatelessWidget {
  final Profile draft;
  final ValueChanged<Profile> onChange;

  const _LanguageStep({super.key, required this.draft, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return ListView(
      children: [
        Text(s.languageStepTitle, style: MCTypography.display(size: 36)),
        const SizedBox(height: 12),
        Text(s.languageStepBody, style: MCTypography.italic(size: 16)),
        const SizedBox(height: 28),
        Row(
          children: [
            _LangCard(
              label: s.languageEnglish,
              selected: draft.lang == 'en',
              accent: MCColors.coral,
              onTap: () {
                onChange(draft.copyWith(lang: 'en'));
                I18n.notifierOf(context).setLang('en');
              },
            ),
            const SizedBox(width: 16),
            _LangCard(
              label: s.languageGerman,
              selected: draft.lang == 'de',
              accent: MCColors.teal,
              onTap: () {
                onChange(draft.copyWith(lang: 'de'));
                I18n.notifierOf(context).setLang('de');
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LangCard extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _LangCard({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? accent : MCColors.polaroid,
            border: Border.all(
              color: selected ? accent : MCColors.paperDark,
              width: 0.8,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Center(
            child: Text(
              label.toLowerCase(),
              style: MCTypography.display(
                size: 28,
                color: selected ? MCColors.cream : MCColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// === Step 2: Name ========================================================

class _NameStep extends StatefulWidget {
  final Profile draft;
  final ValueChanged<Profile> onChange;

  const _NameStep({super.key, required this.draft, required this.onChange});

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.draft.name);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return ListView(
      children: [
        Text(s.nameStepTitle, style: MCTypography.display(size: 36)),
        const SizedBox(height: 12),
        Text(s.nameStepBody, style: MCTypography.italic(size: 16)),
        const SizedBox(height: 32),
        TextField(
          controller: _ctrl,
          decoration: InputDecoration(hintText: s.nameHint),
          style: MCTypography.body(size: 18),
          onChanged: (v) => widget.onChange(widget.draft.copyWith(name: v.trim())),
        ),
      ],
    );
  }
}

// === Step 3: Diet ========================================================

class _DietStep extends StatefulWidget {
  final Profile draft;
  final ValueChanged<Profile> onChange;
  const _DietStep({super.key, required this.draft, required this.onChange});

  @override
  State<_DietStep> createState() => _DietStepState();
}

class _DietStepState extends State<_DietStep> {
  final _ingredientCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final state = AppScope.of(context);
    final ont = state.ontologyRepo.ontology;
    final lang = widget.draft.lang;

    final compoundKeys = ont.compoundFlags.keys.toList();
    final commonClasses = const [
      'pork', 'beef', 'fish', 'shellfish', 'egg', 'dairy', 'gluten',
      'soy', 'peanuts', 'tree-nuts', 'sesame', 'honey', 'added-sugar',
    ];

    return ListView(
      children: [
        Text(s.dietStepTitle, style: MCTypography.display(size: 32)),
        const SizedBox(height: 8),
        Text(s.dietStepBody, style: MCTypography.italic(size: 15)),
        const SizedBox(height: 18),
        Text(s.allergiesLabel.toUpperCase(), style: MCTypography.eyebrow()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in compoundKeys)
              TagChip(
                label: ont.compoundFlags[k]!.label.resolve(lang),
                selected: widget.draft.avoidFlags.contains(k),
                accent: MCColors.coral,
                onTap: () => _toggleAvoid(k),
              ),
            for (final k in commonClasses)
              if (!compoundKeys.contains(k))
                TagChip(
                  label: ont.labelForFlag(k).resolve(lang),
                  selected: widget.draft.avoidFlags.contains(k),
                  onTap: () => _toggleAvoid(k),
                ),
          ],
        ),
        const SizedBox(height: 26),
        Text(s.specificIngredients.toUpperCase(), style: MCTypography.eyebrow()),
        const SizedBox(height: 10),
        TextField(
          controller: _ingredientCtrl,
          decoration: InputDecoration(hintText: s.searchIngredient),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_ingredientCtrl.text.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: state.ingredientRepo.tree
                .search(_ingredientCtrl.text)
                .map(
                  (n) => TagChip(
                    label: n.label.resolve(lang),
                    onTap: () {
                      final next = {...widget.draft.avoidIngredients, n.id};
                      widget.onChange(widget.draft.copyWith(avoidIngredients: next));
                      _ingredientCtrl.clear();
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 18),
        if (widget.draft.avoidIngredients.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.draft.avoidIngredients.map((id) {
              final n = state.ingredientRepo.tree.find(id);
              final lbl = n?.label.resolve(lang) ?? id;
              return TagChip(
                label: '$lbl ×',
                selected: true,
                accent: MCColors.teal,
                onTap: () {
                  final next = {...widget.draft.avoidIngredients}..remove(id);
                  widget.onChange(widget.draft.copyWith(avoidIngredients: next));
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 30),
        HandwrittenNote(
          text: s.noteHalalDisclaimer,
          rotationTurns: -0.005,
          color: MCColors.inkSoft,
          size: 18,
        ),
      ],
    );
  }

  void _toggleAvoid(String id) {
    final set = {...widget.draft.avoidFlags};
    if (set.contains(id)) {
      set.remove(id);
    } else {
      set.add(id);
    }
    widget.onChange(widget.draft.copyWith(avoidFlags: set));
  }
}

// === Step 4: Target ======================================================

class _TargetStep extends StatelessWidget {
  final Profile draft;
  final ValueChanged<Profile> onChange;
  const _TargetStep({super.key, required this.draft, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final calories = draft.calorieTarget ?? 600;
    final minutes = draft.maxTimeMinutes ?? 45;
    return ListView(
      children: [
        Text(s.targetStepTitle, style: MCTypography.display(size: 32)),
        const SizedBox(height: 8),
        Text(s.targetStepBody, style: MCTypography.italic(size: 15)),
        const SizedBox(height: 24),
        _SliderRow(
          label: s.calorieTarget,
          hint: s.calorieTargetHint,
          value: calories.toDouble(),
          min: 250,
          max: 1100,
          divisions: 17,
          format: (v) => '${v.round()} kcal',
          onChanged: (v) => onChange(draft.copyWith(calorieTarget: v.round())),
        ),
        const SizedBox(height: 20),
        _SliderRow(
          label: s.timeBudget,
          hint: s.timeBudgetHint,
          value: minutes.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          format: (v) => '${v.round()} ${s.minutes}',
          onChanged: (v) => onChange(draft.copyWith(maxTimeMinutes: v.round())),
        ),
        const SizedBox(height: 24),
        Text(s.effortMood.toUpperCase(), style: MCTypography.eyebrow()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final mood in ['easy', 'medium', 'hard'])
              TagChip(
                label: mood,
                selected: draft.preferredEffort == mood,
                accent: MCColors.olive,
                onTap: () => onChange(
                  draft.copyWith(
                    preferredEffort:
                        draft.preferredEffort == mood ? null : mood,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: MCTypography.eyebrow()),
            const Spacer(),
            Text(format(value),
                style: MCTypography.mono(size: 13, color: MCColors.inkSoft)),
          ],
        ),
        const SizedBox(height: 4),
        Text(hint, style: MCTypography.italic(size: 13)),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: MCColors.ink,
            inactiveTrackColor: MCColors.paperDark,
            thumbColor: MCColors.coral,
            overlayColor: MCColors.coral.withValues(alpha: 0.1),
            trackHeight: 1.4,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// === Step 5: Confirm =====================================================

class _ConfirmStep extends StatelessWidget {
  final Profile draft;
  const _ConfirmStep({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final state = AppScope.of(context);
    final ont = state.ontologyRepo.ontology;
    final lang = draft.lang;

    final avoid = [
      ...draft.avoidFlags.map((f) => ont.labelForFlag(f).resolve(lang)),
      ...draft.avoidIngredients
          .map((id) => state.ingredientRepo.tree.find(id)?.label.resolve(lang) ?? id),
    ];

    return ListView(
      children: [
        Masthead(
          title: 'hello, ${draft.name.isEmpty ? "friend" : draft.name.toLowerCase()}.',
          subtitle: s.confirmStepBody,
          align: TextAlign.left,
          titleSize: 36,
        ),
        const SizedBox(height: 12),
        _ConfirmRow(label: s.youAvoid, value: avoid.isEmpty ? s.nothingSelected : avoid.join(', ')),
        const Divider(),
        _ConfirmRow(
            label: s.yourTarget,
            value:
                draft.calorieTarget == null ? s.noPreference : '${draft.calorieTarget} kcal'),
        const Divider(),
        _ConfirmRow(
            label: s.yourBudget,
            value:
                draft.maxTimeMinutes == null ? s.noPreference : '${draft.maxTimeMinutes} ${s.minutes}'),
        const Divider(),
        _ConfirmRow(
            label: s.effortMood,
            value: draft.preferredEffort ?? s.noPreference),
        const SizedBox(height: 30),
        HandwrittenNote(
          text: '— ${s.everyBody.toLowerCase()}.',
          color: MCColors.coral,
          size: 26,
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label.toUpperCase(), style: MCTypography.eyebrow()),
          ),
          Expanded(
            child: Text(value, style: MCTypography.italic(size: 17)),
          ),
        ],
      ),
    );
  }
}
