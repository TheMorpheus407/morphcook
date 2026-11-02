import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/fields.dart';
import '../../design/widgets/paper.dart';
import '../../design/widgets/rules.dart';
import '../../l10n/strings.dart';
import '../../models/ontology.dart';
import '../../state/app_state.dart';
import '../../state/profile_controller.dart';

/// The onboarding flow.
///
/// language → name → diet & allergies → calorie target & time budget →
/// confirm. Every step writes straight into the profile, so the feed is
/// already correct the moment onboarding ends.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ingredientController = TextEditingController();

  int _page = 0;
  List<dynamic> _ingredientResults = <dynamic>[];

  static const int _pageCount = 7;

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _controller.animateToPage(
      page,
      duration: MotionScope.dur(context, Motion.medium),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() {
    if (_page >= _pageCount - 1) {
      context.read<ProfileController>().completeOnboarding();
      return;
    }
    _goTo(_page + 1);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _ProgressDots(page: _page, total: _pageCount),
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _page = page),
                  children: <Widget>[
                    _WelcomeStep(strings: strings),
                    _LanguageStep(strings: strings),
                    _NameStep(
                      strings: strings,
                      controller: _nameController,
                    ),
                    _DietStep(strings: strings),
                    _AllergyStep(
                      strings: strings,
                      controller: _ingredientController,
                      results: _ingredientResults,
                      onSearch: _searchIngredients,
                      onPick: _pickIngredient,
                    ),
                    _TargetsStep(strings: strings),
                    _ConfirmStep(
                      strings: strings,
                      onEdit: _goTo,
                    ),
                  ],
                ),
              ),
              _Footer(
                page: _page,
                strings: strings,
                onBack: () => _goTo(_page - 1),
                onNext: _next,
                onSkip: () => context
                    .read<ProfileController>()
                    .completeOnboarding(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _searchIngredients(String value) {
    final state = context.read<AppState>();
    final results = value.trim().isEmpty
        ? <dynamic>[]
        : state.corpus.ingredients.search(value, lang: state.lang);
    setState(() => _ingredientResults = results.take(8).toList());
  }

  void _pickIngredient(dynamic node) {
    context.read<ProfileController>().addAvoidIngredient(node.id as String);
    _ingredientController.clear();
    setState(() => _ingredientResults = <dynamic>[]);
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.page, required this.total});

  final int page;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 6),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < total; i++)
            Expanded(
              child: Container(
                height: 2,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 5),
                decoration: BoxDecoration(
                  color: i <= page ? MC.coral : MC.ruleFaint,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Step 0 — the welcome.
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.strings});

  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 40, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('✳', style: Type.scriptLarge(size: 54, color: MC.coral)),
          const SizedBox(height: 10),
          Text(strings.onboardWelcomeTitle, style: Type.display(size: 36)),
          const SizedBox(height: 10),
          const DashedRule(),
          const SizedBox(height: 16),
          Text(strings.onboardWelcomeBody, style: Type.body(size: 16)),
          const SizedBox(height: 18),
          Text(
            strings.tagline,
            style: Type.script(size: 20, color: MC.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// Step 1 — language.
class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.strings});

  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.onboardStepLanguage, style: Type.display(size: 30)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 22),
          SegmentedChoice<String>(
            value: profile.lang,
            options: const <({String value, String label})>[
              (value: 'en', label: 'English'),
              (value: 'de', label: 'Deutsch'),
            ],
            onChanged: (value) =>
                context.read<ProfileController>().setLanguage(value),
          ),
        ],
      ),
    );
  }
}

/// Step 2 — name.
class _NameStep extends StatelessWidget {
  const _NameStep({required this.strings, required this.controller});

  final Strings strings;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.onboardStepName, style: Type.display(size: 30)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 22),
          PaperField(
            controller: controller,
            hint: strings.onboardNamePlaceholder,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (value) =>
                context.read<ProfileController>().setName(value),
          ),
          const SizedBox(height: 12),
          Text(strings.onboardNoName, style: Type.script(size: 19)),
        ],
      ),
    );
  }
}

/// Step 3 — diet.
class _DietStep extends StatelessWidget {
  const _DietStep({required this.strings});

  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile.profile;
    final ontology = state.corpus.ontology;

    final groups = <String, List<FlagDefinition>>{};
    for (final flag in ontology.avoid.values) {
      groups.putIfAbsent(flag.category, () => <FlagDefinition>[]).add(flag);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.onboardStepDiet, style: Type.display(size: 30)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 14),
          Text(strings.onboardingDietNote, style: Type.small(size: 13)),
          const SizedBox(height: 18),
          for (final entry in groups.entries) ...<Widget>[
            Text(
              entry.key.toUpperCase(),
              style: Type.label(size: 9),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final flag in entry.value)
                  _ChoicePill(
                    label: flag.label.resolve(strings.lang),
                    selected: profile.avoidFlags.contains(flag.id),
                    onTap: () => context
                        .read<ProfileController>()
                        .toggleAvoidFlag(flag.id),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

/// Step 4 — specific ingredients to avoid.
class _AllergyStep extends StatelessWidget {
  const _AllergyStep({
    required this.strings,
    required this.controller,
    required this.results,
    required this.onSearch,
    required this.onPick,
  });

  final Strings strings;
  final TextEditingController controller;
  final List<dynamic> results;
  final ValueChanged<String> onSearch;
  final ValueChanged<dynamic> onPick;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.onboardStepAllergies, style: Type.display(size: 30)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            onChanged: onSearch,
            style: Type.body(size: 15, color: MC.ink),
            cursorColor: MC.coral,
            decoration: InputDecoration(
              hintText: strings.onboardSearchIngredient,
              hintStyle: Type.body(size: 14, color: MC.inkGhost),
              filled: true,
              fillColor: MC.card,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: MC.ruleFaint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: MC.ruleFaint),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: MC.coral),
              ),
            ),
          ),
          if (results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: MC.card,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: MC.ruleFaint),
              ),
              child: Column(
                children: <Widget>[
                  for (final node in results)
                    ListTile(
                      dense: true,
                      title: Text(
                        node.label.resolve(strings.lang) as String,
                        style: Type.body(size: 14, color: MC.ink),
                      ),
                      subtitle: node.parentId == null
                          ? null
                          : Text(
                              '${node.parentId}'.split('.').last.replaceAll('-', ' '),
                              style: Type.label(size: 8.5),
                            ),
                      onTap: () => onPick(node),
                    ),
                ],
              ),
            ),
          if (profile.avoidIngredients.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final id in profile.avoidIngredients)
                  _ChoicePill(
                    label: state.corpus.ingredients.node(id)?.label.resolve(
                          strings.lang,
                        ) ??
                        id,
                    selected: true,
                    onTap: () => context
                        .read<ProfileController>()
                        .removeAvoidIngredient(id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Step 5 — the everyday targets.
class _TargetsStep extends StatelessWidget {
  const _TargetsStep({required this.strings});

  final Strings strings;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile.profile;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.onboardStepTargets, style: Type.display(size: 30)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 20),
          _TargetRow(
            label: strings.onboardCalorieTarget,
            value: profile.calorieTarget.toDouble(),
            min: 200,
            max: 1200,
            divisions: 50,
            suffix: 'kcal',
            onChanged: (value) => context
                .read<ProfileController>()
                .setCalorieTarget(value.round()),
          ),
          _TargetRow(
            label: strings.onboardTimeBudget,
            value: profile.maxTimeMinutes.toDouble(),
            min: 10,
            max: 180,
            divisions: 34,
            suffix: 'min',
            onChanged: (value) => context
                .read<ProfileController>()
                .setMaxTimeMinutes(value.round()),
          ),
          const SizedBox(height: 10),
          Text(
            strings.settingsEffort.toUpperCase(),
            style: Type.label(size: 9.5),
          ),
          const SizedBox(height: 8),
          SegmentedChoice<String>(
            value: profile.preferredEffort,
            options: <({String value, String label})>[
              (value: 'easy', label: strings.effortLabel('easy')),
              (value: 'medium', label: strings.effortLabel('medium')),
              (value: 'hard', label: strings.effortLabel('hard')),
            ],
            onChanged: (value) =>
                context.read<ProfileController>().setPreferredEffort(value),
          ),
        ],
      ),
    );
  }
}

/// Step 6 — confirmation.
class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.strings, required this.onEdit});

  final Strings strings;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile.profile;
    final ontology = state.corpus.ontology;

    final avoidLabels = profile.avoidFlags
        .map((id) => ontology.avoid[id]?.label.resolve(strings.lang) ?? id)
        .toList();
    final ingredientLabels = profile.avoidIngredients
        .map(
          (id) => state.corpus.ingredients.node(id)?.label.resolve(strings.lang) ??
              id,
        )
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.onboardStepConfirm, style: Type.display(size: 30)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 20),
          _SummaryCard(
            title: strings.onboardStepName,
            value: profile.name.isEmpty ? strings.onboardNoName : profile.name,
            onEdit: () => onEdit(2),
          ),
          _SummaryCard(
            title: strings.onboardStepDiet,
            value: avoidLabels.isEmpty
                ? strings.genericNone
                : avoidLabels.join(', '),
            onEdit: () => onEdit(3),
          ),
          _SummaryCard(
            title: strings.onboardStepAllergies,
            value: ingredientLabels.isEmpty
                ? strings.genericNone
                : ingredientLabels.join(', '),
            onEdit: () => onEdit(4),
          ),
          _SummaryCard(
            title: strings.onboardStepTargets,
            value: '${profile.calorieTarget} kcal · '
                '${profile.maxTimeMinutes} min · '
                '${strings.effortLabel(profile.preferredEffort)}',
            onEdit: () => onEdit(5),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.onEdit,
  });

  final String title;
  final String value;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MC.card,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: MC.ruleFaint),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title.toUpperCase(), style: Type.label(size: 9)),
                const SizedBox(height: 5),
                Text(value, style: Type.body(size: 14.5, color: MC.ink)),
              ],
            ),
          ),
          TextAction(label: 'edit', onPressed: onEdit),
        ],
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: Type.body(size: 15, color: MC.ink)),
              const Spacer(),
              Text(
                '${value.round()} $suffix',
                style: Type.mono(size: 13, color: MC.inkSoft),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MC.coral,
              inactiveTrackColor: MC.ruleFaint,
              thumbColor: MC.coral,
              overlayColor: MC.coral.withValues(alpha: 0.12),
              trackHeight: 2,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? MC.coral : MC.card,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: selected ? MC.coral : MC.ruleFaint),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected) ...<Widget>[
              const Icon(Icons.check_rounded, size: 13, color: MC.card),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Type.label(
                size: 10,
                weight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? MC.card : MC.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.page,
    required this.strings,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
  });

  final int page;
  final Strings strings;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isLast = page == 6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 20),
      child: Row(
        children: <Widget>[
          if (page > 0)
            GhostButton(
              label: strings.onboardBack,
              onPressed: onBack,
            )
          else
            GhostButton(
              label: strings.onboardSkip,
              onPressed: onSkip,
            ),
          const Spacer(),
          PaperButton(
            label: isLast ? strings.onboardFinish : strings.onboardNext,
            icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}
