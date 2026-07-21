import 'package:flutter/material.dart';

import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.profile,
    required this.quickNextTapEnabled,
    required this.onUpdateProfile,
    required this.onQuickNextChanged,
    required this.onEditProfile,
    required this.onOpenFaq,
    required this.onOpenInsights,
    required this.onOpenHistory,
    required this.onExportBackup,
    required this.onImportBackup,
    super.key,
    this.onOpenMatchingFaq,
  });

  final UserProfile profile;
  final bool quickNextTapEnabled;
  final Future<void> Function(UserProfile profile) onUpdateProfile;
  final Future<void> Function(bool enabled) onQuickNextChanged;
  final VoidCallback onEditProfile;
  final VoidCallback onOpenFaq;
  final VoidCallback? onOpenMatchingFaq;
  final VoidCallback onOpenInsights;
  final VoidCallback onOpenHistory;
  final Future<void> Function(String? password) onExportBackup;
  final Future<void> Function() onImportBackup;

  @override
  Widget build(BuildContext context) {
    return PaperSurface(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
          children: [
            Text(
              context.strings('settings.title'),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            Text(
              context.strings('settings.offline'),
              style: morphHandwriting(context, size: 20),
            ),
            SectionHeading(
              title: context.strings('settings.profile'),
              kicker: profile.name,
            ),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              title: context.strings('settings.profile'),
              subtitle: context.strings.format('settings.profileSummary', {
                'calories': profile.calorieTarget,
                'minutes': profile.maxTimeMinutes,
                'effort': context.strings('effort.${profile.preferredEffort}'),
              }),
              onTap: onEditProfile,
            ),
            _SettingsTile(
              icon: Icons.language_rounded,
              title: context.strings('settings.language'),
              subtitle: context.strings.option(
                'language',
                profile.languageCode,
              ),
              trailing: SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'en',
                    label: Text(
                      context.strings('onboarding.language.englishShort'),
                    ),
                  ),
                  ButtonSegment(
                    value: 'de',
                    label: Text(
                      context.strings('onboarding.language.germanShort'),
                    ),
                  ),
                ],
                selected: {profile.languageCode},
                showSelectedIcon: false,
                onSelectionChanged: (selected) => onUpdateProfile(
                  profile.copyWith(languageCode: selected.first),
                ),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.label_outline_rounded),
              title: Text(context.strings('settings.variantTags')),
              value: profile.showVariantTags,
              onChanged: (value) =>
                  onUpdateProfile(profile.copyWith(showVariantTags: value)),
            ),
            SectionHeading(title: context.strings('settings.appearance')),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.motion_photos_off_outlined),
              title: Text(context.strings('settings.reduceMotion')),
              subtitle: profile.reduceMotion == null
                  ? Text(context.strings('settings.followPhone'))
                  : null,
              value:
                  profile.reduceMotion ??
                  MediaQuery.disableAnimationsOf(context),
              onChanged: (value) =>
                  onUpdateProfile(profile.copyWith(reduceMotion: value)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.flash_on_outlined),
              title: Text(context.strings('settings.visualAlerts')),
              value: profile.visualAlertEnabled,
              onChanged: (value) =>
                  onUpdateProfile(profile.copyWith(visualAlertEnabled: value)),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.touch_app_outlined),
              title: Text(context.strings('settings.quickTap')),
              subtitle: Text(context.strings('settings.quickTapBody')),
              value: quickNextTapEnabled,
              onChanged: onQuickNextChanged,
            ),
            SectionHeading(
              title: context.strings('settings.backup'),
              kicker: context.strings('settings.backupKicker'),
            ),
            _SettingsTile(
              icon: Icons.ios_share_rounded,
              title: context.strings('settings.export'),
              subtitle: context.strings('settings.exportFormat'),
              onTap: () => _export(context),
            ),
            _SettingsTile(
              icon: Icons.settings_backup_restore_rounded,
              title: context.strings('settings.import'),
              subtitle: context.strings('settings.importFormat'),
              onTap: onImportBackup,
            ),
            SectionHeading(title: context.strings('settings.libraryHelp')),
            _SettingsTile(
              icon: Icons.insights_outlined,
              title: context.strings('settings.insights'),
              subtitle: context.strings('settings.insightsBody'),
              onTap: onOpenInsights,
            ),
            _SettingsTile(
              icon: Icons.history_rounded,
              title: context.strings('settings.history'),
              onTap: onOpenHistory,
            ),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              title: context.strings('settings.faq'),
              subtitle: context.strings('faq.hint'),
              onTap: onOpenFaq,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label:
                  '${context.strings('settings.compatibleNote')} ${context.strings('settings.compatibleLearnMore')}',
              onTap: onOpenMatchingFaq ?? onOpenFaq,
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: onOpenMatchingFaq ?? onOpenFaq,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.morph.paperDeep.withValues(alpha: .5),
                      border: Border.all(
                        color: context.morph.ink.withValues(alpha: .3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: context.morph.teal),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.strings('settings.compatibleNote'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                context.strings('settings.compatibleLearnMore'),
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: context.morph.teal),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                context.strings('settings.versionFooter'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final password = await showDialog<String?>(
      context: context,
      builder: (context) => const _BackupPasswordDialog(),
    );
    if (password == _cancelSentinel) return;
    await onExportBackup(password?.trim().isEmpty == true ? null : password);
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 58,
      leading: Icon(icon, color: context.morph.teal),
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

const _cancelSentinel = '__cancel__';

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog();

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _password = TextEditingController();
  var _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.strings('settings.export')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.strings('settings.exportExplanation')),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: context.strings('settings.password'),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: context.strings(
                  _obscure ? 'settings.showPassword' : 'settings.hidePassword',
                ),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _cancelSentinel),
          child: Text(context.strings('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _password.text),
          child: Text(context.strings('common.continue')),
        ),
      ],
    );
  }
}
