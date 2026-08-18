import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';
import 'backup.dart';
import 'faq.dart';
import 'insights.dart';
import 'profile_editor.dart';

/// Settings: profile editor, language toggle, adaptation preferences,
/// halal/kosher note, backup, insights, help center, about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final loc = context.watch<LocaleController>();
    final profile = store.profile;

    return Scaffold(
      appBar: AppBar(title: Text(context.t('tabSettings'))),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _sectionHeader(context, context.t('stProfile')),
            _card(
              context,
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      profile.name.isEmpty ? '—' : profile.name,
                      style: const TextStyle(
                        fontFamily: 'Caveat',
                        fontSize: 26,
                        color: MC.ink,
                      ),
                    ),
                    subtitle: Text(
                      context.t('stProfileSub'),
                      style: const TextStyle(
                          fontSize: 11, color: MC.inkFaint),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        size: 18, color: MC.inkFaint),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ProfileEditorScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader(context, context.t('stLanguage')),
            _card(
              context,
              child: RadioGroup<String>(
                groupValue: loc.lang,
                onChanged: (v) {
                  if (v != null) {
                    loc.setLang(v);
                    store.setLang(v);
                  }
                },
                child: Column(
                  children: [
                    for (final lang in LocaleController.supported)
                      RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: lang,
                        title: Text(
                          lang == 'en' ? 'english' : 'deutsch',
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 13,
                            color: MC.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader(context, context.t('stAdaptions')),
            _card(
              context,
              child: Column(
                children: [
                  _switchRow(
                    context,
                    title: context.t('stVisualAlert'),
                    sub: context.t('stVisualAlertSub'),
                    value: profile.visualAlertEnabled,
                    onChanged: (v) => store.updateProfile(
                        profile.copyWith(visualAlertEnabled: v)),
                  ),
                  _switchRow(
                    context,
                    title: context.t('stQuickTap'),
                    sub: context.t('stQuickTapSub'),
                    value: profile.quickNextTapEnabled,
                    onChanged: (v) => store.updateProfile(
                        profile.copyWith(quickNextTapEnabled: v)),
                  ),
                  _switchRow(
                    context,
                    title: context.t('stReduceMotion'),
                    sub: null,
                    value: profile.reduceMotion,
                    onChanged: (v) => store.updateProfile(
                        profile.copyWith(reduceMotion: v)),
                  ),
                  _switchRow(
                    context,
                    title: context.t('stVariantTags'),
                    sub: context.t('stVariantTagsSub'),
                    value: profile.showVariantTags,
                    onChanged: (v) => store.updateProfile(
                        profile.copyWith(showVariantTags: v)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader(context, context.t('tag.halal').replaceFirst('halal-compatible', 'halal · kosher')),
            _card(
              context,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('stHalalKosherNote'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const FaqScreen()),
                      ),
                      icon: const Icon(Icons.help_outline, size: 14),
                      label: Text(context.t('stFaq')),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader(context, context.t('stBackup')),
            _card(
              context,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                title: Text(
                  context.t('stBackup'),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
                subtitle: Text(
                  context.t('stBackupSub'),
                  style: const TextStyle(fontSize: 11, color: MC.inkFaint),
                ),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: MC.inkFaint),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BackupScreen()),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader(context, context.t('stInsights')),
            _card(
              context,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                title: Text(
                  context.t('stInsights'),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
                subtitle: Text(
                  context.t('stInsightsSub'),
                  style: const TextStyle(fontSize: 11, color: MC.inkFaint),
                ),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: MC.inkFaint),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InsightsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _sectionHeader(context, context.t('stFaq')),
            _card(
              context,
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14),
                title: Text(
                  context.t('stFaq'),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right,
                    size: 18, color: MC.inkFaint),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FaqScreen()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  const DashedOrnament(),
                  const SizedBox(height: 12),
                  Text(
                    context.t('stAboutText'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10,
                      height: 1.6,
                      color: MC.inkFaint,
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

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 10.5,
          letterSpacing: 1.6,
          color: MC.inkSoft,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }

  Widget _switchRow(
    BuildContext context, {
    required String title,
    String? sub,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: MC.ink,
                  ),
                ),
                if (sub != null)
                  Text(
                    sub,
                    style:
                        const TextStyle(fontSize: 10.5, color: MC.inkFaint),
                  ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
