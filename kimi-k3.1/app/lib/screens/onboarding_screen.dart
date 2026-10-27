import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';
import '../widgets/profile_fields.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController nameController = TextEditingController();
  late Profile draft;
  int step = 0;
  bool showNameError = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    draft = context.read<AppState>().profile;
    nameController.text = draft.name;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      'language_title',
      'name_title',
      'diet_title',
      'calorie_title',
      'confirm_title',
    ];
    final bodies = [
      'language_body',
      'name_body',
      'diet_body',
      'calorie_body',
      'confirm_body',
    ];
    return Scaffold(
      body: Paper(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'morphcook.',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ),
                    Text(
                      context.l10n.t('step_count', {
                        'current': '${step + 1}',
                        'total': '5',
                      }),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: (step + 1) / 5,
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: motionDuration(
                    context,
                    const Duration(milliseconds: 280),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(step),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.t('onboarding_kicker'),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.coral),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.t(titles[step]),
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.t(bodies[step]),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 27),
                          _page(step),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const DashedRule(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (step > 0)
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: saving ? null : previous,
                            icon: const Icon(Icons.arrow_back, size: 17),
                            label: Text(context.l10n.t('back')),
                          ),
                          const Spacer(),
                          if (step == 1)
                            TextButton(
                              onPressed: () {
                                nameController.clear();
                                draft = draft.copyWith(name: '');
                                next();
                              },
                              child: Text(context.l10n.t('skip')),
                            ),
                        ],
                      ),
                    if (step > 0) const SizedBox(height: 8),
                    if (step == 0)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.t('tagline'),
                              maxLines: 2,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          ),
                          PrimaryButton(
                            label: context.l10n.t('next'),
                            onPressed: saving ? null : next,
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: step == 4
                              ? context.l10n.t('start_cookbook')
                              : context.l10n.t('next'),
                          onPressed: saving ? null : next,
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
  }

  Widget _page(int index) {
    switch (index) {
      case 0:
        return Column(
          children: [
            _LanguageCard(
              title: 'English',
              subtitle: 'a little kitchen poetry',
              selected: draft.lang == 'en',
              onTap: () => selectLanguage('en'),
            ),
            const SizedBox(height: 12),
            _LanguageCard(
              title: 'Deutsch',
              subtitle: 'ein bisschen Küchenpoesie',
              selected: draft.lang == 'de',
              onTap: () => selectLanguage('de'),
            ),
          ],
        );
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: false,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: InputDecoration(
                hintText: context.l10n.t('name_hint'),
                errorText: showNameError ? context.l10n.t('name_error') : null,
                counterText: '',
              ),
              onChanged: (value) {
                draft = draft.copyWith(name: value.trim());
                if (showNameError && value.trim().isNotEmpty) {
                  setState(() => showNameError = false);
                }
              },
              onSubmitted: (_) => next(),
            ),
            const SizedBox(height: 26),
            Text(
              '“Tell me what you eat, and I’ll make more room.”',
              style: Theme.of(context).textTheme.headlineSmall?.handwritten
                  .copyWith(color: AppColors.coral),
            ),
          ],
        );
      case 2:
        return DietFields(
          profile: draft,
          onChanged: (profile) => setState(() => draft = profile),
        );
      case 3:
        return PreferenceFields(
          profile: draft,
          onChanged: (profile) => setState(() => draft = profile),
        );
      default:
        final selected = context
            .read<AppState>()
            .repository
            .ontology
            .avoidFlags
            .values
            .where((flag) => draft.avoidFlags.contains(flag.id))
            .map((flag) => flag.name[context.lang])
            .toList();
        return Polaroid(
          turns: 0.003,
          padding: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.t('profile_summary'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 14),
              _SummaryLine(
                icon: Icons.person_outline,
                text: draft.name.isEmpty ? 'cook' : draft.name,
              ),
              _SummaryLine(
                icon: Icons.schedule_outlined,
                text: '${draft.maxTimeMinutes} min · ${draft.preferredEffort}',
              ),
              _SummaryLine(
                icon: Icons.local_fire_department_outlined,
                text: '${draft.calorieTarget} ± ${draft.calorieTolerance} kcal',
              ),
              if (selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selected
                        .map((name) => TagPill(name, active: true))
                        .toList(),
                  ),
                ),
              if (draft.avoidIngredients.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(draft.avoidIngredients.join(' · ')),
                ),
            ],
          ),
        );
    }
  }

  void selectLanguage(String language) {
    setState(() => draft = draft.copyWith(lang: language));
    context.read<AppState>().updateProfile(
      context.read<AppState>().profile.copyWith(lang: language),
    );
  }

  void previous() {
    if (step > 0) setState(() => step--);
  }

  Future<void> next() async {
    if (step == 1 && nameController.text.trim().isEmpty) {
      setState(() => showNameError = true);
      return;
    }
    if (step < 4) {
      FocusScope.of(context).unfocus();
      setState(() => step++);
      return;
    }
    setState(() => saving = true);
    await context.read<AppState>().updateProfile(
      draft.copyWith(
        name: nameController.text.trim(),
        onboardingComplete: true,
      ),
    );
    if (mounted) setState(() => saving = false);
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: AnimatedContainer(
      duration: motionDuration(context, const Duration(milliseconds: 220)),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.teal.withValues(alpha: 0.12)
            : AppColors.paperLight,
        border: Border.all(
          color: selected
              ? AppColors.teal
              : AppColors.muted.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            color: AppColors.teal,
          ),
        ],
      ),
    ),
  );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, size: 20, color: AppColors.teal),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
