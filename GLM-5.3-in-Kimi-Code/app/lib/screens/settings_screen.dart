/// Settings: full profile editor, language, adaptation prefs, accessibility,
/// backup & restore (with password option), insights, FAQ, about.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../logic/backup.dart' as backup;
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'faq_screen.dart';
import 'insights_screen.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _passwordController = TextEditingController();
  bool _busy = false;

  static const _dietKeys = [
    'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher',
    'low-fodmap', 'sugar-free', 'lactose-free',
  ];
  static const _classKeys = [
    'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
    'egg', 'dairy', 'gluten', 'soy', 'peanuts', 'tree-nuts', 'sesame',
    'mustard', 'celery', 'lupin', 'sulphites', 'alcohol', 'caffeine',
    'added-sugar', 'high-fodmap', 'honey',
  ];

  @override
  void initState() {
    super.initState();
    // the export button label depends on whether a password is typed
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final p = app.profile;
    final onto = app.ontology;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t(lang, 'stTitle'),
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 22)),
      ),
      body: PaperGrain(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _SectionHeader(label: L.t(lang, 'stProfile')),
            ListTile(
              dense: true,
              title: Text(L.t(lang, 'stName')),
              subtitle: Text(p.name.isEmpty ? '—' : p.name),
              onTap: () => _editName(context, app),
            ),
            ListTile(
              dense: true,
              title: Text(L.t(lang, 'stLanguage')),
              subtitle: Text(p.lang == Lang.de ? 'deutsch' : 'english'),
              onTap: () => app.setLang(p.lang == Lang.de ? Lang.en : Lang.de),
            ),

            _SectionHeader(label: L.t(lang, 'stDiets')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(L.t(lang, 'stDietsBody'),
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in _dietKeys)
                StampChip(
                  label: onto.compoundFlags[k]!.label.get(lang),
                  color: AppTheme.teal,
                  selected: p.avoidFlags.contains(k),
                  onTap: () => _toggle(app, k),
                ),
            ]),
            const SizedBox(height: 6),
            // halal/kosher certification note (spec requirement)
            Container(
              padding: const EdgeInsets.all(12),
              decoration:
                  BoxDecoration(border: Border.all(color: AppTheme.mustard)),
              child: Text(
                L.t(lang, 'stHalalNote'),
                style: const TextStyle(
                    fontFamily: AppTheme.mono, fontSize: 9.5, height: 1.6, color: AppTheme.inkSoft),
              ),
            ),
            const SizedBox(height: 14),
            RuleLabel(label: L.t(lang, 'stAvoidClasses')),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in _classKeys)
                StampChip(
                  label: onto.flagLabel(k).get(lang),
                  color: AppTheme.coral,
                  selected: p.avoidFlags.contains(k),
                  onTap: () => _toggle(app, k),
                ),
            ]),
            const SizedBox(height: 14),
            RuleLabel(label: L.t(lang, 'stAvoidSpecific')),
            const SizedBox(height: 8),
            Text(L.t(lang, 'stAvoidSpecificHint'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            _SpecificAvoidEditor(app: app, lang: lang),

            _SectionHeader(label: L.t(lang, 'stAdaptation')),
            _SliderRow(
              label: '${L.t(lang, 'stCalorie')} — ${L.t(lang, 'kcal')}',
              value: p.calorieTarget?.toDouble(),
              min: 300,
              max: 1000,
              division: 14,
              format: (v) => v == null ? L.t(lang, 'stCalorieOff') : '~${v.round()}',
              allowOff: true,
              onChanged: (v) => app.updateProfile(
                  v == null ? p.copyWith(clearCalorieTarget: true) : p.copyWith(calorieTarget: v.round())),
            ),
            _SliderRow(
              label: L.t(lang, 'stTimeBudget'),
              value: p.maxTimeMinutes?.toDouble(),
              min: 15,
              max: 180,
              division: 11,
              format: (v) => v == null ? '—' : '≤ ${v.round()}',
              allowOff: true,
              onChanged: (v) => app.updateProfile(
                  v == null ? p.copyWith(clearMaxTime: true) : p.copyWith(maxTimeMinutes: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(L.t(lang, 'stEffort'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in const ['easy', 'medium', 'hard'])
                StampChip(
                  label: e,
                  color: AppTheme.teal,
                  selected: p.preferredEffort == e,
                  onTap: () => app.updateProfile(p.copyWith(preferredEffort: e)),
                ),
            ]),
            SwitchListTile(
              dense: true,
              value: p.showVariantTags,
              onChanged: (v) =>
                  app.updateProfile(p.copyWith(showVariantTags: v)),
              title: Text(L.t(lang, 'stShowVariantTags')),
            ),

            _SectionHeader(label: L.t(lang, 'stAccessibility')),
            SwitchListTile(
              dense: true,
              value: p.reduceMotion ?? false,
              onChanged: (v) => app.updateProfile(p.copyWith(reduceMotion: v)),
              title: Text(L.t(lang, 'stReduceMotion')),
              subtitle: p.reduceMotion == null
                  ? Text(L.t(lang, 'no'))
                  : null,
            ),
            SwitchListTile(
              dense: true,
              value: p.visualAlertEnabled,
              onChanged: (v) =>
                  app.updateProfile(p.copyWith(visualAlertEnabled: v)),
              title: Text(L.t(lang, 'stVisualAlerts')),
            ),
            SwitchListTile(
              dense: true,
              value: p.quickNextTapEnabled,
              onChanged: (v) =>
                  app.updateProfile(p.copyWith(quickNextTapEnabled: v)),
              title: Text(L.t(lang, 'stQuickTap')),
              subtitle: Text(L.t(lang, 'stQuickTapHint')),
            ),

            _SectionHeader(label: L.t(lang, 'stData')),
            ListTile(
              dense: true,
              leading: const Icon(Icons.help_outline, size: 18, color: AppTheme.teal),
              title: Text(L.t(lang, 'stFaq')),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const FaqScreen())),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.insights_outlined, size: 18, color: AppTheme.teal),
              title: Text(L.t(lang, 'stInsights')),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const InsightsScreen())),
            ),
            if (app.stores.contentRequests.isNotEmpty) ...[
              RuleLabel(label: L.t(lang, 'stContentRequests')),
              const SizedBox(height: 6),
              Text(L.t(lang, 'stContentRequestsBody'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final q in app.stores.contentRequests)
                    Text(
                      '“$q”',
                      style: const TextStyle(
                          fontFamily: AppTheme.display,
                          fontStyle: FontStyle.italic,
                          fontSize: 14,
                          color: AppTheme.inkSoft),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            RuleLabel(label: L.t(lang, 'stBackup')),
            const SizedBox(height: 8),
            Text(L.t(lang, 'stBackupBody'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: L.t(lang, 'stPassword'),
                helperText: L.t(lang, 'stPasswordHint'),
                helperStyle: const TextStyle(
                    fontFamily: AppTheme.mono, fontSize: 9, color: AppTheme.inkFaint),
                border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.ink, width: 1.2)),
              ),
              style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _InkButtonSmall(
                  label: _passwordController.text.isEmpty
                      ? L.t(lang, 'stExport')
                      : L.t(lang, 'stExportLocked'),
                  filled: true,
                  onTap: _busy ? null : () => _export(app),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InkButtonSmall(
                  label: L.t(lang, 'stImport'),
                  filled: false,
                  onTap: _busy ? null : () => _import(app),
                ),
              ),
            ]),

            _SectionHeader(label: L.t(lang, 'stAbout')),
            Text(L.t(lang, 'stAboutBody'),
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 14.5,
                    height: 1.55,
                    color: AppTheme.inkSoft)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const OnboardingScreen()));
              },
              child: Text(
                L.t(lang, 'stOnboardingAgain'),
                style: const TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: AppTheme.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggle(AppState app, String flag) {
    final p = app.profile;
    final set = {...p.avoidFlags};
    if (!set.add(flag)) set.remove(flag);
    app.updateProfile(p.copyWith(avoidFlags: set));
  }

  Future<void> _editName(BuildContext context, AppState app) async {
    final lang = app.profile.lang;
    final controller = TextEditingController(text: app.profile.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.paper,
        title: Text(L.t(lang, 'stName'),
            style: const TextStyle(fontFamily: AppTheme.display)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
              border: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.ink))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L.t(lang, 'cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(L.t(lang, 'save'))),
        ],
      ),
    );
    if (result != null) {
      await app.updateProfile(app.profile.copyWith(name: result));
    }
    controller.dispose();
  }

  Future<void> _export(AppState app) async {
    final lang = app.profile.lang;
    setState(() => _busy = true);
    try {
      await app.exportBackup(
          password: _passwordController.text.isEmpty
              ? null
              : _passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L.t(lang, 'stExport'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L.t(lang, 'errGeneric'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import(AppState app) async {
    final lang = app.profile.lang;
    final files = await FilePicker.pickFiles(type: FileType.any);
    final file = files.singleOrNull;
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    var imported = -1;
    try {
      imported = await app.importBackup(bytes.toList());
    } on backup.DecryptionException catch (e) {
      if (e.reason == 'needsPassword') {
        final password = await _askPassword();
        if (password == null) return;
        try {
          imported =
              await app.importBackup(bytes.toList(), password: password);
        } on backup.DecryptionException catch (e2) {
          if (mounted) {
            final key = e2.reason == 'wrongPassword'
                ? 'stWrongPassword'
                : e2.reason == 'corrupted'
                    ? 'stCorrupted'
                    : 'stInvalidFormat';
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(L.t(lang, key))));
          }
          return;
        }
      } else {
        if (mounted) {
          final key = e.reason == 'corrupted'
              ? 'stCorrupted'
              : 'stInvalidFormat';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(L.t(lang, key))));
        }
        return;
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L.t(lang, 'stInvalidFormat'))));
      }
      return;
    }
    if (imported >= 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.f(lang, 'stImportDone', {'n': '$imported'}))));
    }
  }

  Future<String?> _askPassword() async {
    final lang = context.read<AppState>().profile.lang;
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.paper,
        title: Text(L.t(lang, 'stPassword'),
            style: const TextStyle(fontFamily: AppTheme.display)),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
              border: UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.ink))),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L.t(lang, 'cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(L.t(lang, 'done'))),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _SpecificAvoidEditor extends StatefulWidget {
  final AppState app;
  final Lang lang;
  const _SpecificAvoidEditor({required this.app, required this.lang});

  @override
  State<_SpecificAvoidEditor> createState() => _SpecificAvoidEditorState();
}

class _SpecificAvoidEditorState extends State<_SpecificAvoidEditor> {
  final _controller = TextEditingController();
  List<String> _suggestions = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final lang = widget.lang;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: _controller,
        onChanged: (v) => setState(() =>
            _suggestions = app.ingredients.search(v).map((n) => n.id).toList()),
        decoration: InputDecoration(
          hintText: L.t(lang, 'scHint'),
          hintStyle: const TextStyle(
              fontFamily: AppTheme.hand, fontSize: 17, color: AppTheme.inkFaint),
          border: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.ink, width: 1.2)),
        ),
        style: const TextStyle(fontFamily: AppTheme.display, fontSize: 16),
      ),
      for (final id in _suggestions.take(4))
        if (!app.profile.avoidIngredients.contains(id))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(app.ingredients.nodes[id]?.name.get(lang) ?? id,
                style:
                    const TextStyle(fontFamily: AppTheme.display, fontSize: 15)),
            trailing: const Icon(Icons.add, size: 16, color: AppTheme.teal),
            onTap: () {
              final p = app.profile;
              app.updateProfile(p.copyWith(
                  avoidIngredients: {...p.avoidIngredients, id}));
              _controller.clear();
              setState(() => _suggestions = const []);
            },
          ),
      if (app.profile.avoidIngredients.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final id in app.profile.avoidIngredients)
              StampChip(
                label: app.ingredients.nodes[id]?.name.get(lang) ?? id,
                color: AppTheme.coral,
                selected: true,
                onTap: () {
                  final p = app.profile;
                  final next = {...p.avoidIngredients}..remove(id);
                  app.updateProfile(p.copyWith(avoidIngredients: next));
                },
              ),
          ]),
        ),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
              color: AppTheme.coral),
        ),
        const SizedBox(height: 4),
        Container(height: 2.5, color: AppTheme.ink),
      ]),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double? value;
  final double min;
  final double max;
  final int division;
  final String Function(double?) format;
  final bool allowOff;
  final ValueChanged<double?> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.division,
    required this.format,
    required this.allowOff,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          Text(
            format(value),
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.teal),
          ),
        ]),
      ),
      Row(children: [
        if (allowOff)
          GestureDetector(
            onTap: () => onChanged(null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                    color: value == null ? AppTheme.teal : AppTheme.line),
              ),
              child: Text(
                'off',
                style: TextStyle(
                    fontFamily: AppTheme.mono,
                    fontSize: 9,
                    color: value == null ? AppTheme.teal : AppTheme.inkFaint),
              ),
            ),
          ),
        Expanded(
          child: Slider(
            value: value ?? min,
            min: min,
            max: max,
            divisions: division,
            activeColor: AppTheme.teal,
            inactiveColor: AppTheme.line,
            onChanged: value == null && allowOff
                ? null
                : (v) => onChanged(v),
          ),
        ),
      ]),
    ]);
  }
}

class _InkButtonSmall extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const _InkButtonSmall(
      {required this.label, required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppTheme.ink : AppTheme.paper,
          border: Border.all(color: AppTheme.ink, width: 1.2),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 10,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
              color: filled ? AppTheme.paper : AppTheme.ink),
        ),
      ),
    );
  }
}
