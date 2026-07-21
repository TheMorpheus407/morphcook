import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import 'backup_screen.dart';
import 'faq_screen.dart';
import 'history_screen.dart';
import 'profile_editor_screen.dart';
import 'shopping_insights_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final profile = app.profile;
    return Scaffold(
      appBar: AppBar(title: Text(Copy.text('settings', lang))),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(13, 6, 13, 34),
          children: [
            _SectionLabel(Copy.text('profile', lang)),
            _SettingsTile(
              icon: Icons.person_outline,
              title: profile.name,
              subtitle:
                  '${profile.calorieTarget} kcal · ${profile.maxTimeMinutes} min · ${Copy.text(profile.preferredEffort, lang)}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileEditorScreen(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.language,
              title: Copy.text('language', lang),
              trailing: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'en', label: Text('EN')),
                  ButtonSegment(value: 'de', label: Text('DE')),
                ],
                selected: {lang},
                onSelectionChanged: (value) =>
                    app.updateProfile(profile.copyWith(language: value.first)),
              ),
            ),
            _SectionLabel(Copy.text('preferences', lang)),
            SwitchListTile(
              secondary: const Icon(Icons.sell_outlined),
              value: profile.showVariantTags,
              activeThumbColor: BrandColors.coral,
              title: Text(Copy.text('show_tags', lang)),
              onChanged: (value) =>
                  app.updateProfile(profile.copyWith(showVariantTags: value)),
            ),
            ListTile(
              leading: const Icon(Icons.motion_photos_off_outlined),
              title: Text(Copy.text('reduce_motion', lang)),
              trailing: DropdownButton<bool?>(
                value: profile.reduceMotion,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(Copy.text('follow_system', lang)),
                  ),
                  DropdownMenuItem(
                    value: true,
                    child: Text(lang == 'de' ? 'an' : 'on'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text(lang == 'de' ? 'aus' : 'off'),
                  ),
                ],
                onChanged: (value) => app.updateProfile(
                  value == null
                      ? profile.copyWith(clearReduceMotion: true)
                      : profile.copyWith(reduceMotion: value),
                ),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              value: profile.visualAlertEnabled,
              activeThumbColor: BrandColors.coral,
              title: Text(Copy.text('visual_alert', lang)),
              onChanged: (value) => app.updateProfile(
                profile.copyWith(visualAlertEnabled: value),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.touch_app_outlined),
              value: profile.quickNextTapEnabled,
              activeThumbColor: BrandColors.coral,
              title: Text(Copy.text('quick_tap', lang)),
              onChanged: (value) => app.updateProfile(
                profile.copyWith(quickNextTapEnabled: value),
              ),
            ),
            _SectionLabel(lang == 'de' ? 'DEIN BUCH' : 'YOUR BOOK'),
            _SettingsTile(
              icon: Icons.insights_outlined,
              title: Copy.text('insights', lang),
              subtitle: lang == 'de'
                  ? '${app.varietyScore} einzigartige Zutaten'
                  : '${app.varietyScore} unique ingredients',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ShoppingInsightsScreen(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.history,
              title: Copy.text('history', lang),
              subtitle: '${app.history.length}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.help_outline,
              title: Copy.text('help', lang),
              subtitle: lang == 'de'
                  ? 'ernährung · funktionen · fehlerhilfe'
                  : 'dietary · features · troubleshooting',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const FaqScreen()),
              ),
            ),
            _SettingsTile(
              icon: Icons.ios_share_outlined,
              title: Copy.text('backup', lang),
              subtitle: lang == 'de'
                  ? 'JSON · GZip · optionale AES-256-Verschlüsselung'
                  : 'JSON · GZip · optional AES-256 encryption',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
              ),
            ),
            const SizedBox(height: 28),
            const Center(
              child: Text(
                'MorphCook · v1.0.0 · offline always',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 9,
                  color: BrandColors.fadedInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 24, 12, 7),
    child: Row(
      children: [
        Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 10),
        const Expanded(child: DashedRule()),
      ],
    ),
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing:
        trailing ??
        (onTap == null ? null : const Icon(Icons.arrow_forward_ios, size: 15)),
    onTap: onTap,
  );
}
