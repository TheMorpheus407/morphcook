import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/profile.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../navigation.dart';
import '../../state/app_state.dart';
import '../../widgets/controls.dart';
import '../../widgets/ingredient_typeahead.dart';
import '../../widgets/paper.dart';
import '../backup/backup_screen.dart';
import '../insights/insights_screen.dart';

/// Settings: the full profile editor (name, language, avoidance, budgets,
/// effort), adaptation & accessibility preferences, and the links to backup,
/// insights, help and about. Every change writes through to the profile
/// immediately — there is no "save" button, the paper is always current.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _nameInitialized = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final profile = appState.profile;
    final ontology = appState.corpus.ontology;

    if (!_nameInitialized) {
      _nameController.text = profile.name;
      _nameInitialized = true;
    }

    // Class-level avoid chips: compound shortcuts first, then single classes.
    final avoidClassFlags = <String>[
      ...ontology.compoundAvoidFlags.keys,
      ...ontology.containsFlags,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          children: [
            Expanded(child: Text(s.setTitle, style: Typography.display(30))),
            if (profile.name.isNotEmpty)
              Text(s.greeting(profile.name), style: Typography.hand(22, color: Palette.inkFaint)),
          ],
        ),
        const DashedRule(),

        // ── profile ────────────────────────────────────────────────────────
        SectionLabel(s.setProfile),
        TextField(
          controller: _nameController,
          style: Typography.hand(24),
          decoration: InputDecoration(
            hintText: s.onbNameHint,
            hintStyle: Typography.hand(24, color: Palette.inkFaint),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.line, width: 1.4)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.4)),
          ),
          onChanged: (v) => appState.updateProfile(profile.copyWith(name: v)),
        ),
        const SizedBox(height: 16),
        Text(s.setLanguage, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _langButton(appState, s, profile, 'en', 'english')),
            const SizedBox(width: 10),
            Expanded(child: _langButton(appState, s, profile, 'de', 'deutsch')),
          ],
        ),
        const DashedRule(),

        // ── adaptation preferences ─────────────────────────────────────────
        SectionLabel(s.setAdaptation),
        Text(s.setAvoidClasses, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final flag in avoidClassFlags)
              PaperChip(
                label: s.flagLabel(flag),
                selected: profile.avoidFlags.contains(flag),
                onTap: () => appState.updateProfile(profile.copyWith(
                  avoidFlags: _toggle(profile.avoidFlags, flag),
                )),
              ),
          ],
        ),
        if (profile.avoidFlags.contains('halal') || profile.avoidFlags.contains('kosher') ||
            profile.requiredAttributes.contains('halal') || profile.requiredAttributes.contains('kosher'))
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(s.setHalalNote, style: Typography.mono(9.5, color: Palette.inkFaint, letterSpacing: 0.4)),
          ),
        const SizedBox(height: 20),
        Text(s.setAvoidSpecific, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
        const SizedBox(height: 8),
        IngredientTypeahead(
          lang: profile.lang,
          selected: profile.avoidIngredients,
          hint: s.onbAvoidIngredientHint,
          onChanged: (v) => appState.updateProfile(profile.copyWith(avoidIngredients: v)),
        ),
        const SizedBox(height: 20),
        Text(s.setRequired, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final flag in ontology.compoundAvoidFlags.keys)
              PaperChip(
                label: s.flagLabel(flag),
                selected: profile.requiredAttributes.contains(flag),
                onTap: () => appState.updateProfile(profile.copyWith(
                  requiredAttributes: _toggle(profile.requiredAttributes, flag),
                )),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _sliderRow(
          s,
          label: s.setCalorieTarget,
          value: profile.calorieTarget.toDouble(),
          min: 300,
          max: 1200,
          step: 50,
          display: (v) => '${v.round()} ${s.commonKcal}',
          onChanged: (v) => appState.updateProfile(profile.copyWith(calorieTarget: v.round())),
        ),
        const SizedBox(height: 12),
        _sliderRow(
          s,
          label: s.setMaxTime,
          value: profile.maxTimeMinutes.toDouble(),
          min: 15,
          max: 120,
          step: 5,
          display: (v) => '${v.round()} ${s.commonMin}',
          onChanged: (v) => appState.updateProfile(profile.copyWith(maxTimeMinutes: v.round())),
        ),
        const SizedBox(height: 16),
        Text(s.setEffort, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final e in ontology.effortLevels)
              PaperChip(
                label: s.effortLabel(e),
                selected: profile.preferredEffort == e,
                onTap: () => appState.updateProfile(profile.copyWith(preferredEffort: e)),
              ),
          ],
        ),
        const DashedRule(),

        // ── interface & accessibility ──────────────────────────────────────
        SectionLabel(s.setInterface),
        _toggleRow(s, label: s.setShowVariantTags, value: profile.showVariantTags,
            onChanged: (v) => appState.updateProfile(profile.copyWith(showVariantTags: v))),
        const SizedBox(height: 14),
        Text(s.setReduceMotion, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (label, value) in [
              (s.setReduceMotionSystem, null),
              ('on', true),
              ('off', false),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PaperChip(
                  label: label,
                  selected: profile.reduceMotion == value,
                  onTap: () => appState.updateProfile(value == null
                      ? profile.copyWith(clearReduceMotion: true)
                      : profile.copyWith(reduceMotion: value)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _toggleRow(s, label: s.setVisualAlert, value: profile.visualAlertEnabled,
            onChanged: (v) => appState.updateProfile(profile.copyWith(visualAlertEnabled: v))),
        const SizedBox(height: 4),
        _toggleRow(s, label: s.setQuickTap, value: profile.quickNextTapEnabled,
            onChanged: (v) => appState.updateProfile(profile.copyWith(quickNextTapEnabled: v))),
        const DashedRule(),

        // ── links ──────────────────────────────────────────────────────────
        _linkRow(s.setBackup, Icons.save_alt_outlined, () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen()));
        }),
        _linkRow(s.setInsights, Icons.insights_outlined, () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const InsightsScreen()));
        }),
        _linkRow(s.setHelp, Icons.help_outline, () => openFaq(context)),
        _linkRow(s.setAbout, Icons.info_outline, () => _showAbout(context, s)),
        const SizedBox(height: 24),
        Center(child: MonoLabel(s.datelineNo, size: 9.5)),
      ],
    );
  }

  static Set<String> _toggle(Set<String> set, String value) {
    final next = {...set};
    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }
    return next;
  }

  Widget _langButton(AppState appState, Strings s, UserProfile profile, String code, String label) {
    final selected = profile.lang == code;
    return GestureDetector(
      onTap: () => appState.setLang(code),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? Palette.ink : Palette.paper,
          border: Border.all(color: selected ? Palette.ink : Palette.line, width: 1.4),
        ),
        child: Center(child: Text(label, style: Typography.hand(22, color: selected ? Palette.paper : Palette.ink))),
      ),
    );
  }

  Widget _sliderRow(
    Strings s, {
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required String Function(double) display,
    required ValueChanged<double> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: Typography.mono(10, weight: FontWeight.w700, letterSpacing: 2, color: Palette.inkFaint)),
              Text(display(value), style: Typography.mono(12, weight: FontWeight.w700, color: Palette.teal)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: Palette.teal,
              inactiveTrackColor: Palette.line,
              thumbColor: Palette.ink,
              overlayColor: Palette.teal.withValues(alpha: 0.15),
              trackHeight: 2,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: ((max - min) / step).round(),
              onChanged: onChanged,
            ),
          ),
        ],
      );

  Widget _toggleRow(Strings s, {required String label, required bool value, required ValueChanged<bool> onChanged}) =>
      Row(
        children: [
          Expanded(child: Text(label, style: Typography.body(15, italic: true, color: Palette.ink))),
          Switch(value: value, onChanged: onChanged),
        ],
      );

  Widget _linkRow(String label, IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Palette.line, width: 0.7)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Palette.inkSoft),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: Typography.body(16, italic: true, color: Palette.ink))),
              Icon(Icons.chevron_right, size: 16, color: Palette.inkFaint),
            ],
          ),
        ),
      );

  void _showAbout(BuildContext context, Strings s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.appName, style: Typography.display(24)),
        content: Text(
          '${s.tagline}\n\nmorphcook v1.0.0 — offline, no accounts, no telemetry. '
          'the recipe corpus ships with the app; backups are files you own.',
          style: Typography.body(14, italic: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.commonClose)),
        ],
      ),
    );
  }
}
