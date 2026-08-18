import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../core/util/dates.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';
import '../onboarding/diet_editor.dart';
import '../routes.dart';

/// Settings (SPEC): full profile editor, language toggle, adaptation
/// preferences, halal/kosher documentation note, data tools, FAQ.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  TextStyle _labelStyle() => AppFonts.serif(size: 16, color: AppColors.ink);

  TextStyle _valueStyle() => AppFonts.mono(size: 11, color: AppColors.inkSoft);

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppFonts.display(size: 22, color: AppColors.tealDeep)),
            const SizedBox(height: 4),
            const DashedRule(),
          ],
        ),
      );

  Future<void> _editName() async {
    final state = context.read<AppState>();
    final controller =
        TextEditingController(text: state.profile.name ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.paperCard,
        title: Text(dialogContext.trRead('set.name'), style: AppFonts.display(size: 20)),
        content: TextField(controller: controller, style: AppFonts.serif(size: 16)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.trRead('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.trRead('common.save'))),
        ],
      ),
    );
    if (ok == true) {
      await state.updateProfile(state.profile.copy()
        ..name = controller.text.trim());
    }
  }
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final lang = state.lang;

    return PaperScaffold(
      seed: 91,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 54, 0, 40),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('set.title'),
                    style: AppFonts.display(size: 40, color: AppColors.ink)),
                const SizedBox(height: 8),
                const DashedRule(glyph: '&'),
              ],
            ),
          ),
          _section(context.tr('set.profile')),
          ListTile(
            title: Text(context.tr('set.name'), style: _labelStyle()),
            subtitle: Text(
                profile.name == null || profile.name!.isEmpty ? '—' : profile.name!,
                style: _valueStyle()),
            trailing: const Icon(Icons.edit_outlined, size: 16, color: AppColors.teal),
            onTap: _editName,
          ),
          ListTile(
            title: Text(context.tr('set.lang'), style: _labelStyle()),
            subtitle: Wrap(
              spacing: 8,
              children: [
                for (final code in ['en', 'de'])
                  SelectablePill(
                    label: code == 'en' ? 'english' : 'deutsch',
                    selected: profile.lang == code,
                    onTap: () => state.updateProfile(profile.copy()..lang = code),
                    compact: true,
                  ),
              ],
            ),
          ),
          _section(context.tr('set.diet')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: DietEditor(
              profile: profile,
              onChanged: () async {
                await state.updateProfile(profile);
                setState(() {});
              },
            ),
          ),
          _numbersSection(state, profile, lang),
          _adaptationSection(state, profile),
          _dataSection(state, lang),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _numbersSection(AppState state, dynamic profile, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context.tr('set.calorie')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('set.calorieBody'),
                  style: AppFonts.hand(size: 15, color: AppColors.inkSoft)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final target in [400, 550, 700, 850])
                    SelectablePill(
                      label: '$target',
                      selected: profile.calorieTarget == target,
                      onTap: () =>
                          state.updateProfile(profile.copy()..calorieTarget = target),
                      compact: true,
                    ),
                  SelectablePill(
                    label: context.tr('common.none'),
                    selected: profile.calorieTarget == null,
                    onTap: () =>
                        state.updateProfile(profile.copy()..calorieTarget = null),
                    compact: true,
                  ),
                ],
              ),
            ],
          ),
        ),
        _section(context.tr('set.time')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final minutes in [20, 30, 45, 60, 90])
                SelectablePill(
                  label: '$minutes ${context.trRead('common.min')}',
                  selected: profile.maxTimeMinutes == minutes,
                  onTap: () =>
                      state.updateProfile(profile.copy()..maxTimeMinutes = minutes),
                  compact: true,
                ),
              SelectablePill(
                label: context.tr('onb.time.none'),
                selected: profile.maxTimeMinutes == null,
                onTap: () =>
                    state.updateProfile(profile.copy()..maxTimeMinutes = null),
                compact: true,
              ),
            ],
          ),
        ),
        _section(context.tr('set.effort')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final effort in state.corpus.ontology.efforts)
                SelectablePill(
                  label: state.corpus.ontology.attrLabel(effort.id, lang),
                  selected: profile.preferredEffort == effort.id,
                  onTap: () => state
                      .updateProfile(profile.copy()..preferredEffort = effort.id),
                  compact: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _adaptationSection(AppState state, dynamic profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context.tr('set.adaptation')),
        SwitchListTile(
          value: profile.showVariantTags,
          onChanged: (v) => state.updateProfile(profile.copy()..showVariantTags = v),
          title: Text(context.tr('set.showTags'), style: _labelStyle()),
          activeColor: AppColors.teal,
        ),
        SwitchListTile(
          value: profile.reduceMotion ?? MediaQuery.of(context).disableAnimations,
          onChanged: (v) => state.updateProfile(profile.copy()..reduceMotion = v),
          subtitle: Text(context.tr('set.reduceMotionSystem'),
              style: AppFonts.mono(size: 9, color: AppColors.inkFaint)),
          title: Text(context.tr('set.reduceMotion'), style: _labelStyle()),
          activeColor: AppColors.teal,
        ),
        SwitchListTile(
          value: profile.visualAlertEnabled,
          onChanged: (v) => state.updateProfile(profile.copy()..visualAlertEnabled = v),
          subtitle: Text(context.tr('set.visualAlertBody'),
              style: AppFonts.hand(size: 15, color: AppColors.inkSoft)),
          title: Text(context.tr('set.visualAlert'), style: _labelStyle()),
          activeColor: AppColors.teal,
        ),
        SwitchListTile(
          value: state.profileStore.quickNextTapEnabled,
          onChanged: (v) async {
            await state.profileStore.setQuickNextTapEnabled(v);
            setState(() {});
          },
          title: Text(context.tr('set.quickNext'), style: _labelStyle()),
          activeColor: AppColors.teal,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  context.tr('set.halalNote'),
                  style: AppFonts.hand(size: 15, color: AppColors.inkSoft, height: 1.35),
                ),
              ),
              QuietLink(
                label: context.tr('common.why'),
                onTap: () => openFaq(context, 'faq-halal-kosher'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dataSection(AppState state, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section(context.tr('set.data')),
        ListTile(
          leading: const Icon(Icons.ios_share, size: 18, color: AppColors.teal),
          title: Text(context.tr('set.backup'), style: _labelStyle()),
          onTap: () => openBackup(context),
        ),
        ListTile(
          leading: const Icon(Icons.insights_outlined, size: 18, color: AppColors.teal),
          title: Text(context.tr('set.insights'), style: _labelStyle()),
          onTap: () => openShoppingInsights(context),
        ),
        ListTile(
          leading: const Icon(Icons.history_edu_outlined, size: 18, color: AppColors.teal),
          title: Text(context.tr('set.history'), style: _labelStyle()),
          onTap: () => openHistory(context),
        ),
        ListTile(
          leading: const Icon(Icons.help_outline, size: 18, color: AppColors.teal),
          title: Text(context.tr('common.viewFaq'), style: _labelStyle()),
          onTap: () => openFaq(context),
        ),
        // ---- content gap log ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('set.contentRequests'),
                  style: AppFonts.mono(
                      size: 10, color: AppColors.coral, letterSpacing: 1.4)),
              const SizedBox(height: 2),
              Text(context.tr('set.contentRequestsBody'),
                  style: AppFonts.hand(size: 15, color: AppColors.inkSoft)),
              const SizedBox(height: 6),
              if (state.contentRequests.isEmpty)
                Text('—', style: _valueStyle())
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final request in state.contentRequests.take(12))
                      TagChip(
                        label:
                            '${request.query} · ${DateFmt.shortDate(request.at, lang)}',
                        color: AppColors.mustard,
                      ),
                  ],
                ),
            ],
          ),
        ),
        _section(context.tr('set.about')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            context.tr('set.aboutBody', {'v': state.corpus.corpusVersion}),
            style: AppFonts.serif(size: 13, color: AppColors.inkSoft, height: 1.55),
          ),
        ),
      ],
    );
  }
}
