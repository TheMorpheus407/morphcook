import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/corpus_repository.dart';
import '../../core/models/local_text.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/paper_grain.dart';
import '../../shared/widgets/polaroid_card.dart';
import 'strings.dart';

/// First-run onboarding: language, name, diet & allergies, calorie/time
/// targets, confirmation. Writes the finished profile via
/// [ProfileStore.completeOnboarding]; AppGate rebuilds on its own.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 5;

  int _step = 0;

  late String _lang;
  late final TextEditingController _nameController;
  final TextEditingController _searchController = TextEditingController();

  final Set<String> _avoidFlags = {};
  final Set<String> _avoidIngredients = {};
  final Set<String> _requiredAttributes = {};

  double _calories = 600;
  double _minutes = 60;
  String _effort = 'easy';

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileStore>().profile;
    _lang = profile.lang;
    _nameController = TextEditingController(text: profile.name);
    _calories = profile.calorieTarget.toDouble();
    _minutes = profile.maxTimeMinutes.toDouble();
    _effort = profile.preferredEffort;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _t(String key) => strings[key]?[_lang] ?? strings[key]?['en'] ?? key;

  bool get _reduceMotion =>
      context.read<ProfileStore>().profile.reduceMotion ??
      MediaQuery.disableAnimationsOf(context);

  void _goTo(int step) {
    setState(() => _step = step.clamp(0, _stepCount - 1));
  }

  void _selectLanguage(String lang) {
    setState(() => _lang = lang);
    _goTo(1);
  }

  Future<void> _finish() async {
    final store = context.read<ProfileStore>();
    final profile = store.profile.copyWith(
      lang: _lang,
      name: _nameController.text.trim(),
      avoidFlags: _avoidFlags,
      avoidIngredients: _avoidIngredients,
      requiredAttributes: _requiredAttributes,
      calorieTarget: _calories.round(),
      maxTimeMinutes: _minutes.round(),
      preferredEffort: _effort,
    );
    await store.completeOnboarding(profile);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion;
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: Stack(
        children: [
          const Positioned.fill(child: PaperGrain()),
          SafeArea(
            child: Column(
              children: [
                _ProgressHeader(
                  step: _step,
                  total: _stepCount,
                  label: '${_t('onboarding.step')} ${_step + 1} / $_stepCount',
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildStep(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _buildLanguageStep();
      case 1:
        return _buildNameStep();
      case 2:
        return _buildDietStep(context);
      case 3:
        return _buildTargetsStep();
      default:
        return _buildConfirmStep(context);
    }
  }

  /// Shared scrollable step layout: Playfair italic title, dashed rule,
  /// content, optional Caveat margin note, optional footer buttons.
  Widget _stepScaffold({
    required String title,
    String? note,
    required List<Widget> children,
    Widget? footer,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.headline(size: 30)),
          const SizedBox(height: 12),
          const DashedRule(),
          const SizedBox(height: 20),
          ...children,
          if (note != null) ...[
            const SizedBox(height: 20),
            Text(note, style: AppText.handwritten(size: 19)),
          ],
          if (footer != null) ...[const SizedBox(height: 28), footer],
        ],
      ),
    );
  }

  Widget _navFooter({VoidCallback? onNext, String? nextLabel}) {
    return Row(
      children: [
        if (_step > 0)
          _OutlineButton(
            label: _t('onboarding.common.back'),
            onTap: () => _goTo(_step - 1),
          ),
        const Spacer(),
        if (onNext != null)
          _OutlineButton(
            label: nextLabel ?? _t('onboarding.common.next'),
            onTap: onNext,
            primary: true,
          ),
      ],
    );
  }

  // ---- step 0: language ----------------------------------------------------

  Widget _buildLanguageStep() {
    return _stepScaffold(
      title: _t('onboarding.lang.title'),
      note: _t('onboarding.lang.note'),
      children: [
        Text(
          _t('onboarding.welcome'),
          style: AppText.handwritten(size: 22, color: AppColors.coral),
        ),
        const SizedBox(height: 24),
        _LanguageCard(label: 'english', onTap: () => _selectLanguage('en')),
        const SizedBox(height: 14),
        _LanguageCard(label: 'deutsch', onTap: () => _selectLanguage('de')),
      ],
    );
  }

  // ---- step 1: name ---------------------------------------------------------

  Widget _buildNameStep() {
    return _stepScaffold(
      title: _t('onboarding.name.title'),
      note: _t('onboarding.name.note'),
      children: [
        TextField(
          controller: _nameController,
          style: AppText.body(size: 20),
          cursorColor: AppColors.coral,
          decoration: InputDecoration(
            hintText: _t('onboarding.name.hint'),
            hintStyle: AppText.handwritten(size: 22),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft, width: 1),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.ink, width: 1.4),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _goTo(2),
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              _nameController.clear();
              _goTo(2);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _t('onboarding.common.skip'),
                style: AppText.monoLabel(size: 11).copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.inkSoft,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _navFooter(onNext: () => _goTo(2)),
        ],
      ),
    );
  }

  // ---- step 2: diet & allergies ----------------------------------------------

  Widget _buildDietStep(BuildContext context) {
    final corpus = context.read<CorpusRepository>();
    final compound = corpus.ontology.compoundFlags.values.toList();
    final classes = corpus.ontology.containsFlags.values.toList();

    final query = _searchController.text;
    final results = query.trim().isEmpty
        ? const []
        : corpus.ingredientDictionary
              .search(query, _lang)
              .where((node) => !_avoidIngredients.contains(node.id))
              .take(6)
              .toList();

    return _stepScaffold(
      title: _t('onboarding.diet.title'),
      note: _t('onboarding.diet.note'),
      children: [
        SectionRule(label: _t('onboarding.diet.compound')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final flag in compound)
              _ChoiceChip(
                label: localize(flag.label, _lang),
                selected: _avoidFlags.contains(flag.id),
                onTap: () => setState(() {
                  if (!_avoidFlags.remove(flag.id)) _avoidFlags.add(flag.id);
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SectionRule(label: _t('onboarding.diet.classes')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final flag in classes)
              _ChoiceChip(
                label: localize(flag.label, _lang),
                selected: _avoidFlags.contains(flag.id),
                quiet: true,
                onTap: () => setState(() {
                  if (!_avoidFlags.remove(flag.id)) _avoidFlags.add(flag.id);
                }),
              ),
          ],
        ),
        const SizedBox(height: 24),
        SectionRule(label: _t('onboarding.diet.specific')),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          style: AppText.body(size: 16),
          cursorColor: AppColors.coral,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: _t('onboarding.diet.search_hint'),
            hintStyle: AppText.handwritten(size: 19),
            isDense: true,
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft, width: 1),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.ink, width: 1.4),
            ),
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 4),
          for (final node in results)
            InkWell(
              onTap: () => setState(() {
                _avoidIngredients.add(node.id);
                _searchController.clear();
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        localize(node.name, _lang),
                        style: AppText.body(size: 15),
                      ),
                    ),
                    Text('+', style: AppText.monoLabel(color: AppColors.teal)),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(_t('onboarding.diet.chosen'), style: AppText.monoLabel()),
        const SizedBox(height: 10),
        if (_avoidIngredients.isEmpty)
          Text(
            _t('onboarding.diet.empty'),
            style: AppText.body(size: 14, color: AppColors.inkSoft),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in _avoidIngredients)
                _RemovableChip(
                  label: _ingredientLabel(corpus, id),
                  onRemove: () => setState(() => _avoidIngredients.remove(id)),
                ),
            ],
          ),
        const SizedBox(height: 24),
        SectionRule(label: _t('onboarding.require.title')),
        const SizedBox(height: 8),
        _RequireToggle(
          label: _t('onboarding.require.halal'),
          value: _requiredAttributes.contains('halal'),
          onChanged: (v) => setState(() {
            if (v) {
              _requiredAttributes.add('halal');
            } else {
              _requiredAttributes.remove('halal');
            }
          }),
        ),
        _RequireToggle(
          label: _t('onboarding.require.kosher'),
          value: _requiredAttributes.contains('kosher'),
          onChanged: (v) => setState(() {
            if (v) {
              _requiredAttributes.add('kosher');
            } else {
              _requiredAttributes.remove('kosher');
            }
          }),
        ),
      ],
      footer: _navFooter(onNext: () => _goTo(3)),
    );
  }

  String _ingredientLabel(CorpusRepository corpus, String id) {
    final node = corpus.ingredientDictionary.byId(id);
    return node == null ? id : localize(node.name, _lang);
  }

  // ---- step 3: calorie target & time budget ------------------------------------

  Widget _buildTargetsStep() {
    return _stepScaffold(
      title: _t('onboarding.targets.title'),
      note: _t('onboarding.targets.note'),
      children: [
        SectionRule(label: _t('onboarding.targets.calories')),
        const SizedBox(height: 6),
        Text(
          '${_calories.round()} kcal',
          style: AppText.monoLabel(size: 20, color: AppColors.ink),
        ),
        Slider(
          value: _calories,
          min: 300,
          max: 1000,
          divisions: 14,
          activeColor: AppColors.coral,
          inactiveColor: AppColors.coralSoft,
          onChanged: (v) => setState(() => _calories = v),
        ),
        const SizedBox(height: 12),
        SectionRule(label: _t('onboarding.targets.time')),
        const SizedBox(height: 6),
        Text(
          '${_minutes.round()} min',
          style: AppText.monoLabel(size: 20, color: AppColors.ink),
        ),
        Slider(
          value: _minutes,
          min: 15,
          max: 120,
          divisions: 21,
          activeColor: AppColors.teal,
          inactiveColor: AppColors.tealSoft,
          onChanged: (v) => setState(() => _minutes = v),
        ),
        const SizedBox(height: 12),
        SectionRule(label: _t('onboarding.targets.effort')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in const ['easy', 'medium', 'hard'])
              _ChoiceChip(
                label: _t('onboarding.effort.$level'),
                selected: _effort == level,
                onTap: () => setState(() => _effort = level),
              ),
          ],
        ),
      ],
      footer: _navFooter(onNext: () => _goTo(4)),
    );
  }

  // ---- step 4: confirm --------------------------------------------------------

  Widget _buildConfirmStep(BuildContext context) {
    final corpus = context.read<CorpusRepository>();

    final avoids = <String>[
      for (final id in _avoidFlags)
        localize(corpus.ontology.flagLabel(id), _lang),
      for (final id in _avoidIngredients) _ingredientLabel(corpus, id),
    ];
    final requires = <String>[
      if (_requiredAttributes.contains('halal')) 'halal',
      if (_requiredAttributes.contains('kosher')) 'kosher',
    ];

    return _stepScaffold(
      title: _t('onboarding.confirm.title'),
      children: [
        Center(
          child: PolaroidCard(
            rotation: -0.015,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _summaryRow(
                  _t('onboarding.summary.language'),
                  _lang == 'de' ? 'deutsch' : 'english',
                  0,
                ),
                _summaryRow(
                  _t('onboarding.summary.name'),
                  _nameController.text.trim().isEmpty
                      ? _t('onboarding.summary.no_name')
                      : _nameController.text.trim(),
                  1,
                ),
                _summaryRow(
                  _t('onboarding.summary.avoids'),
                  avoids.isEmpty
                      ? _t('onboarding.summary.none')
                      : avoids.join(', '),
                  2,
                ),
                _summaryRow(
                  _t('onboarding.summary.requires'),
                  requires.isEmpty
                      ? _t('onboarding.summary.none')
                      : requires.join(', '),
                  2,
                ),
                _summaryRow(
                  _t('onboarding.summary.calories'),
                  '${_calories.round()} kcal',
                  3,
                ),
                _summaryRow(
                  _t('onboarding.summary.time'),
                  '${_minutes.round()} min',
                  3,
                ),
                _summaryRow(
                  _t('onboarding.summary.effort'),
                  _t('onboarding.effort.$_effort'),
                  3,
                ),
              ],
            ),
          ),
        ),
      ],
      note: _t('onboarding.confirm.note'),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OutlineButton(
            label: _t('onboarding.confirm.begin'),
            primary: true,
            centered: true,
            onTap: _finish,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _OutlineButton(
                label: _t('onboarding.common.back'),
                onTap: () => _goTo(3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, int editStep) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(label, style: AppText.monoLabel(size: 10)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: AppText.body(size: 14))),
          GestureDetector(
            onTap: () => _goTo(editStep),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _t('onboarding.common.edit'),
                style: AppText.monoLabel(size: 10, color: AppColors.coral)
                    .copyWith(
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.coral,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mono step counter plus a row of small dash indicators.
class _ProgressHeader extends StatelessWidget {
  final int step;
  final int total;
  final String label;

  const _ProgressHeader({
    required this.step,
    required this.total,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      child: Row(
        children: [
          Text(label, style: AppText.monoLabel()),
          const Spacer(),
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Container(
              width: 16,
              height: 2,
              color: i < step
                  ? AppColors.teal
                  : i == step
                  ? AppColors.coral
                  : AppColors.inkSoft.withValues(alpha: 0.3),
            ),
          ],
        ],
      ),
    );
  }
}

/// Large calm language option card.
class _LanguageCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _LanguageCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.polaroid,
          border: Border.all(color: AppColors.ink, width: 1.1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Center(child: Text(label, style: AppText.headline(size: 24))),
      ),
    );
  }
}

/// Checkbox-style chip for avoid-flags. [quiet] softens secondary groups.
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool quiet;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? AppColors.teal
        : quiet
        ? AppColors.inkSoft.withValues(alpha: 0.5)
        : AppColors.inkSoft;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.tealSoft : Colors.transparent,
          border: Border.all(color: border, width: selected ? 1.1 : 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label.toLowerCase(),
          style: AppText.monoLabel(
            size: 11,
            color: selected
                ? AppColors.ink
                : quiet
                ? AppColors.inkSoft
                : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// Removable chip for chosen ingredient avoidances.
class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onRemove,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.coralSoft,
          border: Border.all(color: AppColors.coral, width: 0.8),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toLowerCase(),
              style: AppText.monoLabel(size: 11, color: AppColors.ink),
            ),
            const SizedBox(width: 6),
            Text(
              '×',
              style: AppText.monoLabel(size: 12, color: AppColors.coral),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ink-outlined toggle row for required attributes.
class _RequireToggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RequireToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? AppColors.teal : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.teal : AppColors.inkSoft,
                  width: 1.1,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: value
                  ? const Icon(Icons.check, size: 13, color: AppColors.paper)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.toLowerCase(),
                style: AppText.monoLabel(size: 11, color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ink-outlined button with generous padding and lowercase mono label.
class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool centered;

  const _OutlineButton({
    required this.label,
    this.onTap,
    this.primary = false,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
        decoration: BoxDecoration(
          color: primary ? AppColors.ink : Colors.transparent,
          border: Border.all(color: AppColors.ink, width: 1.2),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label.toLowerCase(),
          textAlign: centered ? TextAlign.center : null,
          style: AppText.monoLabel(
            size: 12,
            color: primary ? AppColors.paper : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
