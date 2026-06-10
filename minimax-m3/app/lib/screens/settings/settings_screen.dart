import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../faq/faq_screen.dart';
import '../shopping/insights_screen.dart';
import '../shopping/shopping_list_screen.dart';
import 'backup_screen.dart';
import 'profile_editor_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = I18n.of(context);

    return ListenableBuilder(
      listenable: state.profileRepo,
      builder: (context, child) {
        final profile = state.profileRepo.profile;
        return Scaffold(
          body: PaperBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  Masthead(
                    title: s.settingsTitle,
                    subtitle: 'hello, ${profile.name.isEmpty ? "friend" : profile.name.toLowerCase()}.',
                    align: TextAlign.left,
                    titleSize: 36,
                  ),
                  const SizedBox(height: 18),

                  // Profile
                  _Section(title: s.profile, children: [
                    _Row(
                      label: s.profileEditor,
                      value: profile.name.isEmpty ? '—' : profile.name,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ProfileEditorScreen(),
                      )),
                    ),
                  ]),

                  // Language
                  _Section(title: s.language, children: [
                    _SegmentedRow(
                      value: profile.lang,
                      options: const ['en', 'de'],
                      labels: {
                        'en': s.languageEnglish,
                        'de': s.languageGerman,
                      },
                      onChange: (lang) async {
                        await state.profileRepo
                            .update((p) => p.copyWith(lang: lang));
                        if (context.mounted) {
                          I18n.notifierOf(context).setLang(lang);
                        }
                      },
                    ),
                  ]),

                  // Insights & shopping list
                  _Section(title: s.shoppingList, children: [
                    _Row(
                      label: s.shoppingList,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const ShoppingListScreen(),
                      )),
                    ),
                    _Row(
                      label: s.shoppingInsights,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const InsightsScreen(),
                      )),
                    ),
                  ]),

                  // Accessibility
                  _Section(title: s.accessibility, children: [
                    _SwitchRow(
                      label: s.reduceMotion,
                      caption: profile.reduceMotion == null
                          ? s.followsSystem
                          : (profile.reduceMotion! ? s.on : s.off),
                      value: profile.reduceMotion ?? false,
                      onChange: (v) => state.profileRepo.update(
                        (p) => p.copyWith(reduceMotion: v),
                      ),
                    ),
                    _SwitchRow(
                      label: s.visualAlerts,
                      value: profile.visualAlertEnabled,
                      onChange: (v) => state.profileRepo
                          .update((p) => p.copyWith(visualAlertEnabled: v)),
                    ),
                    _SwitchRow(
                      label: s.quickTapAdvance,
                      value: profile.quickNextTapEnabled,
                      onChange: (v) => state.profileRepo
                          .update((p) => p.copyWith(quickNextTapEnabled: v)),
                    ),
                  ]),

                  // Backup & restore
                  _Section(title: s.backupRestore, children: [
                    _Row(
                      label: s.exportBackup,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const BackupScreen(mode: BackupMode.export),
                      )),
                    ),
                    _Row(
                      label: s.importBackup,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const BackupScreen(mode: BackupMode.import),
                      )),
                    ),
                  ]),

                  // Help
                  _Section(title: s.faqHelp, children: [
                    _Row(
                      label: s.faqHelp,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const FaqScreen(),
                      )),
                    ),
                  ]),

                  const SizedBox(height: 30),
                  Text(s.noteHalalDisclaimer,
                      style: MCTypography.italic(
                          size: 12, color: MCColors.inkFaded)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: MCTypography.eyebrow()),
          const SizedBox(height: 6),
          const DashedRule(),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _Row({required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: MCTypography.body(size: 15))),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(value!, style: MCTypography.italic(size: 14, color: MCColors.inkFaded)),
              ),
            const Icon(Icons.chevron_right, color: MCColors.inkFaded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChange;
  const _SwitchRow({
    required this.label,
    this.caption,
    required this.value,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MCTypography.body(size: 15)),
                if (caption != null)
                  Text(caption!, style: MCTypography.italic(size: 12, color: MCColors.inkFaded)),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChange, activeThumbColor: MCColors.coral),
        ],
      ),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final String value;
  final List<String> options;
  final Map<String, String> labels;
  final ValueChanged<String> onChange;

  const _SegmentedRow({
    required this.value,
    required this.options,
    required this.labels,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: options.map((o) {
          final selected = value == o;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChange(o),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? MCColors.ink : MCColors.polaroid,
                  border: Border.all(
                      color: selected ? MCColors.ink : MCColors.paperDark,
                      width: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Center(
                  child: Text(
                    labels[o] ?? o,
                    style: MCTypography.body(
                      size: 14,
                      color: selected ? MCColors.cream : MCColors.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
