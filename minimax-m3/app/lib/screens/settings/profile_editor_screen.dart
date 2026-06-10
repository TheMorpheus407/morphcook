import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../models/profile.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/handwritten_note.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/tag_chip.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late Profile _draft;
  final _nameCtrl = TextEditingController();
  final _ingCtrl = TextEditingController();
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final state = AppScope.of(context);
    _draft = state.profileRepo.profile;
    _nameCtrl.text = _draft.name;
    _seeded = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final state = AppScope.of(context);
    await state.profileRepo.save(_draft);
    if (mounted) Navigator.of(context).pop();
  }

  void _toggleAvoid(String id) {
    final s = {..._draft.avoidFlags};
    s.contains(id) ? s.remove(id) : s.add(id);
    setState(() => _draft = _draft.copyWith(avoidFlags: s));
  }

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final state = AppScope.of(context);
    final ont = state.ontologyRepo.ontology;
    final lang = _draft.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.profileEditor),
        actions: [
          TextButton(onPressed: _save, child: Text(s.save)),
        ],
      ),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            Text(s.changeName.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              onChanged: (v) => setState(() => _draft = _draft.copyWith(name: v.trim())),
              decoration: InputDecoration(hintText: s.nameHint),
            ),
            const SizedBox(height: 24),
            Text(s.changeAvoidances.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in ont.compoundFlags.keys)
                  TagChip(
                    label: ont.compoundFlags[k]!.label.resolve(lang),
                    selected: _draft.avoidFlags.contains(k),
                    accent: MCColors.coral,
                    onTap: () => _toggleAvoid(k),
                  ),
                for (final f in [
                  'dairy', 'gluten', 'egg', 'fish', 'shellfish', 'pork',
                  'beef', 'soy', 'peanuts', 'tree-nuts', 'sesame', 'honey',
                  'added-sugar',
                ])
                  TagChip(
                    label: ont.labelForFlag(f).resolve(lang),
                    selected: _draft.avoidFlags.contains(f),
                    onTap: () => _toggleAvoid(f),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            Text(s.specificIngredients.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 6),
            TextField(
              controller: _ingCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: s.searchIngredient),
            ),
            if (_ingCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: state.ingredientRepo.tree.search(_ingCtrl.text).map((n) {
                  return TagChip(
                    label: n.label.resolve(lang),
                    onTap: () {
                      final next = {..._draft.avoidIngredients, n.id};
                      setState(() => _draft = _draft.copyWith(avoidIngredients: next));
                      _ingCtrl.clear();
                    },
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 16),
            if (_draft.avoidIngredients.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _draft.avoidIngredients.map((id) {
                  final n = state.ingredientRepo.tree.find(id);
                  return TagChip(
                    label: '${n?.label.resolve(lang) ?? id} ×',
                    selected: true,
                    accent: MCColors.teal,
                    onTap: () {
                      final s = {..._draft.avoidIngredients}..remove(id);
                      setState(() => _draft = _draft.copyWith(avoidIngredients: s));
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 30),
            Text(s.calorieTarget.toUpperCase(), style: MCTypography.eyebrow()),
            Slider(
              value: (_draft.calorieTarget ?? 600).toDouble(),
              min: 250,
              max: 1100,
              divisions: 17,
              activeColor: MCColors.coral,
              inactiveColor: MCColors.paperDark,
              onChanged: (v) => setState(() =>
                  _draft = _draft.copyWith(calorieTarget: v.round())),
            ),
            Text('${_draft.calorieTarget ?? 600} kcal', style: MCTypography.mono(size: 13)),
            const SizedBox(height: 16),
            Text(s.timeBudget.toUpperCase(), style: MCTypography.eyebrow()),
            Slider(
              value: (_draft.maxTimeMinutes ?? 45).toDouble(),
              min: 10,
              max: 120,
              divisions: 22,
              activeColor: MCColors.coral,
              inactiveColor: MCColors.paperDark,
              onChanged: (v) => setState(() =>
                  _draft = _draft.copyWith(maxTimeMinutes: v.round())),
            ),
            Text('${_draft.maxTimeMinutes ?? 45} ${s.minutes}', style: MCTypography.mono(size: 13)),
            const SizedBox(height: 16),
            Text(s.effortMood.toUpperCase(), style: MCTypography.eyebrow()),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final mood in ['easy', 'medium', 'hard'])
                  TagChip(
                    label: mood,
                    selected: _draft.preferredEffort == mood,
                    accent: MCColors.olive,
                    onTap: () => setState(() => _draft = _draft.copyWith(
                          preferredEffort:
                              _draft.preferredEffort == mood ? null : mood,
                        )),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            const DashedRule(),
            const SizedBox(height: 24),
            HandwrittenNote(
              text: '— ${s.everyBody.toLowerCase()}.',
              color: MCColors.coral,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}
