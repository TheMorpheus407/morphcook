import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../../models/profile.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// Onboarding: language → name → diet & allergies → calorie target +
/// time budget → confirm.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;

  String _lang = 'en';
  final _name = TextEditingController();
  final Set<String> _avoidFlags = {};
  final Set<String> _avoidIngredients = {};
  int? _calorieTarget;
  int? _maxTime;

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_index < 4) {
      _page.nextPage(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    await state.completeOnboarding(Profile(
      name: _name.text.trim(),
      lang: _lang,
      avoidFlags: _avoidFlags,
      avoidIngredients: _avoidIngredients,
      calorieTarget: _calorieTarget,
      maxTimeMinutes: _maxTime,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S(_lang);
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              Text('morphcook',
                  style: MorphText.display.copyWith(fontSize: 30)),
              Text(s('tagline'),
                  style: MorphText.hand.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 24,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      color: i <= _index
                          ? MorphColors.terracotta
                          : MorphColors.line,
                    ),
                ],
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _languagePage(s),
                    _namePage(s),
                    _dietPage(s),
                    _targetsPage(s),
                    _confirmPage(s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frame(String title, List<Widget> children,
      {String? subtitle, Widget? footer}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 24),
      children: [
        Text(title, style: MorphText.display.copyWith(fontSize: 27)),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(subtitle,
                style: MorphText.hand
                    .copyWith(fontSize: 18, color: MorphColors.inkSoft)),
          ),
        const SizedBox(height: 22),
        ...children,
        const SizedBox(height: 28),
        if (footer != null) footer,
      ],
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) => FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: MorphColors.ink,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2)),
        ),
        onPressed: onTap,
        child: Text(label.toLowerCase(),
            style: MorphText.label(color: MorphColors.cream)),
      );

  Widget _languagePage(S s) => _frame(
        s('obLanguageTitle'),
        [
          _bigChoice('english', _lang == 'en', () {
            setState(() => _lang = 'en');
          }),
          const SizedBox(height: 12),
          _bigChoice('deutsch', _lang == 'de', () {
            setState(() => _lang = 'de');
          }),
        ],
        footer: _primaryButton(s('next'), _next),
      );

  Widget _bigChoice(String label, bool selected, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected ? MorphColors.ink : MorphColors.card,
            border: Border.all(color: MorphColors.line),
          ),
          child: Text(label,
              style: MorphText.display.copyWith(
                  fontSize: 20,
                  color:
                      selected ? MorphColors.cream : MorphColors.ink)),
        ),
      );

  Widget _namePage(S s) => _frame(
        s('obNameTitle'),
        [
          TextField(
            controller: _name,
            autofocus: false,
            style: MorphText.mono.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: s('obNameHint'),
              hintStyle: MorphText.mono
                  .copyWith(fontSize: 13, color: MorphColors.inkFaint),
              enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: MorphColors.line)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: MorphColors.terracotta)),
            ),
          ),
        ],
        footer: _primaryButton(s('next'), _next),
      );

  Widget _dietPage(S s) {
    final state = context.read<AppState>();
    final ontology = state.corpus.ontology;
    return _frame(
      s('obDietTitle'),
      [
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final compound in ontology.compoundFlags)
              MonoChip(
                label: compound.name.of(_lang),
                selected: _avoidFlags.contains(compound.id),
                onTap: () => setState(() =>
                    _avoidFlags.contains(compound.id)
                        ? _avoidFlags.remove(compound.id)
                        : _avoidFlags.add(compound.id)),
              ),
          ],
        ),
        const DashedDivider(),
        Text(s('obAllergyTitle'), style: MorphText.label(size: 10)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 10,
          children: [
            for (final flag in const [
              'dairy', 'gluten', 'egg', 'soy', 'peanuts', 'tree-nuts',
              'fish', 'shellfish', 'sesame', 'mustard', 'celery',
              'sulphites', 'alcohol', 'caffeine'
            ])
              MonoChip(
                label: ontology.nameOf(flag, _lang),
                selected: _avoidFlags.contains(flag),
                onTap: () => setState(() => _avoidFlags.contains(flag)
                    ? _avoidFlags.remove(flag)
                    : _avoidFlags.add(flag)),
              ),
          ],
        ),
      ],
      subtitle: s('obDietSub'),
      footer: _primaryButton(s('next'), _next),
    );
  }

  Widget _targetsPage(S s) => _frame(
        s('obTargetsTitle'),
        [
          _targetSlider(
            label: s('obCalories'),
            value: _calorieTarget?.toDouble(),
            min: 300,
            max: 1000,
            divisions: 14,
            display: (v) =>
                v == null ? s('noLimit') : '${v.round()} kcal',
            onChanged: (v) =>
                setState(() => _calorieTarget = v?.round()),
          ),
          const SizedBox(height: 16),
          _targetSlider(
            label: s('obTime'),
            value: _maxTime?.toDouble(),
            min: 15,
            max: 240,
            divisions: 15,
            display: (v) =>
                v == null ? s('noLimit') : '${v.round()} ${s('minutes')}',
            onChanged: (v) => setState(() => _maxTime = v?.round()),
          ),
        ],
        footer: _primaryButton(s('next'), _next),
      );

  Widget _targetSlider({
    required String label,
    required double? value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double?) display,
    required void Function(double?) onChanged,
  }) {
    final active = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: MorphText.label())),
            Text(display(value),
                style: MorphText.mono.copyWith(
                    fontSize: 12, color: MorphColors.terracotta)),
            Checkbox(
              value: active,
              activeColor: MorphColors.terracotta,
              onChanged: (v) => onChanged(v == true ? (min + max) / 2 : null),
            ),
          ],
        ),
        if (active)
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: MorphColors.terracotta,
            onChanged: onChanged,
          ),
      ],
    );
  }

  Widget _confirmPage(S s) {
    final name = _name.text.trim();
    return _frame(
      s('obConfirmTitle'),
      [
        if (name.isNotEmpty)
          Text('${s('editionFor')} $name'.toLowerCase(),
              style: MorphText.label()),
        const SizedBox(height: 12),
        Text(s('obConfirmBody'),
            style: MorphText.serif.copyWith(fontSize: 17)),
        const SizedBox(height: 16),
        Text('&', style: MorphText.hand.copyWith(
            fontSize: 44, color: MorphColors.terracotta)),
      ],
      footer: _primaryButton(s('letsCook'), _finish),
    );
  }
}
