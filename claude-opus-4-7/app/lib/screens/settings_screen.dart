import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../backup/backup_service.dart';
import '../backup/crypto.dart';
import '../data/corpus.dart';
import '../data/profile_store.dart';
import '../l10n/strings.dart';
import '../models/ingredient_dict.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/chip_tag.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/ink_button.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';
import 'faq_screen.dart';
import 'shopping_insights_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final corpus = context.watch<Corpus>();
    final store = context.watch<ProfileStore>();
    final p = store.profile;

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Masthead(
                title: 'settings',
                edition: l.t('settings.title'),
                leftMeta: p.name.isNotEmpty ? p.name : '—',
                rightMeta: p.lang.toUpperCase(),
              ),

              // Language
              _SectionTitle(label: l.t('settings.language')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChipTag(
                      label: l.t('settings.lang.en'),
                      selected: p.lang == 'en',
                      onTap: () => store.update((p) => p.copyWith(lang: 'en')),
                    ),
                    ChipTag(
                      label: l.t('settings.lang.de'),
                      selected: p.lang == 'de',
                      onTap: () => store.update((p) => p.copyWith(lang: 'de')),
                    ),
                  ],
                ),
              ),

              _SectionTitle(label: l.t('settings.profile')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextFormField(
                  initialValue: p.name,
                  decoration: InputDecoration(labelText: l.t('onb.name.hint')),
                  onChanged: (v) => store.update((p) => p.copyWith(name: v)),
                ),
              ),

              _SectionTitle(label: l.t('settings.dietary')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f
                            in corpus.ontology.compoundFlags.keys.toList()..sort())
                          ChipTag(
                            label: corpus.ontology.compoundFlagNames[f]
                                    ?.get(l.lang) ??
                                f,
                            selected: p.avoidFlags.contains(f),
                            onTap: () {
                              final next = Set<String>.from(p.avoidFlags);
                              if (next.contains(f)) {
                                next.remove(f);
                              } else {
                                next.add(f);
                              }
                              store.update((pp) => pp.copyWith(avoidFlags: next));
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _IngredientAvoid(
                      selected: p.avoidIngredients,
                      onChange: (next) => store
                          .update((pp) => pp.copyWith(avoidIngredients: next)),
                      lang: l.lang,
                    ),
                  ],
                ),
              ),

              _SectionTitle(label: l.t('settings.calorie_target')),
              _SliderRow(
                value: p.calorieTarget.toDouble(),
                min: 0,
                max: 1200,
                divisions: 24,
                suffix: p.calorieTarget == 0 ? '—' : '${p.calorieTarget} kcal',
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(calorieTarget: v.round())),
              ),
              SwitchListTile.adaptive(
                value: p.calorieHardFilter,
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(calorieHardFilter: v)),
                title: Text(l.t('settings.calorie_hard'),
                    style: MorphType.body(size: 15)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                activeColor: MorphColors.coral,
              ),
              _SliderRow(
                value: p.calorieTolerance.toDouble(),
                min: 50,
                max: 500,
                divisions: 9,
                suffix: '± ${p.calorieTolerance} kcal',
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(calorieTolerance: v.round())),
              ),

              _SectionTitle(label: l.t('settings.max_time')),
              _SliderRow(
                value: p.maxTimeMinutes.toDouble(),
                min: 0,
                max: 120,
                divisions: 12,
                suffix: p.maxTimeMinutes == 0 ? '—' : '≤ ${p.maxTimeMinutes} min',
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(maxTimeMinutes: v.round())),
              ),

              _SectionTitle(label: l.t('settings.effort')),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final e in const ['easy', 'medium', 'hard'])
                      ChipTag(
                        label: e,
                        selected: p.preferredEffort == e,
                        onTap: () => store
                            .update((pp) => pp.copyWith(preferredEffort: e)),
                      ),
                  ],
                ),
              ),

              _SectionTitle(label: l.t('settings.cook_mode')),
              SwitchListTile.adaptive(
                value: p.visualAlertEnabled,
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(visualAlertEnabled: v)),
                title: Text(l.t('settings.visual_alert'),
                    style: MorphType.body(size: 15)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                activeColor: MorphColors.coral,
              ),
              SwitchListTile.adaptive(
                value: p.quickNextTapEnabled,
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(quickNextTapEnabled: v)),
                title: Text(l.t('settings.quick_tap'),
                    style: MorphType.body(size: 15)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                activeColor: MorphColors.coral,
              ),

              _SectionTitle(label: l.t('settings.access')),
              SwitchListTile.adaptive(
                value: p.reduceMotion ?? false,
                onChanged: (v) => store.update(
                    (pp) => pp.copyWith(reduceMotion: v)),
                title: Text(l.t('settings.reduce_motion'),
                    style: MorphType.body(size: 15)),
                subtitle: p.reduceMotion == null
                    ? Text('uses system setting',
                        style: MorphType.smallCaps(size: 9))
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                activeColor: MorphColors.coral,
              ),
              SwitchListTile.adaptive(
                value: p.showVariantTags,
                onChanged: (v) =>
                    store.update((pp) => pp.copyWith(showVariantTags: v)),
                title: Text(l.t('settings.show_tags'),
                    style: MorphType.body(size: 15)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20),
                activeColor: MorphColors.coral,
              ),

              _SectionTitle(label: l.t('settings.backup')),
              const _BackupBlock(),

              _SectionTitle(label: '—'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    InkButton(
                      label: l.t('settings.insights'),
                      icon: Icons.insights,
                      primary: false,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShoppingInsightsScreen(),
                        ),
                      ),
                    ),
                    InkButton(
                      label: l.t('settings.faq'),
                      icon: Icons.help_outline,
                      primary: false,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const FaqScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: MorphType.smallCaps()),
          const SizedBox(height: 4),
          const DashedRule(),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final double value;
  final double min, max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;
  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: MorphColors.ink,
              inactiveColor: MorphColors.inkFaint,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(suffix,
                textAlign: TextAlign.end,
                style: MorphType.mono(size: 12)),
          ),
        ],
      ),
    );
  }
}

class _IngredientAvoid extends StatefulWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChange;
  final String lang;
  const _IngredientAvoid({
    required this.selected,
    required this.onChange,
    required this.lang,
  });

  @override
  State<_IngredientAvoid> createState() => _IngredientAvoidState();
}

class _IngredientAvoidState extends State<_IngredientAvoid> {
  final _ctrl = TextEditingController();
  List<IngredientNode> _matches = const [];

  @override
  Widget build(BuildContext context) {
    final dict = context.read<Corpus>().ingredientDict;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          cursorColor: MorphColors.ink,
          onChanged: (s) {
            setState(() => _matches = dict.typeahead(s, widget.lang));
          },
          decoration: const InputDecoration(
            hintText: 'apples, cilantro, bell pepper…',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        if (_matches.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in _matches.take(20))
                ChipTag(
                  label: n.name.get(widget.lang),
                  selected: widget.selected.contains(n.id),
                  icon: Icons.add,
                  onTap: () {
                    final next = Set<String>.from(widget.selected);
                    next.add(n.id);
                    widget.onChange(next);
                    setState(() {
                      _ctrl.clear();
                      _matches = const [];
                    });
                  },
                ),
            ],
          ),
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in widget.selected)
                ChipTag(
                  label: dict.nodes[id]?.name.get(widget.lang) ?? id,
                  selected: true,
                  icon: Icons.close,
                  onTap: () {
                    final next = Set<String>.from(widget.selected);
                    next.remove(id);
                    widget.onChange(next);
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BackupBlock extends StatefulWidget {
  const _BackupBlock();
  @override
  State<_BackupBlock> createState() => _BackupBlockState();
}

class _BackupBlockState extends State<_BackupBlock> {
  String _password = '';
  bool _busy = false;
  String? _info;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            obscureText: true,
            decoration: InputDecoration(
              labelText: l.t('settings.backup.password'),
              helperText: l.t('settings.backup.hint'),
              helperMaxLines: 2,
            ),
            onChanged: (v) => _password = v,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              InkButton(
                label: l.t('settings.backup.export'),
                icon: Icons.upload_file,
                onPressed: _busy ? null : _doExport,
              ),
              InkButton(
                label: l.t('settings.backup.import'),
                icon: Icons.download,
                primary: false,
                onPressed: _busy ? null : _doImport,
              ),
            ],
          ),
          if (_info != null) ...[
            const SizedBox(height: 8),
            Text(_info!,
                style: MorphType.smallCaps(
                    size: 10, color: MorphColors.inkSoft)),
          ],
        ],
      ),
    );
  }

  Future<void> _doExport() async {
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final svc = context.read<BackupService>();
      final bundle = await svc.export(password: _password);
      await svc.shareBundle(bundle);
      setState(() {
        _info = bundle.encrypted
            ? 'Exported encrypted backup + GZip companion.'
            : 'Exported backup (json + gz).';
      });
    } catch (e) {
      setState(() => _info = 'Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doImport() async {
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (res == null || res.files.isEmpty) {
        setState(() => _busy = false);
        return;
      }
      final pf = res.files.single;
      final bytes = pf.bytes ?? await File(pf.path!).readAsBytes();
      final svc = context.read<BackupService>();
      final out = await svc.importFromBytes(bytes, password: _password);
      setState(() => _info =
          '+${out.savedAdded} saved, ${out.historyAdded} history, ${out.weeksMerged} weeks');
    } on DecryptionException catch (e) {
      setState(() => _info = e.message);
    } catch (e) {
      setState(() => _info = 'Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
