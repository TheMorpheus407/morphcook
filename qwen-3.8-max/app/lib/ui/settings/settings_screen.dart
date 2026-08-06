import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../data/profile.dart';
import '../../services/backup.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../faq/faq_screen.dart';
import '../history/history_screen.dart';
import '../onboarding/ingredient_typeahead.dart';
import '../shopping/insights_screen.dart';
import '../widgets.dart';

/// Settings: full profile editor, language toggle, adaptation preferences,
/// cook-mode accessibility options, backup/restore, help & insights links.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final s = app.strings;

    return PaperGrain(
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Text('←',
                            style:
                                Type.mono(size: 16, color: Paper.inkSoft)),
                      ),
                      const SizedBox(width: 14),
                      Text(s.get('settings'),
                          style: Type.displayBold(size: 28)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(text: s.get('language')),
                      Row(
                        children: [
                          PaperChip(
                            label: 'English',
                            selected: app.lang == AppLang.en,
                            onTap: () => app.setLang(AppLang.en),
                          ),
                          PaperChip(
                            label: 'Deutsch',
                            selected: app.lang == AppLang.de,
                            onTap: () => app.setLang(AppLang.de),
                          ),
                        ],
                      ),
                      SectionHeader(text: s.get('profile')),
                      const _ProfileEditor(),
                      SectionHeader(text: s.get('adaptation')),
                      const _AdaptationSettings(),
                      SectionHeader(text: s.get('cookMode')),
                      const _CookModeSettings(),
                      SectionHeader(text: s.get('backup')),
                      const _BackupSection(),
                      SectionHeader(text: s.get('data')),
                      _LinkRow(
                        label: '✦ ${s.get('insights')}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const InsightsScreen()),
                        ),
                      ),
                      _LinkRow(
                        label: '↻ ${s.get('history')}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const HistoryScreen()),
                        ),
                      ),
                      _LinkRow(
                        label: '? ${s.get('helpCenter')}',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FaqScreen()),
                        ),
                      ),
                      _LinkRow(
                        label: '↺ ${s.get('resetOnboarding')}',
                        onTap: () async {
                          await context.read<AppModel>().resetOnboarding();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(s.get('aboutCorpus'),
                          style:
                              Type.mono(size: 10, color: Paper.inkFaint)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: Type.mono(size: 12.5, color: Paper.teal)),
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor();

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _name;
  late final TextEditingController _typeahead = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
        text: context.read<AppModel>().profile.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _typeahead.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;
    final profile = app.profile;
    final ontology = corpus.ontology;

    final compounds = ontology.compoundExpansions.keys.toList();
    final classFlags = [
      'dairy', 'gluten', 'egg', 'peanuts', 'tree-nuts', 'soy',
      'shellfish', 'fish', 'sesame', 'mustard', 'celery', 'pork',
      'alcohol', 'honey',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.get('name').toUpperCase(), style: Type.label()),
        const SizedBox(height: 6),
        PaperField(
          controller: _name,
          hint: s.get('name'),
          onChanged: (v) => app.updateProfile((p) => p.name = v),
        ),
        const SizedBox(height: 16),
        Text(s.get('dietAndAllergies').toUpperCase(), style: Type.label()),
        const SizedBox(height: 8),
        Wrap(children: [
          for (final flag in compounds)
            PaperChip(
              label: tx(ontology.compoundLabels[flag], lang),
              selected: profile.avoidFlags.contains(flag),
              onTap: () => app.updateProfile((p) =>
                  p.avoidFlags.contains(flag)
                      ? p.avoidFlags.remove(flag)
                      : p.avoidFlags.add(flag)),
            ),
        ]),
        const SizedBox(height: 8),
        Wrap(children: [
          for (final flag in classFlags)
            PaperChip(
              label: tx(ontology.containsFlags[flag], lang),
              selected: profile.avoidFlags.contains(flag),
              onTap: () => app.updateProfile((p) =>
                  p.avoidFlags.contains(flag)
                      ? p.avoidFlags.remove(flag)
                      : p.avoidFlags.add(flag)),
            ),
        ]),
        const SizedBox(height: 14),
        Text(s.get('avoidedIngredients').toUpperCase(), style: Type.label()),
        const SizedBox(height: 8),
        IngredientTypeahead(
          controller: _typeahead,
          dictionary: corpus.ingredients,
          lang: lang,
          selected: profile.avoidIngredients,
          onChanged: () => app.updateProfile((_) {}),
        ),
        const SizedBox(height: 14),
        Text(s.get('requiredAttributes').toUpperCase(), style: Type.label()),
        const SizedBox(height: 6),
        Text(s.get('halalKosherNote'),
            style: Type.mono(size: 10, color: Paper.inkFaint)),
        const SizedBox(height: 8),
        Wrap(children: [
          PaperChip(
            label: 'halal',
            selected: profile.requiredAttributes.contains('halal'),
            onTap: () => app.updateProfile((p) =>
                p.requiredAttributes.contains('halal')
                    ? p.requiredAttributes.remove('halal')
                    : p.requiredAttributes.add('halal')),
          ),
          PaperChip(
            label: 'kosher',
            selected: profile.requiredAttributes.contains('kosher'),
            onTap: () => app.updateProfile((p) =>
                p.requiredAttributes.contains('kosher')
                    ? p.requiredAttributes.remove('kosher')
                    : p.requiredAttributes.add('kosher')),
          ),
        ]),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${s.get('calorieTarget')}: ${profile.calorieTarget == null ? s.get('off') : '~${profile.calorieTarget} kcal'}',
                style: Type.mono(size: 11.5),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Paper.coral,
            inactiveTrackColor: Paper.deep,
            thumbColor: Paper.ink,
            overlayColor: Paper.coral.withValues(alpha: 0.12),
            trackHeight: 2,
          ),
          child: Slider(
            value: _calorieIndex(profile.calorieTarget).toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (v) {
              const steps = [0, 400, 500, 600, 700, 800];
              final target = steps[v.round()];
              app.updateProfile(
                  (p) => p.calorieTarget = target == 0 ? null : target);
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                '${s.get('timeBudget')}: ${profile.maxTimeMinutes == null ? s.get('noLimit') : '${profile.maxTimeMinutes} min'}',
                style: Type.mono(size: 11.5),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Paper.teal,
            inactiveTrackColor: Paper.deep,
            thumbColor: Paper.ink,
            overlayColor: Paper.teal.withValues(alpha: 0.12),
            trackHeight: 2,
          ),
          child: Slider(
            value: _timeIndex(profile.maxTimeMinutes).toDouble(),
            min: 0,
            max: 6,
            divisions: 6,
            onChanged: (v) {
              const steps = [0, 15, 20, 30, 45, 60, 90];
              final t = steps[v.round()];
              app.updateProfile(
                  (p) => p.maxTimeMinutes = t == 0 ? null : t);
            },
          ),
        ),
        Text(s.get('preferredEffort').toUpperCase(), style: Type.label()),
        const SizedBox(height: 8),
        Wrap(children: [
          for (final effort in ['easy', 'medium', 'hard'])
            PaperChip(
              label: tx(ontology.effortLabels[effort], lang),
              selected: profile.preferredEffort == effort,
              onTap: () => app.updateProfile(
                  (p) => p.preferredEffort = effort),
            ),
        ]),
      ],
    );
  }

  static int _calorieIndex(int? target) {
    const steps = [0, 400, 500, 600, 700, 800];
    final i = steps.indexOf(target ?? 0);
    return i < 0 ? 0 : i;
  }

  static int _timeIndex(int? minutes) {
    const steps = [0, 15, 20, 30, 45, 60, 90];
    final i = steps.indexOf(minutes ?? 0);
    return i < 0 ? 0 : i;
  }
}

class _AdaptationSettings extends StatelessWidget {
  const _AdaptationSettings();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final s = app.strings;
    final profile = app.profile;

    return Column(
      children: [
        _settingRow(
          s.get('showVariantTags'),
          PaperSwitch(
            value: profile.showVariantTags,
            onChanged: (v) =>
                app.updateProfile((p) => p.showVariantTags = v),
          ),
        ),
        _settingRow(
          '${s.get('reduceMotion')} (${profile.reduceMotion == null ? s.get('systemDefault') : (profile.reduceMotion! ? 'on' : 'off')})',
          PaperSwitch(
            value: profile.reduceMotion ?? false,
            onChanged: (v) => app.updateProfile((p) => p.reduceMotion = v),
          ),
        ),
      ],
    );
  }
}

class _CookModeSettings extends StatelessWidget {
  const _CookModeSettings();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final s = app.strings;
    final profile = app.profile;

    return Column(
      children: [
        _settingRow(
          s.get('visualAlerts'),
          PaperSwitch(
            value: profile.visualAlertEnabled,
            onChanged: (v) =>
                app.updateProfile((p) => p.visualAlertEnabled = v),
          ),
        ),
        _settingRow(
          s.get('quickTap'),
          PaperSwitch(
            value: profile.quickNextTapEnabled,
            onChanged: (v) =>
                app.updateProfile((p) => p.quickNextTapEnabled = v),
          ),
        ),
      ],
    );
  }
}

Widget _settingRow(String label, Widget control) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Type.mono(size: 12)),
        ),
        control,
      ],
    ),
  );
}

class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  final TextEditingController _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  BackupData _collect() {
    final app = context.read<AppModel>();
    final library = context.read<LibraryModel>();
    return BackupData(
      profile: app.profile.toJson(),
      saved: library.savedByDateDesc(),
      mealPlan: library.planAsBackupMap(),
      history: [
        for (final e in library.historyEntries())
          {'r': e.recipeId, 'at': e.at.toIso8601String()}
      ],
      contentRequests: library.contentRequests(),
    );
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final dir = await getTemporaryDirectory();
      final password = _password.text.trim();
      final paths = await BackupService.exportToDirectory(
        _collect(),
        dir,
        password: password.isEmpty ? null : password,
      );
      await SharePlus.instance.share(ShareParams(
        files: [for (final p in paths) XFile(p)],
        subject: 'MorphCook backup',
      ));
      if (mounted) {
        _toast(S.of(context).get('exportDone'));
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      } else {
        return;
      }
      await _importBytes(bytes);
    } on DecryptionException catch (e) {
      if (!mounted) return;
      if (e.reason == DecryptionReason.needsPassword) {
        await _promptPasswordAndRetry();
      } else {
        _toast(e.message);
      }
    } catch (e) {
      if (mounted) _toast(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promptPasswordAndRetry() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Paper.card,
        title: Text(S.of(context).get('enterPassword'),
            style: Type.display(size: 20)),
        content: PaperField(controller: controller, hint: '••••••••'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(S.of(context).get('back'),
                style: Type.mono(size: 12)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text),
            child: Text(S.of(context).get('continue_'),
                style: Type.mono(size: 12, color: Paper.coral)),
          ),
        ],
      ),
    );
    if (password == null || password.isEmpty) return;
    // Re-read the picked file path from the last pick is not retained;
    // ask the user to pick again with the password armed.
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes =
        file.bytes ?? await File(file.path ?? '').readAsBytes();
    try {
      final data = BackupService.parseEncrypted(bytes, password);
      await _applyImport(data);
    } on DecryptionException catch (e) {
      if (mounted) _toast(e.message);
    }
  }

  Future<void> _importBytes(Uint8List bytes) async {
    final password = _password.text.trim();
    final data = BackupService.parse(
        bytes, password: password.isEmpty ? null : password);
    await _applyImport(data);
  }

  Future<void> _applyImport(BackupData data) async {
    if (!mounted) return;
    final s = S.of(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Paper.card,
        title: Text(s.get('mergeOrReplace'), style: Type.display(size: 19)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('merge'),
            child: Text(s.get('merge'),
                style: Type.mono(size: 12, color: Paper.teal)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('replace'),
            child: Text(s.get('replace'),
                style: Type.mono(size: 12, color: Paper.coral)),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final app = context.read<AppModel>();
    final library = context.read<LibraryModel>();

    if (data.profile.isNotEmpty) {
      final imported = Profile.fromJson(data.profile);
      // Keep the current UI language unless the backup carries one.
      if (choice == 'merge') {
        imported.lang = app.profile.lang;
        imported.name =
            imported.name.isNotEmpty ? imported.name : app.profile.name;
      }
      await app.replaceProfile(imported);
      await app.finishOnboarding();
    }

    if (choice == 'merge') {
      await library.mergeFromBackup(
        saved: data.saved,
        mealPlan: data.mealPlan,
        history: data.history,
        contentRequests: data.contentRequests,
      );
    } else {
      await library.replaceAllFromBackup(
        saved: data.saved,
        mealPlan: data.mealPlan,
        history: data.history,
        contentRequests: data.contentRequests,
      );
    }
    _toast(s.get('importDone'));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: Type.mono(size: 11.5, color: Paper.white)),
        backgroundColor: Paper.ink,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperField(
          controller: _password,
          hint: '${s.get('backupPassword')} (${s.get('optional').toLowerCase()})',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            PaperButton(
              label: _busy ? '…' : s.get('exportBackup'),
              onTap: _busy ? null : _export,
            ),
            const SizedBox(width: 12),
            PaperButton(
              label: s.get('importBackup'),
              primary: false,
              onTap: _busy ? null : _import,
            ),
          ],
        ),
      ],
    );
  }
}
