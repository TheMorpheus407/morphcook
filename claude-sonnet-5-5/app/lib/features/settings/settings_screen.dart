import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/routes.dart';
import '../../core/app_info.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/models/profile.dart';
import '../../state/controllers/content_request_log.dart';
import '../../state/controllers/cook_session_controller.dart';
import '../../state/controllers/cookbook_controller.dart';
import '../../state/controllers/history_controller.dart';
import '../../state/controllers/meal_plan_controller.dart';
import '../../state/controllers/one_handed_cook_mode_controller.dart';
import '../../state/controllers/profile_controller.dart';
import '../../state/controllers/shopping_controller.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../profile/profile_editors.dart';

/// Settings: the full profile editor, language, adaptation preferences, cook
/// mode options, backup, insights and help.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  void _update(Profile profile) => context.read<ProfileController>().setProfile(profile);

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final controller = context.watch<ProfileController>();
    final profile = controller.profile;
    final settings = controller.settings;
    final oneHanded = context.watch<OneHandedCookModeController>();
    final requests = context.watch<ContentRequestLog>();

    return PaperScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 48),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(-12, 0),
                        child: PaperIconButton(
                          icon: Icons.arrow_back,
                          tooltip: s('common.back'),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                  TabHeader(title: s('settings.title'), note: s('settings.note')),
                  const SizedBox(height: 14),
                  FormSection(
                    title: s('settings.you'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MonoLabel(s('profile.summary.name')),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          style: AppText.serifItalic(size: 20),
                          decoration: InputDecoration(hintText: s('onboarding.name.hint')),
                          onChanged: (v) => _update(profile.copyWith(name: v.trim())),
                        ),
                        const SizedBox(height: 16),
                        MonoLabel(s('settings.language')),
                        const SizedBox(height: 6),
                        LanguageEditor(profile: profile, onChanged: _update),
                      ],
                    ),
                  ),
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
                    child: CalorieEditor(profile: profile, onChanged: _update, showTolerance: true),
                  ),
                  FormSection(
                    title: s('settings.adaptation.title'),
                    note: s('settings.adaptation.note'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SwitchRow(
                          title: s('settings.showTags'),
                          body: s('settings.showTags.body'),
                          value: profile.showVariantTags,
                          onChanged: (v) => _update(profile.copyWith(showVariantTags: v)),
                        ),
                        const SizedBox(height: 10),
                        MonoLabel(s('settings.reduceMotion')),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            PaperChip(
                              label: s('settings.motion.system'),
                              style: PaperChipStyle.mono,
                              selected: profile.reduceMotion == null,
                              onTap: () => _update(profile.copyWith(reduceMotion: null)),
                            ),
                            PaperChip(
                              label: s('settings.motion.reduce'),
                              style: PaperChipStyle.mono,
                              selected: profile.reduceMotion == true,
                              onTap: () => _update(profile.copyWith(reduceMotion: true)),
                            ),
                            PaperChip(
                              label: s('settings.motion.full'),
                              style: PaperChipStyle.mono,
                              selected: profile.reduceMotion == false,
                              onTap: () => _update(profile.copyWith(reduceMotion: false)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FormSection(
                    title: s('settings.cook.title'),
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: s('settings.visualAlert'),
                          body: s('settings.visualAlert.body'),
                          value: settings.visualAlertEnabled,
                          onChanged: (v) => controller.updateSettings((x) => x.copyWith(visualAlertEnabled: v)),
                        ),
                        const SizedBox(height: 8),
                        _SwitchRow(
                          title: s('settings.timerSound'),
                          body: s('settings.timerSound.body'),
                          value: settings.timerSoundEnabled,
                          onChanged: (v) => controller.updateSettings((x) => x.copyWith(timerSoundEnabled: v)),
                        ),
                        const SizedBox(height: 8),
                        _SwitchRow(
                          title: s('settings.quickTap'),
                          body: s('settings.quickTap.body'),
                          value: oneHanded.quickNextTapEnabled,
                          onChanged: (v) => oneHanded.quickNextTapEnabled = v,
                        ),
                      ],
                    ),
                  ),
                  FormSection(
                    title: s('settings.data.title'),
                    note: s('settings.data.note'),
                    child: Column(
                      children: [
                        _LinkRow(
                          icon: Icons.insights_outlined,
                          title: s('insights.title'),
                          body: s('settings.insights.body'),
                          onTap: () => openInsights(context),
                        ),
                        _LinkRow(
                          icon: Icons.save_alt,
                          title: s('backup.title'),
                          body: s('settings.backup.body'),
                          onTap: () => openBackup(context),
                        ),
                        if (requests.count > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              s.plural('settings.wishes', requests.count),
                              style: AppText.hand(size: 20, color: Palette.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                  FormSection(
                    title: s('settings.help.title'),
                    child: Column(
                      children: [
                        _LinkRow(
                          icon: Icons.help_outline,
                          title: s('faq.title'),
                          body: s('settings.help.body'),
                          onTap: () => openFaq(context),
                        ),
                      ],
                    ),
                  ),
                  FormSection(
                    title: s('settings.about.title'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('settings.about.body'), style: AppText.serif(size: 15.5, height: 1.55)),
                        const SizedBox(height: 8),
                        Text('${s('settings.about.version')} $kAppVersion', style: AppText.mono(size: 12)),
                        const SizedBox(height: 6),
                        PaperButton(
                          label: s('settings.licenses'),
                          style: PaperButtonStyle.quiet,
                          dense: true,
                          onPressed: () => showLicensePage(
                            context: context,
                            applicationName: kAppName,
                            applicationVersion: kAppVersion,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FormSection(
                    title: s('settings.danger.title'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('settings.danger.body'), style: AppText.serif(size: 15, color: Palette.inkSoft)),
                        const SizedBox(height: 8),
                        PaperButton(
                          label: s('settings.danger.action'),
                          icon: Icons.delete_outline,
                          style: PaperButtonStyle.outline,
                          color: Palette.coralDeep,
                          onPressed: () => _confirmDelete(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final s = context.sRead;
    final profile = context.read<ProfileController>();
    final cookbook = context.read<CookbookController>();
    final history = context.read<HistoryController>();
    final plan = context.read<MealPlanController>();
    final shopping = context.read<ShoppingController>();
    final requests = context.read<ContentRequestLog>();
    final cook = context.read<CookSessionController>();
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(s('settings.danger.title')),
        content: Text(s('settings.danger.confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('common.cancel'))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s('settings.danger.action'))),
        ],
      ),
    );
    if (ok != true) return;
    await cookbook.clear();
    await history.clear();
    await plan.clearAll();
    await shopping.clearAll();
    await requests.clear();
    await cook.abandon();
    await profile.resetAll();
    navigator.popUntil((route) => route.isFirst);
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.body, required this.value, required this.onChanged});

  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.serif(size: 16.5, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(body, style: AppText.serif(size: 14, color: Palette.inkSoft, height: 1.4)),
                ],
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.title, required this.body, required this.onTap});

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      hint: body,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 22, color: Palette.ink),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.serif(size: 16.5, weight: FontWeight.w700)),
                    Text(body, style: AppText.serif(size: 14, color: Palette.inkSoft, height: 1.35)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Palette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}
