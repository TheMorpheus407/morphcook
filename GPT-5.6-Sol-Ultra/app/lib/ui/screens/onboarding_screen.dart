import 'package:flutter/material.dart';
import 'package:collection/collection.dart';

import '../../domain/models/ingredient.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.initialProfile,
    required this.ingredients,
    required this.hasMatchingRecipe,
    required this.onComplete,
    super.key,
  });

  final UserProfile initialProfile;
  final IngredientDictionary ingredients;
  final bool Function(UserProfile profile) hasMatchingRecipe;
  final Future<void> Function(UserProfile profile) onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pageCount = 5;
  final _controller = PageController();
  final _nameController = TextEditingController();
  var _page = 0;
  late UserProfile _profile;
  String? _diet;
  String _ingredientQuery = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _nameController.text = _profile.name;
    _diet = _profile.avoidFlags
        .where(
          (flag) => const {'vegan', 'vegetarian', 'pescatarian'}.contains(flag),
        )
        .firstOrNull;
    if (_profile.requiredAttributes.contains('halal')) _diet = 'halal';
    if (_profile.requiredAttributes.contains('kosher')) _diet = 'kosher';
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue => switch (_page) {
    1 => _nameController.text.trim().isNotEmpty,
    4 => widget.hasMatchingRecipe(
      _profile.copyWith(name: _nameController.text.trim()),
    ),
    _ => true,
  };

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    if (!_canContinue || _saving) return;
    if (_page < _pageCount - 1) {
      setState(() {
        _profile = _profile.copyWith(name: _nameController.text.trim());
        _page++;
      });
      await _controller.animateToPage(
        _page,
        duration: context.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onComplete(
        _profile.copyWith(name: _nameController.text.trim()),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    if (_page == 0) return;
    FocusScope.of(context).unfocus();
    setState(() => _page--);
    await _controller.animateToPage(
      _page,
      duration: context.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectDiet(String? value) {
    const compounds = {'vegan', 'vegetarian', 'pescatarian'};
    final avoid = _profile.avoidFlags.difference(compounds);
    final required = _profile.requiredAttributes.difference({
      'halal',
      'kosher',
    });
    if (compounds.contains(value)) avoid.add(value!);
    if (value == 'halal' || value == 'kosher') required.add(value!);
    setState(() {
      _diet = value;
      _profile = _profile.copyWith(
        avoidFlags: avoid,
        requiredAttributes: required,
      );
    });
  }

  void _toggleAvoidFlag(String flag, bool selected) {
    final next = {..._profile.avoidFlags};
    final linkedFlags = flag == 'shellfish'
        ? const {'shellfish', 'molluscs'}
        : {flag};
    selected ? next.addAll(linkedFlags) : next.removeAll(linkedFlags);
    setState(() => _profile = _profile.copyWith(avoidFlags: next));
  }

  void _toggleIngredient(String id) {
    final next = {..._profile.avoidIngredientIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    setState(() => _profile = _profile.copyWith(avoidIngredientIds: next));
  }

  @override
  Widget build(BuildContext context) {
    return MorphStringsScope(
      languageCode: _profile.languageCode,
      child: Builder(
        builder: (context) {
          final strings = context.strings;
          return Scaffold(
            body: PaperSurface(
              child: SafeArea(
                child: Column(
                  children: [
                    _OnboardingHeader(page: _page, count: _pageCount),
                    Expanded(
                      child: PageView(
                        controller: _controller,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _LanguageStep(
                            profile: _profile,
                            onLanguage: (language) => setState(
                              () => _profile = _profile.copyWith(
                                languageCode: language,
                              ),
                            ),
                          ),
                          _NameStep(
                            controller: _nameController,
                            onChanged: (_) => setState(() {}),
                          ),
                          _DietStep(
                            profile: _profile,
                            ingredients: widget.ingredients,
                            selectedDiet: _diet,
                            ingredientQuery: _ingredientQuery,
                            onDiet: _selectDiet,
                            onAvoidFlag: _toggleAvoidFlag,
                            onIngredientQuery: (query) =>
                                setState(() => _ingredientQuery = query),
                            onIngredient: _toggleIngredient,
                          ),
                          _GoalsStep(
                            profile: _profile,
                            onChanged: (profile) =>
                                setState(() => _profile = profile),
                          ),
                          _ConfirmStep(
                            profile: _profile,
                            ingredients: widget.ingredients,
                            hasMatches: widget.hasMatchingRecipe(_profile),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      child: Row(
                        children: [
                          if (_page > 0)
                            TextButton.icon(
                              onPressed: _back,
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: Text(strings('common.back')),
                            )
                          else
                            const SizedBox(width: 48),
                          const Spacer(),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 150),
                            child: FilledButton.icon(
                              onPressed: _canContinue && !_saving
                                  ? _next
                                  : null,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 17,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _page == _pageCount - 1
                                          ? Icons.menu_book_rounded
                                          : Icons.arrow_forward_rounded,
                                    ),
                              label: Text(
                                _page == _pageCount - 1
                                    ? strings('onboarding.start')
                                    : strings('common.continue'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.page, required this.count});

  final int page;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'MorphCook',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              Text(
                '${page + 1} / $count',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(1),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: (page + 1) / count,
              backgroundColor: context.morph.paperDeep,
              color: context.morph.coral,
              semanticsLabel: context.strings('common.onboardingProgress'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  const _StepFrame({
    required this.title,
    required this.body,
    required this.child,
    this.note,
  });

  final String title;
  final String body;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TapeLabel(text: context.strings('onboarding.tape')),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 12),
              Text(body, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 30),
              child,
              if (note != null) ...[
                const SizedBox(height: 18),
                Text(note!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.profile, required this.onLanguage});

  final UserProfile profile;
  final ValueChanged<String> onLanguage;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _StepFrame(
      title: strings('onboarding.language.title'),
      body: strings('onboarding.language.body'),
      child: Row(
        children: [
          Expanded(
            child: _LanguageCard(
              label: strings('onboarding.language.english'),
              note: strings('onboarding.language.englishNote'),
              selected: profile.languageCode == 'en',
              onTap: () => onLanguage('en'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _LanguageCard(
              label: strings('onboarding.language.german'),
              note: strings('onboarding.language.germanNote'),
              selected: profile.languageCode == 'de',
              onTap: () => onLanguage('de'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected
            ? context.morph.teal.withValues(alpha: .13)
            : context.morph.paperDeep.withValues(alpha: .5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(
            color: selected ? context.morph.teal : context.morph.inkMuted,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 26),
            child: Column(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.language_rounded,
                  color: context.morph.teal,
                ),
                const SizedBox(height: 12),
                Text(label, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(note, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _StepFrame(
      title: strings('onboarding.name.title'),
      body: strings('app.tagline'),
      note: strings('onboarding.name.note'),
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
        maxLength: 40,
        decoration: InputDecoration(
          labelText: strings('onboarding.name.hint'),
          prefixIcon: const Icon(Icons.person_outline_rounded),
        ),
      ),
    );
  }
}

class _DietStep extends StatelessWidget {
  const _DietStep({
    required this.profile,
    required this.ingredients,
    required this.selectedDiet,
    required this.ingredientQuery,
    required this.onDiet,
    required this.onAvoidFlag,
    required this.onIngredientQuery,
    required this.onIngredient,
  });

  final UserProfile profile;
  final IngredientDictionary ingredients;
  final String? selectedDiet;
  final String ingredientQuery;
  final ValueChanged<String?> onDiet;
  final void Function(String, bool) onAvoidFlag;
  final ValueChanged<String> onIngredientQuery;
  final ValueChanged<String> onIngredient;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final results = ingredients.search(
      ingredientQuery,
      languageCode: profile.languageCode,
      limit: 6,
    );
    const diets = [
      null,
      'vegan',
      'vegetarian',
      'pescatarian',
      'halal',
      'kosher',
    ];
    const avoidClasses = [
      'dairy',
      'gluten',
      'nuts',
      'shellfish',
      'egg',
      'soy',
      'sesame',
    ];

    return _StepFrame(
      title: strings('onboarding.diet.title'),
      body: strings('onboarding.diet.body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              for (final diet in diets)
                MorphTag(
                  label: strings('diet.${diet ?? 'none'}'),
                  selected: selectedDiet == diet,
                  onSelected: (_) => onDiet(diet),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            strings('onboarding.avoidClasses').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 5,
            children: [
              for (final flag in avoidClasses)
                MorphTag(
                  label: strings('avoid.$flag'),
                  selected: flag == 'shellfish'
                      ? profile.avoidFlags.any(
                          const {'shellfish', 'molluscs'}.contains,
                        )
                      : profile.avoidFlags.contains(flag),
                  onSelected: (selected) => onAvoidFlag(flag, selected),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            strings('onboarding.specific').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: onIngredientQuery,
            decoration: InputDecoration(
              hintText: strings('onboarding.specificHint'),
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          if (results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: context.morph.paper,
                border: Border.all(
                  color: context.morph.ink.withValues(alpha: .4),
                ),
              ),
              child: Column(
                children: [
                  for (final result in results)
                    CheckboxListTile(
                      dense: true,
                      title: Text(result.name.resolve(profile.languageCode)),
                      subtitle: result.children.isEmpty
                          ? null
                          : Text(
                              strings.format('onboarding.groupedIngredients', {
                                'count': result.children.length,
                              }),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                      value: profile.avoidIngredientIds.contains(result.id),
                      onChanged: (_) => onIngredient(result.id),
                    ),
                ],
              ),
            ),
          if (profile.avoidIngredientIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              children: [
                for (final id in profile.avoidIngredientIds)
                  InputChip(
                    label: Text(
                      ingredients[id]?.name.resolve(profile.languageCode) ?? id,
                    ),
                    onDeleted: () => onIngredient(id),
                  ),
              ],
            ),
          ],
          if (selectedDiet == 'halal' || selectedDiet == 'kosher') ...[
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: context.morph.teal),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    strings('settings.compatibleNote'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({required this.profile, required this.onChanged});

  final UserProfile profile;
  final ValueChanged<UserProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    const times = [15, 30, 45, 60, 90];
    const efforts = ['easy', 'medium', 'hard'];
    return _StepFrame(
      title: strings('onboarding.goals.title'),
      body: strings('app.tagline'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings('onboarding.calories').toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              TapeLabel(
                text: '${profile.calorieTarget} kcal',
                angle: .025,
                color: context.morph.mustard.withValues(alpha: .52),
              ),
            ],
          ),
          Slider(
            value: profile.calorieTarget.toDouble(),
            min: 300,
            max: 1000,
            divisions: 14,
            label: '${profile.calorieTarget} kcal',
            onChanged: (value) => onChanged(
              profile.copyWith(calorieTarget: (value / 50).round() * 50),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            strings('onboarding.time').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final minutes in times)
                MorphTag(
                  label: '$minutes ${strings('common.minutes')}',
                  selected: profile.maxTimeMinutes == minutes,
                  onSelected: (_) =>
                      onChanged(profile.copyWith(maxTimeMinutes: minutes)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            strings('onboarding.effort').toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 9),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: [
              for (final effort in efforts)
                ButtonSegment(
                  value: effort,
                  label: Text(strings('effort.$effort')),
                ),
            ],
            selected: {profile.preferredEffort},
            onSelectionChanged: (selected) =>
                onChanged(profile.copyWith(preferredEffort: selected.first)),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.profile,
    required this.ingredients,
    required this.hasMatches,
  });

  final UserProfile profile;
  final IngredientDictionary ingredients;
  final bool hasMatches;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return _StepFrame(
      title: strings('onboarding.confirm.title'),
      body: strings('onboarding.confirm.body'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.morph.paperDeep.withValues(alpha: .5),
          border: Border.all(color: context.morph.ink.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.name,
              style: morphHandwriting(
                context,
                size: 32,
                color: context.morph.coral,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _SummaryLine(
              icon: Icons.schedule_rounded,
              text: '${profile.maxTimeMinutes} ${strings('common.minutes')}',
            ),
            _SummaryLine(
              icon: Icons.local_fire_department_outlined,
              text:
                  '${profile.calorieTarget} kcal ± ${profile.calorieTolerance}',
            ),
            _SummaryLine(
              icon: Icons.soup_kitchen_outlined,
              text: strings('effort.${profile.preferredEffort}'),
            ),
            if (profile.avoidFlags.isNotEmpty)
              _SummaryLine(
                icon: Icons.shield_outlined,
                text: _localizedAvoidFlags(strings, profile.avoidFlags),
              ),
            if (profile.requiredAttributes.isNotEmpty)
              _SummaryLine(
                icon: Icons.restaurant_menu_rounded,
                text: profile.requiredAttributes
                    .map((attribute) => strings.option('diet', attribute))
                    .join(' · '),
              ),
            if (profile.avoidIngredientIds.isNotEmpty)
              _SummaryLine(
                icon: Icons.no_food_rounded,
                text: profile.avoidIngredientIds
                    .map(
                      (id) =>
                          ingredients[id]?.name.resolve(profile.languageCode) ??
                          id.replaceAll('-', ' '),
                    )
                    .join(' · '),
              ),
            if (!hasMatches) ...[
              const SizedBox(height: 12),
              Text(
                strings('onboarding.noMatch'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: context.morph.coral),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.morph.teal),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

String _localizedAvoidFlags(MorphStrings strings, Set<String> flags) {
  final remaining = {...flags};
  final labels = <String>[];
  if (remaining.remove('shellfish') | remaining.remove('molluscs')) {
    labels.add(strings('avoid.shellfish'));
  }
  labels.addAll(remaining.map((flag) => strings.option('avoid', flag)));
  return labels.join(' · ');
}
