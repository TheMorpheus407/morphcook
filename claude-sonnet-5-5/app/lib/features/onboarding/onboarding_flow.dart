import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/profile.dart';
import '../../state/controllers/profile_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../profile/profile_editors.dart';
import '../profile/profile_summary.dart';

/// language → name → diet & allergies → calorie target + time budget → confirm.
///
/// Every step writes straight into the profile, so leaving mid-way loses
/// nothing; the flow ends when the person confirms.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const int _steps = 5;
  int _step = 0;
  bool _forward = true;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<ProfileController>().profile.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() {
      _forward = step > _step;
      _step = step.clamp(0, _steps - 1);
    });
  }

  void _update(Profile profile) => context.read<ProfileController>().setProfile(profile);

  Future<void> _finish() async {
    final controller = context.read<ProfileController>();
    await controller.completeOnboarding(controller.profile);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final profile = context.watch<ProfileController>().profile;
    final last = _step == _steps - 1;

    return PaperScaffold(
      body: SafeArea(
        child: Column(
          children: [
            ContentWidth(
              padding: const EdgeInsets.fromLTRB(8, 6, 20, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: _step == 0
                        ? null
                        : PaperIconButton(
                            icon: Icons.arrow_back,
                            tooltip: s('common.back'),
                            onPressed: () => _go(_step - 1),
                          ),
                  ),
                  Expanded(
                    child: _Progress(
                      step: _step,
                      steps: _steps,
                      label: s('onboarding.progress', {'n': _step + 1, 'total': _steps}),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: context.motion(const Duration(milliseconds: 300)),
                transitionBuilder: (child, animation) {
                  final incoming = child.key == ValueKey<int>(_step);
                  final offset = Tween<Offset>(
                    begin: Offset((_forward == incoming ? 1 : -1) * 0.06, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: offset, child: child),
                  );
                },
                child: KeyedSubtree(key: ValueKey<int>(_step), child: _buildStep(context, profile)),
              ),
            ),
            ContentWidth(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_step == 1)
                    PaperButton(
                      label: s('common.skip'),
                      style: PaperButtonStyle.quiet,
                      onPressed: () => _go(_step + 1),
                    ),
                  const Spacer(),
                  PaperButton(
                    label: last ? s('onboarding.start') : s('common.next'),
                    icon: last ? Icons.restaurant_menu : Icons.arrow_forward,
                    onPressed: last ? _finish : () => _go(_step + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, Profile profile) {
    final s = context.s;
    switch (_step) {
      case 0:
        return _StepScroll(
          children: [
            const SizedBox(height: 18),
            Center(child: Text('morphcook', style: AppText.display(size: 58))),
            Center(child: HandNote(s('brand.tagline'), size: 28)),
            const SizedBox(height: 34),
            Text(s('onboarding.language.title'), style: AppText.display(size: 30)),
            const SizedBox(height: 6),
            Text(s('onboarding.language.body'), style: AppText.serif(size: 16, color: Palette.inkSoft)),
            const SizedBox(height: 22),
            LanguageEditor(profile: profile, onChanged: _update),
          ],
        );
      case 1:
        return _StepScroll(
          children: [
            const SizedBox(height: 18),
            Text(s('onboarding.name.title'), style: AppText.display(size: 32)),
            const SizedBox(height: 6),
            HandNote(s('onboarding.name.note'), size: 22),
            const SizedBox(height: 22),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              style: AppText.serifItalic(size: 22),
              decoration: InputDecoration(hintText: s('onboarding.name.hint')),
              onChanged: (v) => _update(profile.copyWith(name: v.trim())),
              onSubmitted: (_) => _go(_step + 1),
            ),
          ],
        );
      case 2:
        return _StepScroll(
          children: [
            const SizedBox(height: 14),
            Text(s('onboarding.diet.title'), style: AppText.display(size: 30)),
            const SizedBox(height: 4),
            HandNote(s('onboarding.diet.note'), size: 21),
            const SizedBox(height: 18),
            FormSection(
              title: s('profile.diet.title'),
              child: DietEditor(profile: profile, onChanged: _update),
            ),
            FormSection(
              title: s('profile.avoid.title'),
              child: AvoidFlagsEditor(profile: profile, onChanged: _update),
            ),
            FormSection(
              title: s('profile.ingredients.title'),
              note: s('profile.ingredients.note'),
              child: IngredientAvoidEditor(profile: profile, onChanged: _update),
            ),
            FormSection(
              title: s('profile.required.title'),
              child: RequiredAttributesEditor(profile: profile, onChanged: _update),
            ),
          ],
        );
      case 3:
        return _StepScroll(
          children: [
            const SizedBox(height: 14),
            Text(s('onboarding.pace.title'), style: AppText.display(size: 30)),
            const SizedBox(height: 4),
            HandNote(s('onboarding.pace.note'), size: 21),
            const SizedBox(height: 18),
            FormSection(
              title: s('profile.effort.title'),
              child: EffortEditor(profile: profile, onChanged: _update),
            ),
            FormSection(
              title: s('profile.time.title'),
              child: TimeBudgetEditor(profile: profile, onChanged: _update),
            ),
            FormSection(
              title: s('profile.calories.title'),
              child: CalorieEditor(profile: profile, onChanged: _update),
            ),
          ],
        );
      default:
        return _StepScroll(
          children: [
            const SizedBox(height: 14),
            Text(
              profile.name.isEmpty
                  ? s('onboarding.confirm.titleNoName')
                  : s('onboarding.confirm.title', {'name': profile.name}),
              style: AppText.display(size: 32),
            ),
            const SizedBox(height: 4),
            HandNote(s('onboarding.confirm.note'), size: 21),
            const SizedBox(height: 18),
            ProfileSummary(
              profile: profile,
              ontology: context.read<Corpus>().ontology,
              dictionary: context.read<Corpus>().ingredients,
              onEdit: _go,
            ),
          ],
        );
    }
  }
}

class _StepScroll extends StatelessWidget {
  const _StepScroll({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ContentWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.steps, required this.label});

  final int step;
  final int steps;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < steps; i++)
              AnimatedContainer(
                duration: context.motion(const Duration(milliseconds: 220)),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == step ? 26 : 8,
                height: 4,
                decoration: BoxDecoration(
                  color: i <= step ? (i == step ? Palette.coral : Palette.ink) : Palette.rule,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
