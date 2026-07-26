import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/profile.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../faq/faq_screen.dart';
import '../shopping/insights_screen.dart';
import 'avoidance_editor.dart';
import 'backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(
    text: context.read<AppState>().profile.name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  AppState get _state => context.read<AppState>();

  void _patch(Profile Function(Profile) f) =>
      _state.updateProfile(f(_state.profile));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final profile = state.profile;
    final ontology = state.repository.ontology;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle.toLowerCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
        children: [
          // --- profile ------------------------------------------------------
          SectionHeader(s.settingsProfile),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: s.settingsName),
            onChanged: (v) => _patch((p) => p.copyWith(name: v.trim())),
          ),
          const SizedBox(height: 16),
          Eyebrow(s.settingsLanguage),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final code in S.supported)
                InkChip(
                  label: S.languageNames[code]!,
                  selected: profile.lang == code,
                  onTap: () => _patch((p) => p.copyWith(lang: code)),
                ),
            ],
          ),

          // --- diet ---------------------------------------------------------
          const SizedBox(height: 34),
          SectionHeader(s.settingsDiet),
          const SizedBox(height: 12),
          Text(
            s.settingsClassAvoidanceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Eyebrow(s.settingsClassAvoidance),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final compound in ontology.compoundFlags.values)
                InkChip(
                  label: compound.label(s.lang),
                  dense: true,
                  selected: profile.avoidFlags.contains(compound.id),
                  tooltip: compound.note(s.lang),
                  onTap: () => _patch((p) {
                    final next = Set<String>.from(p.avoidFlags);
                    next.contains(compound.id)
                        ? next.remove(compound.id)
                        : next.add(compound.id);
                    return p.copyWith(avoidFlags: next);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Eyebrow(s.dishContains),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final flag in ontology.containsFlags.values)
                InkChip(
                  label: flag.label(s.lang),
                  dense: true,
                  tone: flag.euAllergen ? colors.accent : colors.secondary,
                  selected: profile.avoidFlags.contains(flag.id),
                  leading: flag.euAllergen
                      ? const Icon(Icons.warning_amber_rounded)
                      : null,
                  onTap: () => _patch((p) {
                    final next = Set<String>.from(p.avoidFlags);
                    next.contains(flag.id)
                        ? next.remove(flag.id)
                        : next.add(flag.id);
                    return p.copyWith(avoidFlags: next);
                  }),
                ),
            ],
          ),

          const SizedBox(height: 22),
          Eyebrow(s.settingsSpecificAvoidance),
          const SizedBox(height: 6),
          Text(
            s.settingsSpecificAvoidanceNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          IngredientAvoidanceEditor(
            lang: s.lang,
            selected: profile.avoidIngredients,
            onChanged: (next) =>
                _patch((p) => p.copyWith(avoidIngredients: next)),
          ),

          const SizedBox(height: 22),
          Eyebrow(s.settingsRequired),
          const SizedBox(height: 6),
          Text(
            s.settingsRequiredNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final descriptor in ontology.descriptors)
                InkChip(
                  label: descriptor.label(s.lang),
                  dense: true,
                  tone: colors.mustard,
                  selected: profile.requiredAttributes.contains(descriptor.id),
                  onTap: () => _patch((p) {
                    final next = Set<String>.from(p.requiredAttributes);
                    next.contains(descriptor.id)
                        ? next.remove(descriptor.id)
                        : next.add(descriptor.id);
                    return p.copyWith(requiredAttributes: next);
                  }),
                ),
            ],
          ),

          const SizedBox(height: 20),
          _CertificationNote(),

          // --- adaptation ----------------------------------------------------
          const SizedBox(height: 34),
          SectionHeader(s.settingsAdaptation),
          const SizedBox(height: 14),
          Eyebrow(s.settingsTimeBudget),
          Text(
            profile.maxTimeMinutes >= 240
                ? s.all
                : s.minutes(profile.maxTimeMinutes),
            style: MorphType.numeric(
              colors.ink,
              size: 22,
              weight: FontWeight.w700,
            ),
          ),
          Slider(
            value: profile.maxTimeMinutes.toDouble().clamp(15, 240),
            min: 15,
            max: 240,
            divisions: 15,
            onChanged: (v) =>
                _patch((p) => p.copyWith(maxTimeMinutes: v.round())),
          ),
          Text(
            s.settingsTimeBudgetNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          FaqLink(anchor: 'time-budget', label: s.helpLinkLabel),

          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: Eyebrow(s.settingsCalorieTarget)),
              Switch(
                value: profile.hasCalorieTarget,
                onChanged: (on) => _patch(
                  (p) => on
                      ? p.copyWith(calorieTarget: 600)
                      : p.copyWith(clearCalorieTarget: true),
                ),
              ),
            ],
          ),
          if (profile.hasCalorieTarget) ...[
            Text(
              '${s.kcal(profile.calorieTarget!)} ± ${profile.calorieTolerance}',
              style: MorphType.numeric(
                colors.ink,
                size: 22,
                weight: FontWeight.w700,
              ),
            ),
            Slider(
              value: profile.calorieTarget!.toDouble().clamp(200, 1200),
              min: 200,
              max: 1200,
              divisions: 20,
              onChanged: (v) =>
                  _patch((p) => p.copyWith(calorieTarget: v.round())),
            ),
            Text(
              s.settingsCalorieTolerance,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Slider(
              value: profile.calorieTolerance.toDouble().clamp(50, 500),
              min: 50,
              max: 500,
              divisions: 9,
              onChanged: (v) =>
                  _patch((p) => p.copyWith(calorieTolerance: v.round())),
            ),
            FaqLink(anchor: 'calorie-target', label: s.helpLinkLabel),
          ] else
            Text(
              s.settingsCalorieTargetOff,
              style: Theme.of(context).textTheme.bodySmall,
            ),

          const SizedBox(height: 22),
          Eyebrow(s.settingsEffort),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final effort in ontology.efforts)
                InkChip(
                  label: effort.label(s.lang),
                  selected: profile.preferredEffort == effort.id,
                  tooltip: effort.note(s.lang),
                  onTap: () =>
                      _patch((p) => p.copyWith(preferredEffort: effort.id)),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: profile.showVariantTags,
            title: Text(s.settingsShowTags),
            subtitle: Text(s.settingsShowTagsNote),
            onChanged: (v) => _patch((p) => p.copyWith(showVariantTags: v)),
          ),

          // --- accessibility -------------------------------------------------
          const SizedBox(height: 24),
          SectionHeader(s.settingsAccessibility),
          const SizedBox(height: 14),
          Eyebrow(s.settingsReduceMotion),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              InkChip(
                label: s.settingsReduceMotionSystem,
                dense: true,
                selected: profile.reduceMotion == null,
                onTap: () => _patch((p) => p.copyWith(clearReduceMotion: true)),
              ),
              InkChip(
                label: s.settingsReduceMotionOn,
                dense: true,
                selected: profile.reduceMotion == true,
                onTap: () => _patch((p) => p.copyWith(reduceMotion: true)),
              ),
              InkChip(
                label: s.settingsReduceMotionOff,
                dense: true,
                selected: profile.reduceMotion == false,
                onTap: () => _patch((p) => p.copyWith(reduceMotion: false)),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: profile.visualAlertEnabled,
            title: Text(s.settingsVisualAlert),
            subtitle: Text(s.settingsVisualAlertNote),
            onChanged: (v) => _patch((p) => p.copyWith(visualAlertEnabled: v)),
          ),
          FaqLink(anchor: 'visual-alert', label: s.helpLinkLabel),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: profile.quickNextTapEnabled,
            title: Text(s.settingsQuickTap),
            subtitle: Text(s.settingsQuickTapNote),
            onChanged: (v) => _patch((p) => p.copyWith(quickNextTapEnabled: v)),
          ),
          FaqLink(anchor: 'quick-tap', label: s.helpLinkLabel),

          // --- data -----------------------------------------------------------
          const SizedBox(height: 30),
          SectionHeader(s.settingsData),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.ios_share),
            title: Text(s.settingsExport),
            subtitle: Text(s.settingsExportNote),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insights_outlined),
            title: Text(s.listInsights),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const InsightsScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.edit_note),
            title: Text(s.settingsContentRequests),
            subtitle: Text(
              state.contentRequests.isEmpty
                  ? s.settingsContentRequestsNote
                  : '${s.contentRequestCount(state.contentRequests.length)} — '
                        '${state.contentRequests.map((r) => r.query).take(3).join(', ')}',
            ),
            trailing: state.contentRequests.isEmpty
                ? null
                : TextButton(
                    onPressed: state.clearContentRequests,
                    child: Text(s.settingsClearRequests),
                  ),
          ),

          // --- about -----------------------------------------------------------
          const SizedBox(height: 30),
          SectionHeader(s.settingsAbout),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(s.settingsHelp),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const FaqScreen())),
          ),
          const SizedBox(height: 8),
          Text(
            s.corpusSummary(
              state.repository.dishes.length,
              state.repository.manifest.partitions
                  .where((p) => p.id == 'core' || p.id == 'extended')
                  .fold(0, (sum, p) => sum + p.recipeCount),
              state.repository.manifest.corpusVersion,
            ),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Text(s.settingsOffline, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          DashedRule(color: colors.edge),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _confirmReset(context, state, s),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: Text(s.settingsReset),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _confirmReset(
    BuildContext context,
    AppState state,
    S s,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.settingsReset),
        content: Text(s.settingsResetConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.settingsReset),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await state.resetEverything();
      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }
}

/// Verbatim from the ontology so the wording lives with the data it describes.
class _CertificationNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.paperSunk,
        border: Border.all(color: colors.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(s.certificationHeadline),
          const SizedBox(height: 8),
          Text(
            state.repository.ontology.certificationNote(s.lang),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FaqLink(anchor: 'halal-kosher', label: s.helpLinkLabel),
        ],
      ),
    );
  }
}
