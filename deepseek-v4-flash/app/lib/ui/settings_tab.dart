import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../models/models.dart';
import 'backup.dart';
import 'faq.dart';
import 'insights.dart';
import 'widgets.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _ingredientController = TextEditingController();
  final TextEditingController _calorieController = TextEditingController();
  List<IngredientNode> _hits = const [];
  Timer? _calorieDebounce;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calorieController.text = Services.of(context).state.profile.calorieTarget
            ?.toString() ??
        '';
  }

  @override
  void dispose() {
    _ingredientController.dispose();
    _calorieController.dispose();
    _calorieDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return ListenableBuilder(
      listenable: svc.state,
      builder: (context, _) {
        final profile = svc.state.profile;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            _profileSection(context, svc, profile, t),
            _avoidClassSection(context, svc, profile, lang, t),
            _avoidIngSection(context, svc, profile, lang, t),
            _requiredSection(context, svc, profile, t),
            _windowsSection(context, svc, profile, t),
            _switchSection(context, profile, t),
            _accessibilitySection(context, profile, t),
            _dataSection(context, svc, t),
          ],
        );
      },
    );
  }

  void _patch(Services svc, void Function(UserProfile p) fn) {
    svc.state.patchProfile(fn);
  }

  Widget _profileSection(BuildContext context, Services svc,
      UserProfile profile, String Function(String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tProfile)),
        Row(
          children: [
            Expanded(
              child: Text(
                profile.name.isEmpty ? '—' : profile.name,
                style: AppText.serif(context, size: 18, weight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: t(L10n.tEdit),
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _editName(context, svc, t),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                t(L10n.tLanguage).toUpperCase(),
                style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
              ),
            ),
            InkWell(
              onTap: () => _patch(svc, (p) => p.lang = L10n.en),
              borderRadius: BorderRadius.circular(4),
              child: PressChip(
                  label: L10n.en, filled: profile.lang == L10n.en),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _patch(svc, (p) => p.lang = L10n.de),
              borderRadius: BorderRadius.circular(4),
              child: PressChip(
                  label: L10n.de, filled: profile.lang == L10n.de),
            ),
          ],
        ),
        const DottedDivider(),
      ],
    );
  }

  Future<void> _editName(BuildContext context, Services svc,
      String Function(String) t) async {
    final controller = TextEditingController(text: svc.state.profile.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t(L10n.tName),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 30,
          style: AppText.mono(context, size: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(L10n.tCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(t(L10n.tSave)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || !mounted) return;
    _patch(svc, (p) => p.name = name.trim());
  }

  Widget _avoidClassSection(BuildContext context, Services svc,
      UserProfile profile, String lang, String Function(String) t) {
    final avoids = svc.corpus.ontology.compoundAvoids;
    final dietOrder = svc.corpus.ontology.dietOrder;
    final ordered = <String>[
      ...dietOrder.where(avoids.containsKey),
      ...avoids.keys.where((k) => !dietOrder.contains(k)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tAvoidClass)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in ordered)
              _Toggle(
                label: T(avoids[id]!.label, lang),
                selected: profile.avoidFlags.contains(id),
                onTap: () => _patch(svc, (p) {
                  final flags = Set.of(p.avoidFlags);
                  if (!flags.remove(id)) flags.add(id);
                  p.avoidFlags = flags;
                }),
              ),
          ],
        ),
        const DottedDivider(),
      ],
    );
  }

  Widget _avoidIngSection(BuildContext context, Services svc,
      UserProfile profile, String lang, String Function(String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tAvoidIng)),
        TextField(
          controller: _ingredientController,
          onChanged: (q) {
            setState(() {
              _hits = q.trim().isEmpty
                  ? const []
                  : svc.corpus.searchIngredients(q, lang).take(6).toList();
            });
          },
          style: AppText.mono(context, size: 12),
          decoration: InputDecoration(hintText: t(L10n.tTypeIngredient)),
        ),
        if (_hits.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              children: [
                for (var i = 0; i < _hits.length; i++)
                  ZebraRow(
                    index: i,
                    onTap: () {
                      final id = _hits[i].id;
                      _patch(svc, (p) {
                        p.avoidIngredients = {
                          ...p.avoidIngredients,
                          id,
                        };
                      });
                      _ingredientController.clear();
                      setState(() => _hits = const []);
                    },
                    child: Text(
                      svc.corpus.labelOf(_hits[i].id, lang),
                      style: AppText.mono(context, size: 11),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        if (profile.avoidIngredients.isEmpty)
          Text(
            t(L10n.tNoIngredient),
            style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in profile.avoidIngredients)
                InkWell(
                  onTap: () => _patch(svc, (p) {
                    p.avoidIngredients =
                        Set.of(p.avoidIngredients)..remove(id);
                  }),
                  borderRadius: BorderRadius.circular(4),
                  child: PressChip(label: svc.corpus.labelOf(id, lang)),
                ),
            ],
          ),
        const DottedDivider(),
      ],
    );
  }

  Widget _requiredSection(BuildContext context, Services svc,
      UserProfile profile, String Function(String) t) {
    final attrs = <String>[];
    for (final group in svc.corpus.ontology.attributes.values) {
      for (final k in group.keys) {
        attrs.add(k);
      }
    }
    final techniques = attrs
        .where((k) =>
            !k.contains('≤') &&
            !k.contains('>') &&
            !const {'easy', 'medium', 'hard'}.contains(k))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tRequiredAttrs)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final id in techniques)
              _Toggle(
                label: id,
                selected: profile.requiredAttributes.contains(id),
                onTap: () => _patch(svc, (p) {
                  final attrs = Set.of(p.requiredAttributes);
                  if (!attrs.remove(id)) attrs.add(id);
                  p.requiredAttributes = attrs;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t(L10n.tAttrNote),
          style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
        ),
        const DottedDivider(),
      ],
    );
  }

  Widget _windowsSection(BuildContext context, Services svc,
      UserProfile profile, String Function(String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tCalorieTime)),
        Row(
          children: [
            Expanded(
              child: Text(
                t(L10n.tCalorieTarget).toUpperCase(),
                style:
                    AppText.mono(context, size: 10, color: AppColors.inkSoft),
              ),
            ),
            SizedBox(
              width: 90,
              child: TextField(
                controller: _calorieController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                style: AppText.mono(context, size: 12),
                onChanged: (v) {
                  _calorieDebounce?.cancel();
                  _calorieDebounce = Timer(const Duration(milliseconds: 400),
                      () => _applyCalorie(svc, v));
                },
                onSubmitted: (v) {
                  _calorieDebounce?.cancel();
                  _applyCalorie(svc, v);
                },
              ),
            ),
          ],
        ),
        Text(
          t(L10n.tCalorieToleranceNote),
          style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
        ),
        const SizedBox(height: 8),
        Text(
          t(L10n.tTimeBudget).toUpperCase(),
          style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
        ),
        Slider(
          value: ((profile.maxTimeMinutes ?? 0).clamp(0, 120)).toDouble(),
          min: 0,
          max: 120,
          divisions: 24,
          label: '${(profile.maxTimeMinutes ?? 0)} ${t(L10n.tMinutes)}',
          onChanged: (v) => _patch(svc, (p) {
            p.maxTimeMinutes = v.round() == 0 ? null : v.round();
          }),
        ),
        const SizedBox(height: 4),
        Text(
          t(L10n.tPrefEffort).toUpperCase(),
          style: AppText.mono(context, size: 10, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in ['easy', 'medium', 'hard'])
              _Toggle(
                label: t({
                  'easy': L10n.tEasy,
                  'medium': L10n.tMedium,
                  'hard': L10n.tHard,
                }[e]!),
                selected: profile.preferredEffort == e,
                onTap: () => _patch(svc, (p) => p.preferredEffort = e),
              ),
            _Toggle(
              label: t(L10n.tAny),
              selected: profile.preferredEffort == null,
              onTap: () => _patch(svc, (p) => p.preferredEffort = null),
            ),
          ],
        ),
        const DottedDivider(),
      ],
    );
  }

  void _applyCalorie(Services svc, String v) {
    if (!mounted) return;
    final parsed = int.tryParse(v.trim());
    final current = svc.state.profile.calorieTarget;
    if (v.trim().isEmpty) {
      if (current != null) _patch(svc, (p) => p.calorieTarget = null);
    } else if (parsed != null && parsed != current) {
      _patch(svc, (p) => p.calorieTarget = parsed);
    }
  }

  Widget _switchSection(BuildContext context, UserProfile profile,
      String Function(String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DottedDivider(),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t(L10n.tShowVariantTags),
              style: AppText.serif(context, size: 15)),
          value: profile.showVariantTags,
          onChanged: (v) =>
              _patch(Services.of(context), (p) => p.showVariantTags = v),
        ),
        const DottedDivider(),
      ],
    );
  }

  Widget _accessibilitySection(BuildContext context, UserProfile profile,
      String Function(String) t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tAccessibility)),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Toggle(
              label: t(L10n.tSystem),
              selected: profile.reduceMotion == null,
              onTap: () => _patch(Services.of(context),
                  (p) => p.reduceMotion = null),
            ),
            _Toggle(
              label: t(L10n.tReduced),
              selected: profile.reduceMotion == true,
              onTap: () => _patch(Services.of(context),
                  (p) => p.reduceMotion = true),
            ),
            _Toggle(
              label: t(L10n.tNormalMotion),
              selected: profile.reduceMotion == false,
              onTap: () => _patch(Services.of(context),
                  (p) => p.reduceMotion = false),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t(L10n.tVisualAlert),
              style: AppText.serif(context, size: 15)),
          value: profile.visualAlertEnabled,
          onChanged: (v) => _patch(Services.of(context),
              (p) => p.visualAlertEnabled = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t(L10n.tQuickNext),
              style: AppText.serif(context, size: 15)),
          value: profile.quickNextTapEnabled,
          onChanged: (v) => _patch(Services.of(context),
              (p) => p.quickNextTapEnabled = v),
        ),
        const DottedDivider(),
      ],
    );
  }

  Widget _dataSection(
      BuildContext context, Services svc, String Function(String) t) {
    final rows = <(String, VoidCallback)>[
      (t(L10n.tBackup), () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const BackupScreen()))),
      (t(L10n.tInsights), () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const InsightsPage()))),
      (t(L10n.tFaq), () => Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const FaqPage()))),
      (t(L10n.tAbout), () => _aboutDialog(context, t)),
      (t(L10n.tClearHistory), () => _clearHistory(context, svc, t)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: t(L10n.tData)),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                ZebraRow(
                  index: i,
                  onTap: rows[i].$2,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rows[i].$1,
                          style: AppText.mono(
                              context, size: 11, color: AppColors.ink),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.inkFaint),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _aboutDialog(BuildContext context, String Function(String) t) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(L10n.tAbout),
            style: AppText.serif(context, size: 18, weight: FontWeight.w700)),
        content: Text(
          t(L10n.tAboutBody),
          style: AppText.mono(context, size: 11, height: 1.5),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(L10n.tDone)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearHistory(
      BuildContext context, Services svc, String Function(String) t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(L10n.tClearHistory),
            style: AppText.serif(context, size: 18, weight: FontWeight.w700)),
        content: Text(
          '${t(L10n.tClearHistory)}?',
          style: AppText.mono(context, size: 11, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t(L10n.tCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(L10n.tConfirm)),
          ),
        ],
      ),
    );
    if (ok == true) svc.state.clearHistory();
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Toggle({required this.label, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.accent : AppColors.lineDotted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          border: Border.all(color: border, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: AppText.mono(
            context,
            size: 10,
            color: selected ? Colors.white : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
