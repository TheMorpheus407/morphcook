import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../models/ingredient_dict.dart';
import '../../models/profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/profile_widgets.dart';

/// First run. A calm, full-screen paper sequence: welcome + language → name →
/// diet & allergies → targets → confirm. We keep a local [Profile] draft and
/// only persist on the final step, except the language, which we set live so the
/// rest of the flow reads in the chosen tongue. After [completeOnboarding] the
/// app root swaps to the main shell on its own — we never navigate manually.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _pager = PageController();
  final _nameController = TextEditingController();

  late Profile _draft;
  bool _initialised = false;
  int _page = 0;

  static const _stepCount = 5;

  static const _calorieMin = 200.0;
  static const _calorieMax = 1200.0;
  static const _timeOptions = [15, 30, 60];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      _draft = context.scope.services.profile.profile;
      _nameController.text = _draft.name;
      _initialised = true;
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      _draft.reduceMotion ??
      MediaQuery.maybeOf(context)?.disableAnimations ??
      false;

  void _go(int page) {
    setState(() => _page = page);
    if (_reduceMotion) {
      _pager.jumpToPage(page);
    } else {
      _pager.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _next() {
    if (_page < _stepCount - 1) _go(_page + 1);
  }

  void _back() {
    if (_page > 0) _go(_page - 1);
  }

  void _setLang(AppLang lang) {
    setState(() => _draft = _draft.copyWith(lang: lang));
    // Set live so the remaining steps render in the chosen language.
    context.scope.services.profile.setLang(lang);
  }

  Future<void> _finish() async {
    final draft = _draft.copyWith(
      name: _nameController.text.trim(),
      onboarded: true,
    );
    await context.scope.services.profile.completeOnboarding(draft);
    // Root listens to the profile and swaps to the shell — no manual nav.
  }

  @override
  Widget build(BuildContext context) {
    return PaperBackground(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pager,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  _welcomeStep(),
                  _nameStep(),
                  _dietStep(),
                  _targetsStep(),
                  _confirmStep(),
                ],
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  // --- steps ---------------------------------------------------------------

  Widget _stepScaffold({required String title, String? sub, required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toLowerCase(),
            style: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 32,
              color: AppColors.ink,
              height: 1.05,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 10),
            Text(
              sub,
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontSize: 16,
                color: AppColors.inkSoft,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          DashedRule(),
          const SizedBox(height: 22),
          ...children,
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _welcomeStep() {
    return _stepScaffold(
      title: context.tr('onb.welcome'),
      sub: context.tr('onb.welcome_sub'),
      children: [
        MonoLabel(context.tr('onb.lang_q'), color: AppColors.terracotta),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _langChoice(AppLang.en, 'English')),
            const SizedBox(width: 12),
            Expanded(child: _langChoice(AppLang.de, 'Deutsch')),
          ],
        ),
      ],
    );
  }

  Widget _langChoice(AppLang lang, String label) {
    final isOn = _draft.lang == lang;
    return GestureDetector(
      onTap: () => _setLang(lang),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isOn ? AppColors.terracotta.withValues(alpha: 0.10) : null,
          border: Border.all(
            color: isOn ? AppColors.terracotta : AppColors.inkSoft,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            fontSize: 20,
            color: isOn ? AppColors.terracotta : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _nameStep() {
    return _stepScaffold(
      title: context.tr('onb.name_q'),
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            fontSize: 24,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: context.tr('onb.name_hint'),
            hintStyle: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              color: AppColors.inkFaint,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkFaint),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.terracotta),
            ),
          ),
          onSubmitted: (_) => _next(),
        ),
      ],
    );
  }

  Widget _dietStep() {
    return _stepScaffold(
      title: context.tr('onb.diet_q'),
      sub: context.tr('onb.diet_sub'),
      children: [
        DietPicker(
          selected: _draft.avoidFlags,
          onChanged: (s) => setState(() => _draft = _draft.copyWith(avoidFlags: s)),
        ),
        const SizedBox(height: 26),
        MonoLabel(context.tr('onb.allergy_q')),
        const SizedBox(height: 12),
        IngredientAvoidanceField(
          selected: _draft.avoidIngredients,
          onChanged: (s) =>
              setState(() => _draft = _draft.copyWith(avoidIngredients: s)),
        ),
      ],
    );
  }

  Widget _targetsStep() {
    final noCalLimit = _draft.calorieTarget == null;
    final cal = (_draft.calorieTarget ?? 600).toDouble().clamp(_calorieMin, _calorieMax);

    return _stepScaffold(
      title: context.tr('onb.targets_q'),
      sub: context.tr('onb.targets_sub'),
      children: [
        // Calorie target
        Row(
          children: [
            Expanded(child: MonoLabel(context.tr('onb.calorie_q'))),
            Text(
              noCalLimit
                  ? context.tr('onb.no_limit')
                  : '${cal.round()} ${context.tr('common.kcal')}',
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 18,
                color: AppColors.terracotta,
              ),
            ),
          ],
        ),
        Opacity(
          opacity: noCalLimit ? 0.4 : 1,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.terracotta,
              inactiveTrackColor: AppColors.inkFaint.withValues(alpha: 0.4),
              thumbColor: AppColors.terracotta,
              overlayColor: AppColors.terracotta.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: cal,
              min: _calorieMin,
              max: _calorieMax,
              divisions: ((_calorieMax - _calorieMin) / 50).round(),
              onChanged: noCalLimit
                  ? null
                  : (v) => setState(
                      () => _draft = _draft.copyWith(calorieTarget: v.round())),
            ),
          ),
        ),
        _switchRow(
          label: context.tr('onb.no_limit'),
          value: noCalLimit,
          onChanged: (v) => setState(() => _draft = _draft.copyWith(
              calorieTarget: v ? null : 600)),
        ),
        const SizedBox(height: 24),
        DashedRule(),
        const SizedBox(height: 22),

        // Time budget
        MonoLabel(context.tr('onb.time_q')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _timeOptions)
              _pill(
                label: '$m ${context.tr('common.minutes')}',
                isOn: _draft.maxTimeMinutes == m,
                onTap: () => setState(
                    () => _draft = _draft.copyWith(maxTimeMinutes: m)),
              ),
            _pill(
              label: context.tr('onb.no_limit'),
              isOn: _draft.maxTimeMinutes == null,
              onTap: () => setState(
                  () => _draft = _draft.copyWith(maxTimeMinutes: null)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        DashedRule(),
        const SizedBox(height: 22),

        // Effort mood
        MonoLabel(context.tr('settings.effort')),
        const SizedBox(height: 12),
        EffortMoodPicker(
          selected: _draft.preferredEffort,
          onChanged: (id) =>
              setState(() => _draft = _draft.copyWith(preferredEffort: id)),
        ),
      ],
    );
  }

  Widget _confirmStep() {
    final de = context.lang == AppLang.de;
    final name = _nameController.text.trim();
    final flags = _draft.avoidFlags
        .map((id) => _flagLabel(id))
        .where((s) => s.isNotEmpty)
        .toList();
    final dict = context.scope.corpus.ingredients;
    final avoided = _draft.avoidIngredients
        .map((id) => dict.node(id))
        .whereType<IngredientNode>()
        .map((n) => context.loc(n.label))
        .toList();

    final calorieLine = _draft.calorieTarget == null
        ? context.tr('onb.no_limit')
        : '${_draft.calorieTarget} ${context.tr('common.kcal')}';
    final timeLine = _draft.maxTimeMinutes == null
        ? context.tr('onb.no_limit')
        : '${_draft.maxTimeMinutes} ${context.tr('common.minutes')}';
    final effortLabel = _effortLabel(_draft.preferredEffort);

    return _stepScaffold(
      title: context.tr('onb.confirm_q'),
      sub: context.tr('onb.confirm_sub'),
      children: [
        if (name.isNotEmpty)
          _summaryLine(de ? 'Name' : 'name', name),
        _summaryLine(
          context.tr('settings.diet'),
          flags.isEmpty ? (de ? 'alles' : 'everything') : flags.join(', '),
        ),
        if (avoided.isNotEmpty)
          _summaryLine(context.tr('settings.avoid_ingredients'), avoided.join(', ')),
        _summaryLine(context.tr('onb.calorie_q'), calorieLine),
        _summaryLine(context.tr('onb.time_q'), timeLine),
        _summaryLine(context.tr('settings.effort'), effortLabel),
      ],
    );
  }

  String _flagLabel(String id) {
    final c = context.scope.corpus.ontology.compound(id);
    return c != null ? context.loc(c.label) : id;
  }

  String _effortLabel(String id) {
    for (final e in context.scope.corpus.ontology.effort) {
      if (e.id == id) return context.loc(e.label);
    }
    return id;
  }

  // --- shared bits ---------------------------------------------------------

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: MonoLabel(label)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontStyle: FontStyle.italic,
                fontSize: 17,
                color: AppColors.ink,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 12,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.terracotta,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _pill({
    required String label,
    required bool isOn,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isOn ? AppColors.terracotta.withValues(alpha: 0.10) : null,
          border: Border.all(
            color: isOn ? AppColors.terracotta : AppColors.inkSoft,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Fonts.mono,
            fontSize: 13,
            color: isOn ? AppColors.terracotta : AppColors.ink,
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    final isLast = _page == _stepCount - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        children: [
          DashedRule(),
          const SizedBox(height: 12),
          Row(
            children: [
              // Back (hidden on first page but keeps layout stable)
              SizedBox(
                width: 80,
                child: _page == 0
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: _back,
                        child: Text(
                          context.tr('common.back'),
                          style: const TextStyle(
                            fontFamily: Fonts.mono,
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ),
              ),
              Expanded(child: _dots()),
              SizedBox(
                width: 140,
                child: _primaryButton(
                  label: isLast ? context.tr('onb.start') : context.tr('common.next'),
                  onTap: isLast ? _finish : _next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _stepCount; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _page
                  ? AppColors.terracotta
                  : AppColors.inkFaint.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }

  Widget _primaryButton({required String label, required VoidCallback onTap}) {
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
              color: AppColors.paper,
            ),
          ),
        ),
      ),
    );
  }
}
