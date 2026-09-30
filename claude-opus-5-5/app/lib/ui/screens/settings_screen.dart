import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../models/profile.dart';
import '../../state/profile_controller.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';
import '../widgets/profile_editors.dart';

/// Full profile editor, language, adaptation & comfort preferences, data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _name = TextEditingController(text: context.read<ProfileController>().profile.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final ctrl = context.watch<ProfileController>();
    final repo = context.read<CorpusRepository>();
    final profile = ctrl.profile;
    void update(Profile p) => ctrl.replace(p);

    Widget sub(String label) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: MonoLabel(label));

    Widget toggle(String title, String? body, bool value, ValueChanged<bool> onChanged, {Key? key}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MT.serif(16)),
                if (body != null) Text(body, style: MT.serif(13, color: MC.inkSoft, height: 1.35)),
              ],
            ),
          ),
          Switch(key: key, value: value, onChanged: onChanged),
        ],
      ),
    );

    final hasCertSensitive = profile.avoidFlags.any(repo.ontology.certificationSensitive.contains);

    return Scaffold(
      appBar: AppBar(title: Text(tr('settings.title'))),
      body: PaperBackground(
        child: ListView(
          key: const Key('settings-list'),
          padding: const EdgeInsets.only(bottom: 50),
          children: [
            SectionHeader(tr('settings.you'), padding: const EdgeInsets.fromLTRB(20, 8, 20, 6)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sub(tr('settings.name')),
                  TextField(
                    key: const Key('settings-name'),
                    controller: _name,
                    style: MT.serif(17),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (v) => ctrl.update((p) => p.copyWith(name: v.trim())),
                  ),
                  sub(tr('settings.language')),
                  Wrap(
                    spacing: 8,
                    children: [
                      InkChip(
                        key: const Key('settings-lang-en'),
                        label: 'english',
                        selected: profile.lang == 'en',
                        onTap: () => update(profile.copyWith(lang: 'en')),
                      ),
                      InkChip(
                        key: const Key('settings-lang-de'),
                        label: 'deutsch',
                        selected: profile.lang == 'de',
                        onTap: () => update(profile.copyWith(lang: 'de')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SectionHeader(tr('settings.kitchen')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sub(tr('settings.ways')),
                  DietChoicesEditor(profile: profile, onChanged: update),
                  const SizedBox(height: 14),
                  // Always shown near the halal/kosher toggles, per the spec.
                  CertificationNote(onMore: () => openFaq(context, entryId: 'halal-kosher')),
                  if (hasCertSensitive) const SizedBox(height: 4),
                  sub(tr('settings.classes')),
                  ClassAvoidanceEditor(profile: profile, onChanged: update),
                  sub(tr('settings.specific')),
                  IngredientAvoidPicker(profile: profile, onChanged: update),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextLink(tr('home.why'), onTap: () => openFaq(context, entryId: 'class-vs-specific')),
                  ),
                  sub(tr('settings.musthave')),
                  Text(tr('settings.musthave.body'), style: MT.serif(14, color: MC.inkSoft)),
                  const SizedBox(height: 8),
                  RequiredAttributesEditor(profile: profile, onChanged: update),
                ],
              ),
            ),
            SectionHeader(tr('settings.limits')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LimitsEditor(profile: profile, onChanged: update, showTolerance: true),
                  TextLink(tr('dish.variants.help'), onTap: () => openFaq(context, entryId: 'calorie-target')),
                ],
              ),
            ),
            SectionHeader(tr('settings.adapt')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: toggle(
                tr('settings.showTags'),
                null,
                profile.showVariantTags,
                (v) => update(profile.copyWith(showVariantTags: v)),
                key: const Key('toggle-tags'),
              ),
            ),
            SectionHeader(tr('settings.comfort')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('settings.reduceMotion'), style: MT.serif(16)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      InkChip(
                        label: tr('settings.reduceMotion.system'),
                        selected: profile.reduceMotion == null,
                        onTap: () => update(profile.copyWith(reduceMotion: () => null)),
                      ),
                      InkChip(
                        key: const Key('reduce-motion-on'),
                        label: tr('settings.reduceMotion.on'),
                        selected: profile.reduceMotion == true,
                        onTap: () => update(profile.copyWith(reduceMotion: () => true)),
                      ),
                      InkChip(
                        label: tr('settings.reduceMotion.off'),
                        selected: profile.reduceMotion == false,
                        onTap: () => update(profile.copyWith(reduceMotion: () => false)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  toggle(
                    tr('settings.visualAlert'),
                    tr('settings.visualAlert.body'),
                    profile.visualAlertEnabled,
                    (v) => update(profile.copyWith(visualAlertEnabled: v)),
                    key: const Key('toggle-visual-alert'),
                  ),
                  toggle(
                    tr('settings.quickTap'),
                    tr('settings.quickTap.body'),
                    profile.quickNextTapEnabled,
                    (v) => update(profile.copyWith(quickNextTapEnabled: v)),
                    key: const Key('toggle-quick-tap'),
                  ),
                  TextLink(tr('dish.variants.help'), onTap: () => openFaq(context, entryId: 'cook-mode')),
                ],
              ),
            ),
            SectionHeader(tr('settings.data')),
            _NavRow(
              key: const Key('nav-backup'),
              icon: Icons.save_alt_outlined,
              label: tr('settings.backup'),
              onTap: () => openBackup(context),
            ),
            _NavRow(
              key: const Key('nav-insights'),
              icon: Icons.insights_outlined,
              label: tr('settings.insights'),
              onTap: () => openInsights(context),
            ),
            _NavRow(
              key: const Key('nav-history'),
              icon: Icons.history,
              label: tr('settings.history'),
              onTap: () => openHistory(context),
            ),
            _NavRow(
              key: const Key('nav-help'),
              icon: Icons.help_outline,
              label: tr('settings.help'),
              onTap: () => openFaq(context),
            ),
            SectionHeader(tr('settings.about')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('settings.about.body', {'v': repo.manifest.corpusVersion}),
                    style: MT.serif(14.5, color: MC.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  PaperButton(
                    label: tr('settings.redoOnboarding'),
                    dense: true,
                    onPressed: () {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      ctrl.update((p) => p.copyWith(onboarded: false));
                    },
                  ),
                  const SizedBox(height: 18),
                  Center(child: HandNote('made with care & butter', size: 20, color: MC.inkFaint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MC.inkSoft),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: MT.serif(17))),
          const Icon(Icons.chevron_right, color: MC.inkFaint),
        ],
      ),
    ),
  );
}
