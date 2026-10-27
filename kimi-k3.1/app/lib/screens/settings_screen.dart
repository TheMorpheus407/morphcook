import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';
import '../widgets/profile_fields.dart';
import 'backup_screen.dart';
import 'faq_screen.dart';
import 'shopping_insights_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final profile = app.profile;
    final systemReduced = MediaQuery.of(context).disableAnimations;
    final reduced = profile.reduceMotion ?? systemReduced;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('settings_title'))),
      body: Paper(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                color: AppColors.teal.withValues(alpha: 0.08),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined, color: AppColors.teal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.t('offline_note'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              settingsLink(
                context,
                icon: Icons.person_outline,
                title: context.l10n.t('profile'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditorScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                context.l10n.t('language'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'en',
                      label: Text(context.l10n.t('english')),
                    ),
                    ButtonSegment(
                      value: 'de',
                      label: Text(context.l10n.t('german')),
                    ),
                  ],
                  selected: {profile.lang},
                  onSelectionChanged: (selection) => app.updateProfile(
                    profile.copyWith(lang: selection.first),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SectionHeading(context.l10n.t('adaptation_preferences')),
              SwitchListTile(
                value: profile.showVariantTags,
                onChanged: (value) =>
                    app.updateProfile(profile.copyWith(showVariantTags: value)),
                title: Text(context.l10n.t('show_variant_tags')),
                contentPadding: EdgeInsets.zero,
              ),
              const DashedRule(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: profile.reduceMotion == null
                      ? 'system'
                      : (profile.reduceMotion! ? 'on' : 'off'),
                  decoration: InputDecoration(
                    labelText: context.l10n.t('reduce_motion'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'system',
                      child: Text(context.l10n.t('motion_system')),
                    ),
                    DropdownMenuItem(
                      value: 'on',
                      child: Text(context.l10n.t('motion_on')),
                    ),
                    DropdownMenuItem(
                      value: 'off',
                      child: Text(context.l10n.t('motion_off')),
                    ),
                  ],
                  onChanged: (value) {
                    final reduced = value == 'system' ? null : value == 'on';
                    app.updateProfile(profile.copyWith(reduceMotion: reduced));
                  },
                ),
              ),
              SwitchListTile(
                value: profile.visualAlertEnabled,
                onChanged: (value) => app.updateProfile(
                  profile.copyWith(visualAlertEnabled: value),
                ),
                title: Text(context.l10n.t('visual_alerts')),
                subtitle: Text(context.l10n.t('visual_alerts_body')),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                value: profile.quickNextTapEnabled,
                onChanged: (value) => app.updateProfile(
                  profile.copyWith(quickNextTapEnabled: value),
                ),
                title: Text(context.l10n.t('quick_next')),
                subtitle: Text(
                  '${context.l10n.t('quick_next_body')}${reduced && profile.quickNextTapEnabled ? '\n${context.l10n.t('motion_on')}.' : ''}',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              settingsLink(
                context,
                icon: Icons.insights_outlined,
                title: context.l10n.t('shopping_insights'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShoppingInsightsScreen(),
                  ),
                ),
              ),
              settingsLink(
                context,
                icon: Icons.ios_share_outlined,
                title: context.l10n.t('backup_restore'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
              ),
              settingsLink(
                context,
                icon: Icons.help_outline,
                title: context.l10n.t('help_center'),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
              ),
              const SizedBox(height: 25),
              Center(
                child: Text(
                  'MorphCook 1.0.0 · offline edition',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget settingsLink(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) => ListTile(
    onTap: onTap,
    leading: Icon(icon, color: AppColors.teal),
    title: Text(title, style: Theme.of(context).textTheme.titleMedium),
    trailing: const Icon(Icons.arrow_forward_ios, size: 15),
    contentPadding: EdgeInsets.zero,
    shape: Border(
      bottom: BorderSide(color: AppColors.muted.withValues(alpha: 0.18)),
    ),
  );
}

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late Profile draft;
  late final TextEditingController nameController;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    draft = context.read<AppState>().profile;
    nameController = TextEditingController(text: draft.name);
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.t('profile')),
      actions: [
        IconButton(
          onPressed: saving ? null : save,
          icon: const Icon(Icons.check),
          tooltip: context.l10n.t('save'),
        ),
      ],
    ),
    body: Paper(
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 30),
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.l10n.t('name_hint'),
              ),
              onChanged: (value) => draft = draft.copyWith(name: value.trim()),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: draft.lang,
              decoration: InputDecoration(
                labelText: context.l10n.t('language'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'en',
                  child: Text(context.l10n.t('english')),
                ),
                DropdownMenuItem(
                  value: 'de',
                  child: Text(context.l10n.t('german')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => draft = draft.copyWith(lang: value)),
            ),
            const SizedBox(height: 25),
            PreferenceFields(
              profile: draft,
              onChanged: (profile) => setState(() => draft = profile),
            ),
            const SizedBox(height: 27),
            const DashedRule(),
            DietFields(
              profile: draft,
              onChanged: (profile) => setState(() => draft = profile),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: saving
                    ? context.l10n.t('loading')
                    : context.l10n.t('save'),
                icon: Icons.check,
                onPressed: saving ? null : save,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> save() async {
    setState(() => saving = true);
    await context.read<AppState>().updateProfile(
      draft.copyWith(name: nameController.text.trim()),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
