import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_state.dart';
import '../logic/backup.dart';
import '../logic/crypto.dart';
import '../models/collections.dart';
import 'faq.dart';
import 'home.dart';
import 'insights.dart';
import 'strings.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final profile = state.profile;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(s('settings'), style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 16),
          SectionLabel(s('profile')),
          TextFormField(
            initialValue: profile.name,
            decoration: InputDecoration(labelText: s('yourName')),
            onFieldSubmitted: (v) =>
                state.updateProfile(profile.copyWith(name: v)),
          ),
          const SizedBox(height: 12),
          Text(s('language')),
          Wrap(
            spacing: 8,
            children: [
              SoftChip(
                label: 'english',
                selected: profile.lang == 'en',
                onTap: () => state.updateProfile(profile.copyWith(lang: 'en')),
              ),
              SoftChip(
                label: 'deutsch',
                selected: profile.lang == 'de',
                onTap: () => state.updateProfile(profile.copyWith(lang: 'de')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionLabel(s('dietAllergies')),
          const SizedBox(height: 8),
          Text(s('avoidClasses')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in state.corpus.ontology.compoundFlags)
                SoftChip(
                  label: c.name.of(state.lang),
                  selected: profile.avoidFlags.contains(c.id),
                  onTap: () {
                    final next = Set<String>.from(profile.avoidFlags);
                    if (!next.add(c.id)) next.remove(c.id);
                    state.updateProfile(profile.copyWith(avoidFlags: next));
                  },
                ),
              for (final f in state.corpus.ontology.containsFlags)
                SoftChip(
                  label: f.name.of(state.lang),
                  selected: profile.avoidFlags.contains(f.id),
                  onTap: () {
                    final next = Set<String>.from(profile.avoidFlags);
                    if (!next.add(f.id)) next.remove(f.id);
                    state.updateProfile(profile.copyWith(avoidFlags: next));
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s('halalKosherNote'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Text(s('avoidSpecific')),
          _IngredientTypeahead(
            onPick: (id) {
              final next = Set<String>.from(profile.avoidIngredients)..add(id);
              state.updateProfile(profile.copyWith(avoidIngredients: next));
            },
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final id in profile.avoidIngredients)
                SoftChip(
                  label: state.corpus.dictionary.nameOf(id, state.lang),
                  selected: true,
                  onTap: () {
                    final next = Set<String>.from(profile.avoidIngredients)
                      ..remove(id);
                    state.updateProfile(
                      profile.copyWith(avoidIngredients: next),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(s('requiredAttributes')),
          Wrap(
            spacing: 6,
            children: [
              for (final id in ['halal', 'kosher', 'gluten-free', 'sugar-free'])
                SoftChip(
                  label: state.corpus.ontology.nameOf(id, state.lang),
                  selected: profile.requiredAttributes.contains(id),
                  onTap: () {
                    final next = Set<String>.from(profile.requiredAttributes);
                    if (!next.add(id)) next.remove(id);
                    state.updateProfile(
                      profile.copyWith(requiredAttributes: next),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          SectionLabel(s('adaptationPrefs')),
          const SizedBox(height: 8),
          Text(s('calorieTarget')),
          Wrap(
            spacing: 6,
            children: [
              SoftChip(
                label: s('noLimit'),
                selected: profile.calorieTarget == null,
                onTap: () => state.updateProfile(
                  profile.copyWith(clearCalorieTarget: true),
                ),
              ),
              for (final c in [400, 550, 700, 900])
                SoftChip(
                  label: '$c',
                  selected: profile.calorieTarget == c,
                  onTap: () =>
                      state.updateProfile(profile.copyWith(calorieTarget: c)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s('timeBudget')),
          Wrap(
            spacing: 6,
            children: [
              SoftChip(
                label: s('noLimit'),
                selected: profile.maxTimeMinutes == null,
                onTap: () =>
                    state.updateProfile(profile.copyWith(clearMaxTime: true)),
              ),
              for (final t in [15, 30, 45, 60, 90])
                SoftChip(
                  label: '$t',
                  selected: profile.maxTimeMinutes == t,
                  onTap: () =>
                      state.updateProfile(profile.copyWith(maxTimeMinutes: t)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(s('preferredEffort')),
          Wrap(
            spacing: 6,
            children: [
              for (final e in ['easy', 'medium', 'hard'])
                SoftChip(
                  label: state.corpus.ontology.nameOf(e, state.lang),
                  selected: profile.preferredEffort == e,
                  onTap: () => state.updateProfile(
                    profile.copyWith(preferredEffort: e),
                  ),
                ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s('showVariantTags')),
            value: profile.showVariantTags,
            onChanged: (v) =>
                state.updateProfile(profile.copyWith(showVariantTags: v)),
          ),
          const SizedBox(height: 12),
          SectionLabel(s('accessibility')),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('reduceMotion')),
            subtitle: Text(
              profile.reduceMotion == null
                  ? s('systemDefault')
                  : (profile.reduceMotion! ? s('on') : s('off')),
            ),
            onTap: () {
              final next = switch (profile.reduceMotion) {
                null => true,
                true => false,
                false => null,
              };
              state.updateProfile(
                profile.copyWith(
                  reduceMotion: next,
                  clearReduceMotion: next == null,
                ),
              );
            },
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s('visualAlert')),
            subtitle: Text(s('visualAlertHint')),
            value: profile.visualAlertEnabled,
            onChanged: (v) =>
                state.updateProfile(profile.copyWith(visualAlertEnabled: v)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(s('quickTap')),
            subtitle: Text(s('quickTapSettingHint')),
            value: profile.quickNextTapEnabled,
            onChanged: (v) =>
                state.updateProfile(profile.copyWith(quickNextTapEnabled: v)),
          ),
          const SizedBox(height: 16),
          SectionLabel(s('backup')),
          const SizedBox(height: 8),
          const _BackupPanel(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('shoppingInsights')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InsightsScreen()),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s('helpCenter')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openFaq(context),
          ),
          const SizedBox(height: 12),
          SectionLabel(s('history')),
          const _HistoryList(),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(s('resetApp')),
                  content: Text(s('resetConfirm')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(s('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(s('erase')),
                    ),
                  ],
                ),
              );
              if (ok == true) await state.resetAll();
            },
            child: Text(s('resetApp')),
          ),
        ],
      ),
    );
  }
}

class _IngredientTypeahead extends StatefulWidget {
  final void Function(String id) onPick;
  const _IngredientTypeahead({required this.onPick});

  @override
  State<_IngredientTypeahead> createState() => _IngredientTypeaheadState();
}

class _IngredientTypeaheadState extends State<_IngredientTypeahead> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final hits = state.corpus.dictionary.search(_q, state.lang).take(8);
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(hintText: s('avoidSpecificHint')),
          onChanged: (v) => setState(() => _q = v),
        ),
        for (final n in hits)
          ListTile(
            dense: true,
            title: Text(n.name.of(state.lang)),
            onTap: () {
              widget.onPick(n.id);
              setState(() => _q = '');
            },
          ),
      ],
    );
  }
}

class _BackupPanel extends StatefulWidget {
  const _BackupPanel();

  @override
  State<_BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends State<_BackupPanel> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(
            labelText: s('backupPassword'),
            helperText: s('backupPasswordHint'),
          ),
        ),
        const SizedBox(height: 8),
        QuietButton(
          label: s('exportBackup'),
          filled: false,
          onPressed: () => _export(state),
        ),
        const SizedBox(height: 8),
        QuietButton(
          label: s('importBackup'),
          filled: false,
          onPressed: () => _import(state, s),
        ),
      ],
    );
  }

  Future<void> _export(AppState state) async {
    final exported = BackupService.export(
      state.buildBackup(),
      password: _password.text,
    );
    final dir = await getTemporaryDirectory();
    final jsonPath = '${dir.path}/morphcook-backup.json';
    final gzPath = '${dir.path}/morphcook-backup.json.gz';
    await File(jsonPath).writeAsBytes(exported.jsonFile);
    await File(gzPath).writeAsBytes(exported.gzipFile);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(jsonPath), XFile(gzPath)],
        subject: 'morphcook backup',
      ),
    );
  }

  Future<void> _import(AppState state, S s) async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final bytes = picked.files.first.bytes ??
        await File(picked.files.first.path!).readAsBytes();
    try {
      final data = BackupService.import(bytes, password: _password.text);
      if (!mounted) return;
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s('importBackup')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s('importMerge')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s('importReplace')),
            ),
          ],
        ),
      );
      if (choice == null) return;
      await state.applyBackup(data, merge: choice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s('importDone'))),
        );
      }
    } on DecryptionException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    if (state.history.isEmpty) {
      return Text(s('historyEmpty'));
    }
    final grouped = <String, List<HistoryEntry>>{};
    for (final h in state.history.reversed) {
      grouped.putIfAbsent(isoWeekKey(h.cookedAt), () => []).add(h);
    }
    final weeks = grouped.keys.take(4).toList();
    return Column(
      children: [
        for (final week in weeks) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${s('week')} $week'),
          ),
          for (final h in grouped[week]!)
            FutureBuilder(
              future: state.corpus.recipeById(h.recipeId),
              builder: (context, snap) {
                final r = snap.data;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(r?.title.of(state.lang) ?? h.recipeId),
                  subtitle: Text(h.cookedAt.toLocal().toString().split('.').first),
                  onTap: r == null
                      ? null
                      : () => openDish(context, r.dishId, recipeId: r.id),
                );
              },
            ),
        ],
      ],
    );
  }
}
