import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/profile.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../settings/profile_widgets.dart';

/// language → name → diet & allergies → calorie target + time budget → confirm
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const _total = 5;
  final _pages = PageController();
  late Profile _draft;
  late final TextEditingController _name;
  int _index = 0;
  bool _showAllAllergens = false;

  @override
  void initState() {
    super.initState();
    _draft = context.read<AppController>().profile;
    _name = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _pages.dispose();
    _name.dispose();
    super.dispose();
  }

  void _set(Profile p) => setState(() => _draft = p);

  void _go(int i) {
    final target = i.clamp(0, _total - 1);
    setState(() => _index = target);
    if (Motion.reduced(context)) {
      _pages.jumpToPage(target);
    } else {
      _pages.animateToPage(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _finish() async {
    final app = context.read<AppController>();
    await app.updateProfile(_draft.copyWith(name: _name.text.trim(), onboardingComplete: true));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final last = _index == _total - 1;
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pages,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _page(1, s('onb.language.title'), s('onb.language.note'), [
              LanguagePicker(
                value: _draft,
                onChanged: (p) {
                  _set(p);
                  context.read<AppController>().setLang(p.lang);
                },
              ),
            ], wordmark: true),
            _page(2, s('onb.name.title'), s('onb.name.note'), [
              TextField(
                controller: _name,
                style: AppText.body(size: 16),
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: s('onb.name.hint')),
                onChanged: (v) => _set(_draft.copyWith(name: v)),
              ),
            ]),
            _page(3, s('onb.diet.title'), s('onb.diet.note'), [
              MonoLabel(s('onb.diet.styles')),
              const SizedBox(height: 8),
              DietStylePicker(value: _draft, onChanged: _set),
              const SizedBox(height: 20),
              MonoLabel(s('onb.diet.allergens')),
              const SizedBox(height: 4),
              if (_showAllAllergens)
                AllergenPicker(value: _draft, onChanged: _set)
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: PaperButton(
                    label: s('common.showAll'),
                    kind: PaperButtonKind.quiet,
                    icon: Icons.expand_more,
                    onPressed: () => setState(() => _showAllAllergens = true),
                  ),
                ),
              const SizedBox(height: 20),
              MonoLabel(s('onb.diet.specific')),
              const SizedBox(height: 8),
              SpecificAvoidanceField(value: _draft, onChanged: _set),
              const SizedBox(height: 20),
              MonoLabel(s('onb.diet.requirements')),
              const SizedBox(height: 4),
              RequirementsPicker(value: _draft, onChanged: _set),
            ]),
            _page(4, s('onb.targets.title'), s('onb.targets.note'), [
              MonoLabel(s('onb.targets.calories')),
              CalorieTargetField(value: _draft, onChanged: _set),
              const SizedBox(height: 16),
              MonoLabel(s('onb.targets.time')),
              TimeBudgetField(value: _draft, onChanged: _set),
              const SizedBox(height: 16),
              MonoLabel(s('onb.targets.effort')),
              const SizedBox(height: 8),
              EffortPicker(value: _draft, onChanged: _set),
            ]),
            _page(5, s('onb.confirm.title'), s('onb.confirm.note'), [_Summary(draft: _draft, name: _name.text)]),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.rule))),
          child: Row(
            children: [
              PaperButton(
                label: s('common.back'),
                kind: PaperButtonKind.quiet,
                icon: Icons.arrow_back,
                onPressed: _index == 0 ? null : () => _go(_index - 1),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: last
                    ? PaperButton(label: s('onb.confirm.start'), icon: Icons.auto_stories_outlined, expand: true, onPressed: _finish)
                    : PaperButton(label: s('common.next'), icon: Icons.arrow_forward, expand: true, onPressed: () => _go(_index + 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(int n, String title, String note, List<Widget> content, {bool wordmark = false}) {
    final s = context.s;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        if (wordmark) ...[
          Text(s('app.name'), style: AppText.display(size: 40)),
          const SizedBox(height: 2),
          MonoLabel(s('app.tagline')),
          const SizedBox(height: 18),
          const DashedRule(),
          const SizedBox(height: 26),
        ],
        MonoLabel(s('onb.step', {'n': '$n', 'total': '$_total'})),
        const SizedBox(height: 10),
        Text(title, style: AppText.display(size: 30)),
        const SizedBox(height: 10),
        HandNote(note, size: 19),
        const SizedBox(height: 24),
        ...content,
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.draft, required this.name});
  final Profile draft;
  final String name;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final ont = app.repo.ontology;
    final dict = app.repo.ingredients;
    final avoiding = [
      ...draft.avoidFlags.map((f) => ont.labelForFlag(f).of(lang)),
      ...draft.avoidIngredients.map((i) => dict.byId[i]?.name.of(lang) ?? i),
    ];
    final requirements = draft.requiredAttributes.map((r) => ont.compoundById[r]?.label.of(lang) ?? r).toList();
    final effort = ont.efforts.where((e) => e.id == draft.preferredEffort).map((e) => e.label.of(lang)).join();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(s('profile.name'), name.trim().isEmpty ? '—' : name.trim()),
        _line(s('onb.confirm.avoiding'), avoiding.isEmpty ? s('onb.confirm.nothing') : avoiding.join(', ')),
        if (requirements.isNotEmpty) _line(s('profile.required'), requirements.join(', ')),
        _line(
          s('profile.calories'),
          draft.calorieTarget == null ? s('onb.targets.caloriesOff') : '${draft.calorieTarget} kcal · ± ${draft.calorieTolerance} kcal',
        ),
        _line(s('profile.time'), draft.maxTimeMinutes == null ? s('onb.targets.timeOff') : '${draft.maxTimeMinutes} min'),
        _line(s('profile.effort'), effort),
        const SizedBox(height: 8),
        const DashedRule(),
        const SizedBox(height: 12),
        HandNote(s('app.tagline'), size: 20, color: Palette.inkFaint),
      ],
    );
  }

  Widget _line(String kicker, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(kicker),
            const SizedBox(height: 3),
            Text(text, style: AppText.body(size: 15.5)),
          ],
        ),
      );
}
