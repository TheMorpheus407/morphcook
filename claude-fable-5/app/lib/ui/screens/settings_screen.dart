import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../../logic/backup/backup_service.dart';
import '../../logic/backup/crypto.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';
import 'faq_screen.dart';
import 'insights_screen.dart';
import 'shopping_list_screen.dart';

const _patreonUrl = 'https://www.patreon.com/c/themorpheus';
const _websiteUrl = 'https://www.the-morpheus.de/';

/// Settings: full profile editor, language toggle, adaptation preferences,
/// accessibility, backup/restore, links to insights & help center,
/// about & support.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _ingredientQuery = TextEditingController();

  @override
  void dispose() {
    _ingredientQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;
    final profile = state.profile;
    final ontology = state.corpus.ontology;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(s('settings'),
              style: MorphText.display.copyWith(fontSize: 30)),
          const SizedBox(height: 8),

          SectionHeader(title: s('profile')),
          TextFormField(
            initialValue: profile.name,
            style: MorphText.mono.copyWith(fontSize: 13),
            decoration: _underline(s('yourName')),
            onFieldSubmitted: (v) =>
                state.updateProfile(profile.copyWith(name: v.trim())),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(s('language'), style: MorphText.label()),
              const Spacer(),
              MonoChip(
                label: 'english',
                selected: lang == 'en',
                onTap: () =>
                    state.updateProfile(profile.copyWith(lang: 'en')),
              ),
              const SizedBox(width: 8),
              MonoChip(
                label: 'deutsch',
                selected: lang == 'de',
                onTap: () =>
                    state.updateProfile(profile.copyWith(lang: 'de')),
              ),
            ],
          ),

          SectionHeader(title: s('dietAllergies')),
          Text(s('avoidClasses'), style: MorphText.label(size: 10)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final compound in ontology.compoundFlags)
                MonoChip(
                  label: compound.name.of(lang),
                  selected: profile.avoidFlags.contains(compound.id),
                  onTap: () => _toggleSet(
                      state,
                      profile.avoidFlags,
                      compound.id,
                      (set) => profile.copyWith(avoidFlags: set)),
                ),
              for (final flag in ontology.containsFlags)
                MonoChip(
                  label: flag.name.of(lang),
                  selected: profile.avoidFlags.contains(flag.id),
                  onTap: () => _toggleSet(
                      state,
                      profile.avoidFlags,
                      flag.id,
                      (set) => profile.copyWith(avoidFlags: set)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(s('halalKosherNote'),
                style: MorphText.hand
                    .copyWith(fontSize: 16, color: MorphColors.inkSoft)),
          ),
          const SizedBox(height: 14),
          Text(s('avoidSpecific'), style: MorphText.label(size: 10)),
          const SizedBox(height: 6),
          _specificAvoidance(state, s, lang),

          SectionHeader(title: s('requiredAttributes')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in const [
                'halal', 'kosher', 'vegan', 'vegetarian',
                'gluten-free', 'low-fodmap', 'sugar-free'
              ])
                MonoChip(
                  label: ontology.nameOf(label, lang),
                  selected: profile.requiredAttributes.contains(label),
                  onTap: () => _toggleSet(
                      state,
                      profile.requiredAttributes,
                      label,
                      (set) =>
                          profile.copyWith(requiredAttributes: set)),
                ),
            ],
          ),

          SectionHeader(title: s('adaptationPrefs')),
          _sliderRow(
            label: s('calorieTarget'),
            value: profile.calorieTarget?.toDouble(),
            min: 300,
            max: 1000,
            divisions: 14,
            display: (v) => v == null ? s('noLimit') : '${v.round()} kcal',
            onChanged: (v) => state.updateProfile(v == null
                ? profile.copyWith(clearCalorieTarget: true)
                : profile.copyWith(calorieTarget: v.round())),
          ),
          _sliderRow(
            label: s('timeBudget'),
            value: profile.maxTimeMinutes?.toDouble(),
            min: 15,
            max: 240,
            divisions: 15,
            display: (v) =>
                v == null ? s('noLimit') : '${v.round()} ${s('minutes')}',
            onChanged: (v) => state.updateProfile(v == null
                ? profile.copyWith(clearMaxTime: true)
                : profile.copyWith(maxTimeMinutes: v.round())),
          ),
          const SizedBox(height: 10),
          Text(s('preferredEffort'), style: MorphText.label()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final effort in const ['easy', 'medium', 'hard'])
                MonoChip(
                  label: ontology.nameOf(effort, lang),
                  selected: profile.preferredEffort == effort,
                  onTap: () => state.updateProfile(
                      profile.copyWith(preferredEffort: effort)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _switchRow(
            s('showVariantTags'),
            profile.showVariantTags,
            (v) =>
                state.updateProfile(profile.copyWith(showVariantTags: v)),
          ),

          SectionHeader(title: s('accessibility')),
          Row(
            children: [
              Expanded(
                  child:
                      Text(s('reduceMotion'), style: MorphText.label())),
              MonoChip(
                label: s('systemDefault'),
                selected: profile.reduceMotion == null,
                onTap: () => state.updateProfile(
                    profile.copyWith(clearReduceMotion: true)),
              ),
              const SizedBox(width: 6),
              MonoChip(
                label: s('on'),
                selected: profile.reduceMotion == true,
                onTap: () => state
                    .updateProfile(profile.copyWith(reduceMotion: true)),
              ),
              const SizedBox(width: 6),
              MonoChip(
                label: s('off'),
                selected: profile.reduceMotion == false,
                onTap: () => state
                    .updateProfile(profile.copyWith(reduceMotion: false)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _switchRow(
            s('visualAlert'),
            profile.visualAlertEnabled,
            (v) => state
                .updateProfile(profile.copyWith(visualAlertEnabled: v)),
            hint: s('visualAlertHint'),
          ),
          _switchRow(
            s('quickTap'),
            profile.quickNextTapEnabled,
            (v) => state
                .updateProfile(profile.copyWith(quickNextTapEnabled: v)),
            hint: s('quickTapSettingHint'),
          ),

          SectionHeader(title: s('backup')),
          _linkRow(Icons.ios_share, s('exportBackup'),
              () => _exportBackup(state, s)),
          _linkRow(Icons.download_outlined, s('importBackup'),
              () => _importBackup(state, s)),

          SectionHeader(title: '&'),
          _linkRow(
              Icons.shopping_basket_outlined,
              s('shoppingList'),
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ShoppingListScreen()))),
          _linkRow(
              Icons.insights_outlined,
              s('shoppingInsights'),
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const InsightsScreen()))),
          _linkRow(
              Icons.help_outline,
              s('helpCenter'),
              () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FaqScreen()))),

          SectionHeader(title: s('aboutSupport')),
          _supportCard(s),

          const SizedBox(height: 18),
          _linkRow(Icons.restart_alt, s('resetApp'),
              () => _confirmReset(state, s),
              color: MorphColors.coral),
        ],
      ),
    );
  }

  // ---- helpers ----

  InputDecoration _underline(String label) => InputDecoration(
        labelText: label,
        labelStyle: MorphText.label(),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: MorphColors.line)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: MorphColors.terracotta)),
      );

  void _toggleSet(AppState state, Set<String> current, String id,
      dynamic Function(Set<String>) update) {
    final next = Set<String>.from(current);
    next.contains(id) ? next.remove(id) : next.add(id);
    state.updateProfile(update(next) as dynamic);
  }

  Widget _specificAvoidance(AppState state, S s, String lang) {
    final profile = state.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.avoidIngredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in profile.avoidIngredients)
                  MonoChip(
                    label:
                        '${state.corpus.dictionary.byId(id)?.name.of(lang) ?? id} ×',
                    selected: true,
                    onTap: () {
                      final next =
                          Set<String>.from(profile.avoidIngredients)
                            ..remove(id);
                      state.updateProfile(
                          profile.copyWith(avoidIngredients: next));
                    },
                  ),
              ],
            ),
          ),
        Autocomplete<String>(
          optionsBuilder: (value) {
            if (value.text.trim().length < 2) {
              return const Iterable<String>.empty();
            }
            return state.corpus.dictionary
                .search(value.text, lang)
                .where((n) => !profile.avoidIngredients.contains(n.id))
                .take(8)
                .map((n) => n.id);
          },
          displayStringForOption: (id) =>
              state.corpus.dictionary.byId(id)?.name.of(lang) ?? id,
          fieldViewBuilder:
              (context, controller, focusNode, onSubmitted) => TextField(
            controller: controller,
            focusNode: focusNode,
            style: MorphText.mono.copyWith(fontSize: 13),
            decoration: _underline(s('avoidSpecificHint')),
          ),
          onSelected: (id) {
            final next = Set<String>.from(profile.avoidIngredients)
              ..add(id);
            state.updateProfile(
                profile.copyWith(avoidIngredients: next));
          },
        ),
      ],
    );
  }

  Widget _sliderRow({
    required String label,
    required double? value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double?) display,
    required void Function(double?) onChanged,
  }) {
    final active = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: MorphText.label())),
            Text(display(value),
                style: MorphText.mono.copyWith(
                    fontSize: 12, color: MorphColors.terracotta)),
            Checkbox(
              value: active,
              activeColor: MorphColors.terracotta,
              onChanged: (v) =>
                  onChanged(v == true ? (min + max) / 2 : null),
            ),
          ],
        ),
        if (active)
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: MorphColors.terracotta,
            onChanged: onChanged,
          ),
      ],
    );
  }

  Widget _switchRow(String label, bool value, void Function(bool) onChanged,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: MorphText.label())),
            Switch(
              value: value,
              activeThumbColor: MorphColors.terracotta,
              onChanged: onChanged,
            ),
          ],
        ),
        if (hint != null)
          Text(hint,
              style: MorphText.hand
                  .copyWith(fontSize: 15, color: MorphColors.inkSoft)),
      ],
    );
  }

  /// Polaroid-flavoured card: logo, handwritten credit, honest mono note,
  /// two outbound links. Visible, not pushy.
  Widget _supportCard(S s) {
    return Container(
      decoration: BoxDecoration(
        color: MorphColors.card,
        border: Border.all(color: MorphColors.line),
        boxShadow: [
          BoxShadow(
            color: MorphColors.ink.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                'assets/mo-logo.png',
                width: 64,
                color: MorphColors.ink, // pure-black source, tinted to ink
                excludeFromSemantics: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(s('supportMadeBy'),
                    style: MorphText.hand
                        .copyWith(fontSize: 21, color: MorphColors.ink)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s('supportBody'),
              style: MorphText.mono
                  .copyWith(fontSize: 12, color: MorphColors.inkSoft)),
          const DashedDivider(height: 20),
          _linkRow(Icons.favorite_border, s('supportPatreon'),
              () => _openExternal(_patreonUrl),
              color: MorphColors.terracotta),
          _linkRow(Icons.public, s('supportWebsite'),
              () => _openExternal(_websiteUrl)),
        ],
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } on Exception {
      _toast(url); // no browser? at least show where to go.
    }
  }

  Widget _linkRow(IconData icon, String label, VoidCallback onTap,
      {Color color = MorphColors.ink}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(label,
                style: MorphText.mono.copyWith(fontSize: 13, color: color)),
            const Spacer(),
            const Icon(Icons.chevron_right,
                size: 16, color: MorphColors.inkFaint),
          ],
        ),
      ),
    );
  }

  // ---- backup ----

  Future<void> _exportBackup(AppState state, S s) async {
    final password = await _promptPassword(s, s('backupPassword'),
        hint: s('backupPasswordHint'), allowEmpty: true);
    if (password == null) return; // cancelled

    final export = BackupService.export(
      state.buildBackup(),
      password: password.isEmpty ? null : password,
    );
    final dir = await getTemporaryDirectory();
    final jsonFile = File('${dir.path}/morphcook-backup.json');
    final gzFile = File('${dir.path}/morphcook-backup.json.gz');
    await jsonFile.writeAsBytes(export.jsonFile);
    await gzFile.writeAsBytes(export.gzipFile);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(jsonFile.path), XFile(gzFile.path)],
      subject: 'morphcook backup',
    ));
  }

  Future<void> _importBackup(AppState state, S s) async {
    final picked =
        await FilePicker.pickFiles(withData: true, type: FileType.any);
    final file = picked?.files.firstOrNull;
    if (file == null) return;
    final bytes = file.bytes ??
        (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null) {
      _toast('This file is not a valid MorphCook backup.');
      return;
    }

    String? password;
    if (BackupService.isEncrypted(bytes)) {
      password = await _promptPassword(s, s('enterPassword'));
      if (password == null) return;
    }

    BackupData data;
    try {
      data = BackupService.import(bytes, password: password);
    } on DecryptionException catch (e) {
      _toast(e.message);
      return;
    }

    if (!mounted) return;
    final merge = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MorphColors.paper,
        title: Text(s('importBackup'),
            style: MorphText.display.copyWith(fontSize: 20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('importMerge'), style: MorphText.label()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('importReplace'),
                style: MorphText.label(color: MorphColors.coral)),
          ),
        ],
      ),
    );
    if (merge == null) return;
    await state.applyBackup(data, merge: merge);
    _toast(s('importDone'));
  }

  Future<String?> _promptPassword(S s, String title,
      {String? hint, bool allowEmpty = false}) {
    return _promptText(s, '',
        label: title, hint: hint, obscure: true, allowEmpty: allowEmpty);
  }

  Future<String?> _promptText(S s, String initial,
      {required String label,
      String? hint,
      bool obscure = false,
      bool allowEmpty = true}) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MorphColors.paper,
        title:
            Text(label, style: MorphText.display.copyWith(fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              obscureText: obscure,
              autofocus: true,
              style: MorphText.mono.copyWith(fontSize: 13),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(hint,
                    style: MorphText.hand.copyWith(
                        fontSize: 15, color: MorphColors.inkSoft)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s('cancel'), style: MorphText.label()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('ok', style: MorphText.label()),
          ),
        ],
      ),
    );
    if (result == null) return null;
    if (!allowEmpty && result.isEmpty) return null;
    return result;
  }

  Future<void> _confirmReset(AppState state, S s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MorphColors.paper,
        content: Text(s('resetConfirm'),
            style: MorphText.mono.copyWith(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s('cancel'), style: MorphText.label()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s('erase'),
                style: MorphText.label(color: MorphColors.coral)),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.resetEverything();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
