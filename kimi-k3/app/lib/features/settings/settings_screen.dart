import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../core/corpus_repository.dart';
import '../../core/l10n.dart';
import '../../core/models/ingredient_node.dart';
import '../../core/models/local_text.dart';
import '../../core/models/profile.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/dashed_rule.dart';
import '../../shared/widgets/paper_grain.dart';
import 'backup_section.dart';

/// Full profile editor. Every change is saved immediately via
/// `profileStore.save(profile.copyWith(...))`.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Positive attributes a recipe must satisfy (subset of compound flags).
  static const _attributeIds = ['halal', 'kosher'];

  final _nameController = TextEditingController();

  /// In-flight slider values; committed to the profile on drag end.
  double? _timeOverride;
  double? _calorieOverride;

  @override
  void initState() {
    super.initState();
    _nameController.text = context.read<ProfileStore>().profile.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save(UserProfile profile) => context.read<ProfileStore>().save(profile);

  void _toggleFlag(UserProfile profile, String id, bool selected) {
    final flags = {...profile.avoidFlags};
    if (selected) {
      flags.add(id);
    } else {
      flags.remove(id);
    }
    _save(profile.copyWith(avoidFlags: flags));
  }

  void _toggleAttribute(UserProfile profile, String id, bool selected) {
    final attrs = {...profile.requiredAttributes};
    if (selected) {
      attrs.add(id);
    } else {
      attrs.remove(id);
    }
    _save(profile.copyWith(requiredAttributes: attrs));
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final profile = context.watch<ProfileStore>().profile;
    final corpus = context.read<CorpusRepository>();
    final lang = profile.lang;
    final reduce =
        profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);

    Widget body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        // ---- you ------------------------------------------------------
        SectionRule(label: s.t('settings.section.you')),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          cursorColor: AppColors.coral,
          style: AppText.body(size: 16),
          decoration: InputDecoration(
            labelText: s.t('settings.name.label'),
            labelStyle: AppText.monoLabel(),
            hintText: s.t('settings.name.hint'),
            hintStyle: AppText.body(size: 15, color: AppColors.inkSoft),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.coral),
            ),
          ),
          onChanged: (v) => _save(profile.copyWith(name: v)),
        ),
        const SizedBox(height: 16),
        Text(s.t('settings.language.label'), style: AppText.monoLabel()),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'en',
              label: Text(s.t('settings.language.en')),
            ),
            ButtonSegment(
              value: 'de',
              label: Text(s.t('settings.language.de')),
            ),
          ],
          selected: {profile.lang},
          onSelectionChanged: (sel) => _save(profile.copyWith(lang: sel.first)),
        ),

        // ---- avoid ------------------------------------------------------
        const SizedBox(height: 24),
        SectionRule(label: s.t('settings.section.avoid')),
        const SizedBox(height: 12),
        Text(s.t('settings.avoid.diets'), style: AppText.monoLabel(size: 10)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final flag in corpus.ontology.compoundFlags.values)
              FilterChip(
                label: Text(localize(flag.label, lang)),
                selected: profile.avoidFlags.contains(flag.id),
                showCheckmark: true,
                onSelected: (sel) => _toggleFlag(profile, flag.id, sel),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(s.t('settings.avoid.classes'), style: AppText.monoLabel(size: 10)),
        const SizedBox(height: 6),
        Opacity(
          opacity: 0.8,
          child: Wrap(
            spacing: 6,
            runSpacing: 0,
            children: [
              for (final flag in corpus.ontology.containsFlags.values)
                FilterChip(
                  label: Text(
                    localize(flag.label, lang),
                    style: AppText.monoLabel(size: 10),
                  ),
                  selected: profile.avoidFlags.contains(flag.id),
                  showCheckmark: true,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (sel) => _toggleFlag(profile, flag.id, sel),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          s.t('settings.avoid.specific'),
          style: AppText.monoLabel(size: 10),
        ),
        const SizedBox(height: 6),
        _IngredientAvoidEditor(
          profile: profile,
          onChanged: (ids) => _save(profile.copyWith(avoidIngredients: ids)),
        ),

        // ---- requirements ------------------------------------------------
        const SizedBox(height: 24),
        SectionRule(label: s.t('settings.section.requirements')),
        const SizedBox(height: 4),
        for (final id in _attributeIds)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              localize(corpus.ontology.flagLabel(id), lang),
              style: AppText.body(size: 15),
            ),
            subtitle: Text(
              s.t('settings.requirements.hint'),
              style: AppText.monoLabel(size: 10),
            ),
            value: profile.requiredAttributes.contains(id),
            activeTrackColor: AppColors.tealSoft,
            activeThumbColor: AppColors.teal,
            onChanged: (sel) => _toggleAttribute(profile, id, sel),
          ),
        const SizedBox(height: 4),
        Text(s.t('settings.halal.note'), style: AppText.handwritten(size: 17)),

        // ---- cooking -----------------------------------------------------
        const SizedBox(height: 24),
        SectionRule(label: s.t('settings.section.cooking')),
        const SizedBox(height: 12),
        Text(s.t('settings.effort.label'), style: AppText.monoLabel(size: 10)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final level in corpus.ontology.effortLevels)
              ButtonSegment(
                value: level.id,
                label: Text(localize(level.label, lang)),
              ),
          ],
          selected: {profile.preferredEffort},
          onSelectionChanged: (sel) =>
              _save(profile.copyWith(preferredEffort: sel.first)),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.t('settings.time.label'),
              style: AppText.monoLabel(size: 10),
            ),
            Text(
              '${(_timeOverride ?? profile.maxTimeMinutes).round()} ${s.t('common.minutes')}',
              style: AppText.monoLabel(size: 11, color: AppColors.ink),
            ),
          ],
        ),
        Slider(
          value: (_timeOverride ?? profile.maxTimeMinutes).toDouble().clamp(
            15,
            120,
          ),
          min: 15,
          max: 120,
          divisions: 21,
          activeColor: AppColors.coral,
          inactiveColor: AppColors.coralSoft,
          onChanged: (v) => setState(() => _timeOverride = v),
          onChangeEnd: (v) {
            _save(profile.copyWith(maxTimeMinutes: v.round()));
            setState(() => _timeOverride = null);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.t('settings.calories.label'),
              style: AppText.monoLabel(size: 10),
            ),
            Text(
              '${(_calorieOverride ?? profile.calorieTarget).round()} ${s.t('common.kcal')}',
              style: AppText.monoLabel(size: 11, color: AppColors.ink),
            ),
          ],
        ),
        Slider(
          value: (_calorieOverride ?? profile.calorieTarget).toDouble().clamp(
            300,
            1000,
          ),
          min: 300,
          max: 1000,
          divisions: 14,
          activeColor: AppColors.coral,
          inactiveColor: AppColors.coralSoft,
          onChanged: (v) => setState(() => _calorieOverride = v),
          onChangeEnd: (v) {
            _save(profile.copyWith(calorieTarget: v.round()));
            setState(() => _calorieOverride = null);
          },
        ),

        // ---- interface -----------------------------------------------------
        const SizedBox(height: 24),
        SectionRule(label: s.t('settings.section.interface')),
        const SizedBox(height: 4),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            s.t('settings.ui.variantTags'),
            style: AppText.body(size: 15),
          ),
          subtitle: Text(
            s.t('settings.ui.variantTags.sub'),
            style: AppText.monoLabel(size: 10),
          ),
          value: profile.showVariantTags,
          activeTrackColor: AppColors.tealSoft,
          activeThumbColor: AppColors.teal,
          onChanged: (v) => _save(profile.copyWith(showVariantTags: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            s.t('settings.ui.visualAlert'),
            style: AppText.body(size: 15),
          ),
          subtitle: Text(
            s.t('settings.ui.visualAlert.sub'),
            style: AppText.monoLabel(size: 10),
          ),
          value: profile.visualAlertEnabled,
          activeTrackColor: AppColors.tealSoft,
          activeThumbColor: AppColors.teal,
          onChanged: (v) => _save(profile.copyWith(visualAlertEnabled: v)),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            s.t('settings.ui.quickNext'),
            style: AppText.body(size: 15),
          ),
          subtitle: Text(
            s.t('settings.ui.quickNext.sub'),
            style: AppText.monoLabel(size: 10),
          ),
          value: profile.quickNextTapEnabled,
          activeTrackColor: AppColors.tealSoft,
          activeThumbColor: AppColors.teal,
          onChanged: (v) => _save(profile.copyWith(quickNextTapEnabled: v)),
        ),
        const SizedBox(height: 8),
        Text(
          s.t('settings.ui.reduceMotion'),
          style: AppText.monoLabel(size: 10),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 'system',
              label: Text(s.t('settings.motion.system')),
            ),
            ButtonSegment(value: 'on', label: Text(s.t('settings.motion.on'))),
            ButtonSegment(
              value: 'off',
              label: Text(s.t('settings.motion.off')),
            ),
          ],
          selected: {
            profile.reduceMotion == null
                ? 'system'
                : (profile.reduceMotion! ? 'on' : 'off'),
          },
          onSelectionChanged: (sel) => _save(
            profile.copyWith(
              reduceMotion: () => switch (sel.first) {
                'on' => true,
                'off' => false,
                _ => null,
              },
            ),
          ),
        ),

        // ---- more -----------------------------------------------------------
        const SizedBox(height: 24),
        SectionRule(label: s.t('settings.section.more')),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(s.t('settings.insights'), style: AppText.body(size: 15)),
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.inkSoft,
          ),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.insights),
        ),
        const DashedRule(),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(s.t('settings.faq'), style: AppText.body(size: 15)),
          trailing: const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppColors.inkSoft,
          ),
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.faq),
        ),

        // ---- backup & restore -------------------------------------------------
        const SizedBox(height: 24),
        const BackupSection(),
      ],
    );
    if (!reduce) {
      body = body.animate().fadeIn(duration: 250.ms);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('settings.title'), style: AppText.headline()),
      ),
      body: Stack(
        children: [
          body,
          const Positioned.fill(child: PaperGrain()),
        ],
      ),
    );
  }
}

/// Typeahead picker for specific avoided ingredients: search the ingredient
/// dictionary, tap to add a chip, tap the chip's × to remove.
class _IngredientAvoidEditor extends StatefulWidget {
  final UserProfile profile;
  final ValueChanged<Set<String>> onChanged;

  const _IngredientAvoidEditor({
    required this.profile,
    required this.onChanged,
  });

  @override
  State<_IngredientAvoidEditor> createState() => _IngredientAvoidEditorState();
}

class _IngredientAvoidEditorState extends State<_IngredientAvoidEditor> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(String id) {
    widget.onChanged({...widget.profile.avoidIngredients, id});
    _controller.clear();
    setState(() => _query = '');
  }

  void _remove(String id) {
    final ids = {...widget.profile.avoidIngredients}..remove(id);
    widget.onChanged(ids);
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final corpus = context.read<CorpusRepository>();
    final lang = context.watch<ProfileStore>().profile.lang;

    final List<IngredientNode> results = _query.trim().isEmpty
        ? const []
        : corpus.ingredientDictionary
              .search(_query, lang)
              .where((n) => !widget.profile.avoidIngredients.contains(n.id))
              .take(6)
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          cursorColor: AppColors.coral,
          style: AppText.body(size: 15),
          decoration: InputDecoration(
            hintText: s.t('settings.avoid.searchHint'),
            hintStyle: AppText.body(size: 14, color: AppColors.inkSoft),
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
              color: AppColors.inkSoft,
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.coral),
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        if (_query.trim().isNotEmpty && results.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              s.t('settings.avoid.noMatches'),
              style: AppText.handwritten(size: 16),
            ),
          ),
        if (results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: AppColors.polaroid,
              border: Border.all(color: AppColors.inkSoft, width: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final node in results)
                  InkWell(
                    onTap: () => _add(node.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              localize(node.name, lang),
                              style: AppText.body(size: 14),
                            ),
                          ),
                          const Icon(
                            Icons.add,
                            size: 16,
                            color: AppColors.inkSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (widget.profile.avoidIngredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final id in widget.profile.avoidIngredients)
                  InputChip(
                    label: Text(
                      localize(
                        corpus.ingredientDictionary.byId(id)?.name,
                        lang,
                      ).ifEmpty(id),
                      style: AppText.monoLabel(size: 10),
                    ),
                    onDeleted: () => _remove(id),
                    deleteIconColor: AppColors.inkSoft,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
