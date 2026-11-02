import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/fields.dart';
import '../../design/widgets/paper.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../domain/backup.dart';
import '../../domain/encryption.dart';
import '../../l10n/strings.dart';
import '../../models/ontology.dart';
import '../../state/app_state.dart';
import '../../state/profile_controller.dart';
import '../faq/faq_screen.dart';
import '../shopping/insights_screen.dart';

/// Settings — the full profile editor plus everything else.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<ProfileController>().profile.name,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final profile = state.profile.profile;
    final ontology = state.corpus.ontology;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          strings.settingsTitle,
                          style: Type.display(size: 30),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                        color: MC.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: const DashedRule(),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // ── Profile ──────────────────────────────────────────
                      SectionHeading(title: strings.settingsProfile),
                      const SizedBox(height: 12),
                      PaperField(
                        controller: _nameController,
                        label: strings.onboardStepName,
                        hint: strings.onboardNamePlaceholder,
                        onChanged: (value) =>
                            context.read<ProfileController>().setName(value),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        strings.settingsLanguage.toUpperCase(),
                        style: Type.label(size: 9.5),
                      ),
                      const SizedBox(height: 8),
                      SegmentedChoice<String>(
                        value: profile.lang,
                        options: const <({String value, String label})>[
                          (value: 'en', label: 'English'),
                          (value: 'de', label: 'Deutsch'),
                        ],
                        onChanged: (value) =>
                            context.read<ProfileController>().setLanguage(value),
                      ),
                      const SizedBox(height: 22),

                      // ── Diet ─────────────────────────────────────────────
                      SectionHeading(title: strings.settingsDiet),
                      const SizedBox(height: 6),
                      Text(
                        strings.onboardingDietNote,
                        style: Type.small(size: 13),
                      ),
                      const SizedBox(height: 14),
                      _FlagGroup(
                        title: strings.settingsAvoidFlags,
                        flags: ontology.avoid.values.toList(),
                        selected: profile.avoidFlags,
                        strings: strings,
                        onToggle: (id) =>
                            context.read<ProfileController>().toggleAvoidFlag(id),
                      ),
                      const SizedBox(height: 16),
                      _IngredientAvoidance(),
                      const SizedBox(height: 16),
                      _RequiredAttributes(ontology: ontology),
                      const SizedBox(height: 14),
                      PaperNote(
                        text: strings.settingsHalalNote,
                        accent: MC.inkBlue,
                        icon: Icons.info_outline_rounded,
                      ),
                      const SizedBox(height: 24),

                      // ── Targets ──────────────────────────────────────────
                      SectionHeading(title: strings.settingsTargets),
                      const SizedBox(height: 12),
                      _SliderRow(
                        label: strings.settingsCalorieTarget,
                        value: profile.calorieTarget.toDouble(),
                        min: 200,
                        max: 1200,
                        divisions: 50,
                        suffix: 'kcal',
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setCalorieTarget(value.round()),
                      ),
                      _SliderRow(
                        label: strings.settingsCalorieTolerance,
                        value: profile.calorieTolerance.toDouble(),
                        min: 0,
                        max: 400,
                        divisions: 20,
                        suffix: 'kcal',
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setCalorieTolerance(value.round()),
                      ),
                      _SliderRow(
                        label: strings.settingsTimeBudget,
                        value: profile.maxTimeMinutes.toDouble(),
                        min: 10,
                        max: 180,
                        divisions: 34,
                        suffix: 'min',
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setMaxTimeMinutes(value.round()),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        strings.settingsEffort.toUpperCase(),
                        style: Type.label(size: 9.5),
                      ),
                      const SizedBox(height: 8),
                      SegmentedChoice<String>(
                        value: profile.preferredEffort,
                        options: <({String value, String label})>[
                          (
                            value: 'easy',
                            label: strings.effortLabel('easy'),
                          ),
                          (
                            value: 'medium',
                            label: strings.effortLabel('medium'),
                          ),
                          (
                            value: 'hard',
                            label: strings.effortLabel('hard'),
                          ),
                        ],
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setPreferredEffort(value),
                      ),
                      const SizedBox(height: 24),

                      // ── Appearance ───────────────────────────────────────
                      SectionHeading(title: strings.settingsAppearance),
                      const SizedBox(height: 6),
                      ToggleRow(
                        title: strings.settingsShowVariantTags,
                        value: profile.showVariantTags,
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setShowVariantTags(value),
                      ),
                      ToggleRow(
                        title: strings.settingsReduceMotion,
                        description: strings.settingsReduceMotionSystem,
                        value: profile.reduceMotion ?? false,
                        accent: MC.plum,
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setReduceMotion(value),
                      ),
                      ToggleRow(
                        title: strings.settingsReduceMotionSystem,
                        description: strings.settingsReduceMotionSystem,
                        value: profile.reduceMotion == null,
                        accent: MC.plum,
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setReduceMotion(value ? null : false),
                      ),
                      ToggleRow(
                        title: strings.settingsVisualAlerts,
                        value: profile.visualAlertEnabled,
                        accent: MC.coral,
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setVisualAlertEnabled(value),
                      ),
                      ToggleRow(
                        title: strings.settingsQuickTap,
                        description: strings.settingsQuickTapBody,
                        value: profile.quickNextTapEnabled,
                        accent: MC.teal,
                        onChanged: (value) => context
                            .read<ProfileController>()
                            .setQuickNextTapEnabled(value),
                      ),
                      const SizedBox(height: 24),

                      // ── Data ─────────────────────────────────────────────
                      SectionHeading(title: strings.settingsData),
                      const SizedBox(height: 12),
                      _BackupCard(
                        passwordController: _passwordController,
                        strings: strings,
                      ),
                      const SizedBox(height: 10),
                      GhostButton(
                        label: strings.settingsInsights,
                        icon: Icons.insights_outlined,
                        expand: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const InsightsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: strings.settingsHelp,
                        icon: Icons.help_outline_rounded,
                        expand: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const FaqScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        strings.settingsOfflineNote,
                        style: Type.scriptSmall(size: 15),
                      ),
                      const SizedBox(height: 10),
                      TextAction(
                        label: strings.settingsResetProfile,
                        color: MC.danger,
                        onPressed: () => _confirmReset(context),
                      ),
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

  Future<void> _confirmReset(BuildContext context) async {
    final strings = context.read<AppState>().strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.settingsResetProfile),
        content: Text(strings.settingsResetConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.genericCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.genericDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ProfileController>().resetProfile();
    }
  }
}

/// A group of class-level avoid toggles.
class _FlagGroup extends StatelessWidget {
  const _FlagGroup({
    required this.title,
    required this.flags,
    required this.selected,
    required this.strings,
    required this.onToggle,
  });

  final String title;
  final List<FlagDefinition> flags;
  final Set<String> selected;
  final Strings strings;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title.toUpperCase(), style: Type.label(size: 9.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final flag in flags)
              _TogglePill(
                label: flag.label.resolve(strings.lang),
                selected: selected.contains(flag.id),
                description: flag.description?.resolve(strings.lang),
                onTap: () => onToggle(flag.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: description ?? '',
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? MC.coral : MC.card,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: selected ? MC.coral : MC.ruleFaint),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (selected) ...<Widget>[
                const Icon(Icons.check_rounded, size: 13, color: MC.card),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Type.label(
                  size: 10,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? MC.card : MC.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The specific-avoidance typeahead, backed by the ingredient tree.
class _IngredientAvoidance extends StatefulWidget {
  @override
  State<_IngredientAvoidance> createState() => _IngredientAvoidanceState();
}

class _IngredientAvoidanceState extends State<_IngredientAvoidance> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = <dynamic>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final profile = state.profile.profile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.settingsAvoidIngredients.toUpperCase(),
          style: Type.label(size: 9.5),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          onChanged: _search,
          style: Type.body(size: 14.5, color: MC.ink),
          cursorColor: MC.coral,
          decoration: InputDecoration(
            hintText: strings.onboardSearchIngredient,
            hintStyle: Type.body(size: 14, color: MC.inkGhost),
            filled: true,
            fillColor: MC.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: MC.ruleFaint),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: MC.ruleFaint),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: MC.coral),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: MC.card,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: MC.ruleFaint),
            ),
            constraints: const BoxConstraints(maxHeight: 210),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final node = _results[index];
                final label = node.label.resolve(strings.lang);
                final already = profile.avoidIngredients.contains(node.id);
                return ListTile(
                  dense: true,
                  title: Text(
                    label,
                    style: Type.body(size: 14, color: MC.ink),
                  ),
                  subtitle: node.parentId == null
                      ? null
                      : Text(
                          node.parentId!.split('.').last.replaceAll('-', ' '),
                          style: Type.label(size: 8.5),
                        ),
                  trailing: already
                      ? const Icon(Icons.check_rounded, size: 16, color: MC.coral)
                      : const Icon(Icons.add_rounded, size: 16, color: MC.inkGhost),
                  onTap: () {
                    final controller = context.read<ProfileController>();
                    if (already) {
                      controller.removeAvoidIngredient(node.id);
                    } else {
                      controller.addAvoidIngredient(node.id);
                    }
                    setState(() => _search(_controller.text));
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 10),
        if (profile.avoidIngredients.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final id in profile.avoidIngredients)
                _TogglePill(
                  label: state.corpus.ingredients.node(id)?.label.resolve(
                            strings.lang,
                          ) ??
                      id,
                  selected: true,
                  onTap: () => context
                      .read<ProfileController>()
                      .removeAvoidIngredient(id),
                ),
            ],
          ),
      ],
    );
  }

  void _search(String value) {
    final state = context.read<AppState>();
    final results = value.trim().isEmpty
        ? <dynamic>[]
        : state.corpus.ingredients.search(value, lang: state.lang);
    setState(() => _results = results.take(12).toList());
  }
}

/// Positive requirements such as `halal`.
class _RequiredAttributes extends StatelessWidget {
  const _RequiredAttributes({required this.ontology});

  final Ontology ontology;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final profile = state.profile.profile;

    final options = <FlagDefinition>[
      for (final id in ontology.compoundCertifications)
        if (ontology.avoid[id] != null) ontology.avoid[id]!,
    ];
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          strings.settingsRequired.toUpperCase(),
          style: Type.label(size: 9.5),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final option in options)
              _TogglePill(
                label: option.label.resolve(strings.lang),
                selected: profile.requiredAttributes.contains(option.id),
                description: option.description?.resolve(strings.lang),
                onTap: () => context
                    .read<ProfileController>()
                    .toggleRequiredAttribute(option.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// A labelled slider.
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(label, style: Type.body(size: 14.5, color: MC.ink)),
              const Spacer(),
              Text(
                '${value.round()} $suffix',
                style: Type.mono(size: 12.5, color: MC.inkSoft),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MC.coral,
              inactiveTrackColor: MC.ruleFaint,
              thumbColor: MC.coral,
              overlayColor: MC.coral.withValues(alpha: 0.12),
              trackHeight: 2,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// Export and restore.
class _BackupCard extends StatelessWidget {
  const _BackupCard({
    required this.passwordController,
    required this.strings,
  });

  final TextEditingController passwordController;
  final Strings strings;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MC.card,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: MC.ruleFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.backupExportBody, style: Type.small(size: 13)),
          const SizedBox(height: 14),
          TextField(
            controller: passwordController,
            obscureText: true,
            style: Type.body(size: 14.5, color: MC.ink),
            cursorColor: MC.coral,
            decoration: InputDecoration(
              labelText: strings.backupPassword,
              hintText: strings.backupPasswordHint,
              labelStyle: Type.label(size: 9.5),
              hintStyle: Type.small(size: 12.5, color: MC.inkGhost),
              filled: true,
              fillColor: MC.cardAlt,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: MC.ruleFaint),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: MC.ruleFaint),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: PaperButton(
                  label: strings.backupExportAction,
                  icon: Icons.ios_share_rounded,
                  onPressed: () => _export(context),
                ),
              ),
              const SizedBox(width: 8),
              GhostButton(
                label: strings.backupImportAction,
                icon: Icons.file_open_outlined,
                onPressed: () => _import(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final password = passwordController.text.trim();

    final document = BackupDocument(
      schemaVersion: BackupDocument.currentSchemaVersion,
      exportedAt: DateTime.now(),
      profile: state.profile.profile,
      saved: state.cookbook.entries.map((entry) => entry.recipeId).toList(),
      mealPlan: state.mealPlan.plan,
      history: state.history.entries,
      contentRequests: state.history.contentRequests
          .map((request) => request.query)
          .toSet()
          .toList(),
    );

    try {
      final files = await const BackupService().writeFiles(
        document,
        password: password.isEmpty ? null : password,
      );
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[
            XFile(files.jsonPath, mimeType: 'application/json'),
            XFile(files.gzipPath, mimeType: 'application/gzip'),
          ],
          subject: 'MorphCook backup',
        ),
      );
      messenger.showSnackBar(
        SnackBar(content: Text(state.strings.backupExported)),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('${state.strings.genericError}: $error')),
      );
    }
  }

  Future<void> _import(BuildContext context) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = await _readBytes(result);
    if (!context.mounted) return;
    if (bytes == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(state.strings.genericError)),
      );
      return;
    }

    final format = BackupCodec.detect(bytes);

    if (format == BackupFormat.encrypted) {
      final password = await _askPassword(context);
      if (!context.mounted) return;
      if (password == null) return;
      try {
        final document = await BackupCodec.decodeEncrypted(bytes, password);
        if (!context.mounted) return;
        await _applyDocument(context, document);
      } on DecryptionException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    try {
      final document = await BackupCodec.decodeAuto(bytes);
      if (!context.mounted) return;
      await _applyDocument(context, document);
    } on BackupFormatException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<Uint8List?> _readBytes(FilePickerResult result) async {
    final file = result.files.first;
    if (file.bytes != null) return file.bytes;
    if (file.path != null) {
      return const BackupService().readBytes(file.path!);
    }
    return null;
  }

  Future<String?> _askPassword(BuildContext context) async {
    final controller = TextEditingController();
    final strings = context.read<AppState>().strings;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.backupPassword),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: strings.backupPasswordHint,
            hintStyle: Type.small(size: 12.5),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(strings.genericCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(strings.genericSave),
          ),
        ],
      ),
    );
    controller.dispose();
    return password;
  }

  Future<void> _applyDocument(
    BuildContext context,
    BackupDocument document,
  ) async {
    final state = context.read<AppState>();
    final strings = state.strings;
    final messenger = ScaffoldMessenger.of(context);

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.settingsImport),
        content: Text(
          '${document.saved.length} ${strings.cookbookCount} · '
          '${document.history.length} ${strings.genericCookedOn}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop('merge'),
            child: Text(strings.backupMerge),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('replace'),
            child: Text(strings.backupReplace),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    final profile = state.profile;
    if (choice == 'replace') {
      profile.resetProfile();
    }
    profile.updateFromBackup(document.profile);

    for (final recipeId in document.saved) {
      state.cookbook.save(recipeId);
    }
    state.mealPlan.replaceAll(document.mealPlan);
    for (final entry in document.history) {
      state.history.record(
        entry.recipeId,
        servings: entry.servings,
        durationSeconds: entry.durationSeconds,
      );
    }

    messenger.showSnackBar(
      SnackBar(content: Text(strings.backupImported)),
    );
  }
}
