import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/profile.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import 'diet_editor.dart';

/// Onboarding flow (SPEC): language → name → diet & allergies →
/// calorie target + time budget (+ preferred effort) → confirm.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.profile});

  final Profile profile;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.profile.name ?? '';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step >= 4) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  void _finish(AppState state) {
    // completeOnboarding flips onboardingDone → the app root swaps home
    // to the Shell automatically.
    state.completeOnboarding(widget.profile);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PaperScaffold(
      seed: 23,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Row(
                children: [
                  Text(
                    context.tr('onb.step', {'n': '${_step + 1}'}),
                    style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.6),
                  ),
                  const Spacer(),
                  Text('morphcook', style: AppFonts.display(size: 20)),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _languageStep(context, state),
                  _nameStep(context, state),
                  _dietStep(context, state),
                  _numbersStep(context, state),
                  _confirmStep(context, state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepFrame(String title, String body, Widget child, VoidCallback onNext,
      {String? nextLabel}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.display(size: 32, color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.5),
          ),
          const SizedBox(height: 14),
          child,
          const SizedBox(height: 22),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onNext,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: const BoxDecoration(color: AppColors.teal),
                child: Text(
                  nextLabel ?? context.tr('common.next').toUpperCase(),
                  style: AppFonts.mono(size: 12, color: AppColors.paper),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  Widget _languageStep(BuildContext context, AppState state) {
    return _stepFrame(
      context.tr('onb.lang.title'),
      context.tr('onb.lang.body'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final lang in ['en', 'de'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectablePill(
                label: lang == 'en' ? 'english' : 'deutsch',
                selected: widget.profile.lang == lang,
                onTap: () {
                  setState(() => widget.profile.lang = lang);
                  state.updateProfile(widget.profile);
                },
              ),
            ),
          const DashedRule(glyph: '&'),
        ],
      ),
      _next,
    );
  }

  Widget _nameStep(BuildContext context, AppState state) {
    return _stepFrame(
      context.tr('onb.name.title'),
      context.tr('onb.name.body'),
      TextField(
        controller: _nameController,
        style: AppFonts.serif(size: 18),
        decoration: InputDecoration(
          hintText: context.tr('onb.name.hint'),
          hintStyle: AppFonts.mono(size: 12, color: AppColors.inkFaint),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.inkFaint),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.teal),
          ),
        ),
      ),
      () {
        widget.profile.name = _nameController.text.trim();
        _next();
      },
    );
  }

  Widget _dietStep(BuildContext context, AppState state) {
    return _stepFrame(
      context.tr('onb.diet.title'),
      context.tr('onb.diet.body'),
      DietEditor(
        profile: widget.profile,
        onChanged: () => setState(() {}),
      ),
      _next,
    );
  }

  Widget _numbersStep(BuildContext context, AppState state) {
    final profile = widget.profile;
    return _stepFrame(
      context.tr('onb.calorie.title'),
      '${context.tr('onb.calorie.body')}\n\n${context.tr('onb.time.body')}',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(context.tr('set.calorie')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final target in [400, 550, 700, 850])
                SelectablePill(
                  label: '$target',
                  selected: profile.calorieTarget == target,
                  onTap: () => setState(() => profile.calorieTarget = target),
                  compact: true,
                ),
              SelectablePill(
                label: context.tr('onb.calorie.none'),
                selected: profile.calorieTarget == null,
                onTap: () => setState(() => profile.calorieTarget = null),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label(context.tr('set.time')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in [20, 30, 45, 60, 90])
                SelectablePill(
                  label: '$minutes ${context.trRead('common.min')}',
                  selected: profile.maxTimeMinutes == minutes,
                  onTap: () => setState(() => profile.maxTimeMinutes = minutes),
                  compact: true,
                ),
              SelectablePill(
                label: context.tr('onb.time.none'),
                selected: profile.maxTimeMinutes == null,
                onTap: () => setState(() => profile.maxTimeMinutes = null),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label(context.tr('set.effort')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final effort in state.corpus.ontology.efforts)
                SelectablePill(
                  label: state.corpus.ontology.attrLabel(effort.id, state.lang),
                  selected: profile.preferredEffort == effort.id,
                  onTap: () => setState(() => profile.preferredEffort = effort.id),
                  compact: true,
                ),
            ],
          ),
        ],
      ),
      _next,
    );
  }
  Widget _confirmStep(BuildContext context, AppState state) {
    final profile = widget.profile;
    final lang = state.lang;
    final avoidLabels = <String>[];
    for (final id in profile.avoidFlags) {
      avoidLabels.add(state.corpus.ontology.flagLabel(id, lang));
    }
    for (final id in profile.avoidIngredients) {
      avoidLabels.add(state.corpus.ingredients.nameOf(id, lang));
    }
    return _stepFrame(
      context.tr('onb.confirm.title'),
      context.tr('onb.confirm.body'),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(context.tr('onb.confirm.name'),
              profile.name == null || profile.name!.isEmpty ? '—' : profile.name!),
          _row(context.tr('onb.confirm.language'), lang == 'de' ? 'deutsch' : 'english'),
          _row(
            context.tr('onb.confirm.avoids'),
            avoidLabels.isEmpty ? context.tr('onb.confirm.avoidsNone') : avoidLabels.join(', '),
          ),
          _row(
            context.tr('onb.confirm.target'),
            profile.calorieTarget == null
                ? '—'
                : '${profile.calorieTarget} ${context.trRead('common.kcal')}',
          ),
          _row(
            context.tr('onb.confirm.time'),
            profile.maxTimeMinutes == null
                ? '—'
                : '${profile.maxTimeMinutes} ${context.trRead('common.min')}',
          ),
          _row(context.tr('onb.confirm.effort'),
              state.corpus.ontology.attrLabel(profile.preferredEffort, lang)),
          const DashedRule(glyph: '&'),
        ],
      ),
      () => _finish(state),
      nextLabel: context.tr('onb.start').toUpperCase(),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.2)),
          ),
          Expanded(
            child: Text(value, style: AppFonts.serif(size: 15, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4),
        ),
      );
}
