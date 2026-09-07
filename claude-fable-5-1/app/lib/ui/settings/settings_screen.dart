import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';
import '../navigation.dart';
import 'profile_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final profile = app.profile;
    const headerPad = EdgeInsets.fromLTRB(20, 22, 20, 8);
    return Scaffold(
      appBar: AppBar(title: Text(s('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _NavRow(
            title: s('settings.profile'),
            subtitle: s('settings.profile.note'),
            icon: Icons.person_outline,
            onTap: () => Routes.openProfile(context),
          ),
          SectionHeader(title: s('settings.language'), padding: headerPad),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LanguagePicker(value: profile, onChanged: (p) => app.setLang(p.lang)),
          ),
          SectionHeader(title: s('settings.adaptation'), padding: headerPad),
          PaperSwitchRow(
            title: s('settings.showTags'),
            subtitle: s('settings.showTags.note'),
            value: profile.showVariantTags,
            onChanged: (v) => app.updateProfile(profile.copyWith(showVariantTags: v)),
          ),
          SectionHeader(title: s('settings.accessibility'), padding: headerPad),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('settings.reduceMotion'), style: AppText.body(size: 15)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PaperChip(
                      label: s('settings.reduceMotion.system'),
                      selected: profile.reduceMotion == null,
                      onTap: () => app.updateProfile(profile.copyWith(reduceMotion: null)),
                    ),
                    PaperChip(
                      label: s('settings.reduceMotion.on'),
                      selected: profile.reduceMotion == true,
                      onTap: () => app.updateProfile(profile.copyWith(reduceMotion: true)),
                    ),
                    PaperChip(
                      label: s('settings.reduceMotion.off'),
                      selected: profile.reduceMotion == false,
                      onTap: () => app.updateProfile(profile.copyWith(reduceMotion: false)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PaperSwitchRow(
            title: s('settings.visualAlert'),
            subtitle: s('settings.visualAlert.note'),
            value: profile.visualAlertEnabled,
            onChanged: (v) => app.updateProfile(profile.copyWith(visualAlertEnabled: v)),
          ),
          PaperSwitchRow(
            title: s('settings.quickTap'),
            subtitle: s('settings.quickTap.note'),
            value: profile.quickNextTapEnabled,
            onChanged: (v) => app.updateProfile(profile.copyWith(quickNextTapEnabled: v)),
          ),
          SectionHeader(title: s('settings.data'), padding: headerPad),
          _NavRow(
            title: s('settings.backup'),
            subtitle: s('settings.backup.note'),
            icon: Icons.ios_share,
            onTap: () => Routes.openBackup(context),
          ),
          _NavRow(
            title: s('settings.insights'),
            subtitle: s('insights.kicker'),
            icon: Icons.insights_outlined,
            onTap: () => Routes.openInsights(context),
          ),
          _NavRow(
            title: s('settings.history'),
            subtitle: s('history.kicker'),
            icon: Icons.history,
            onTap: () => Routes.openHistory(context),
          ),
          SectionHeader(title: s('common.help'), padding: headerPad),
          _NavRow(
            title: s('settings.help'),
            subtitle: s('faq.kicker'),
            icon: Icons.help_outline,
            onTap: () => Routes.openFaq(context),
          ),
          SectionHeader(title: s('settings.about'), padding: headerPad),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaperNote(
                  kicker: s('app.name'),
                  text: '${s('settings.about.note', {'version': app.repo.manifest.version})}\n${s('settings.about.privacy')}',
                  tone: Palette.sage,
                ),
                const SizedBox(height: 10),
                MonoLabel(s('app.tagline')),
                const SizedBox(height: 12),
                const DashedRule(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: PaperButton(
                    label: s('settings.resetOnboarding'),
                    kind: PaperButtonKind.quiet,
                    icon: Icons.replay,
                    onPressed: () async {
                      await app.updateProfile(profile.copyWith(onboardingComplete: false));
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, required this.subtitle, required this.icon, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Palette.inkSoft),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(size: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.mono(color: Palette.inkFaint, size: 11.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Palette.inkFaint),
            ],
          ),
        ),
      );
}
