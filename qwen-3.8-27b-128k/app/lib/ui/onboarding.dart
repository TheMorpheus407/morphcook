/// Onboarding wizard: language → name → diet & avoid → targets → confirm.
/// Spec: "language → name → diet & allergies → calorie target + time budget
/// → confirm."  A single, friendly, scrollable sheet — the same fields the
/// settings hub edits.  Popping with `true` = user confirmed the profile.
library;

import 'package:flutter/material.dart';

import '../core/matching.dart';
import '../core/theme.dart';
import 'morph.dart';
import 'widgets.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late Profile _p; // working copy; committed on "begin"
  late final TextEditingController _nameCtrl;

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final prof = Morph.of(context).profile;
    _p = prof.clone();
    _nameCtrl = TextEditingController(text: prof.name);
    _initialized = true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Profile _commitAndReturn() {
    // mutate store.profile in place so any listeners see the same object.
    final m = Morph.of(context);
    final current = m.profile;
    current.name = _p.name;
    current.lang = _p.lang;
    current.maxTimeMinutes = _p.maxTimeMinutes;
    current.calorieTarget = _p.calorieTarget;
    current.calorieTolerance = _p.calorieTolerance;
    current.preferredEffort = _p.preferredEffort;
    current.showVariantTags = _p.showVariantTags;
    current.reduceMotion = _p.reduceMotion;
    current.visualAlerts = _p.visualAlerts;
    current.quickNextTap = _p.quickNextTap;
    current.avoidFlags
      ..clear()
      ..addAll(_p.avoidFlags);
    current.avoidIngredients
      ..clear()
      ..addAll(_p.avoidIngredients);
    current.requiredAttributes
      ..clear()
      ..addAll(_p.requiredAttributes);
    m.store.updateProfile(current.clone());
    return current;
  }

  void _saveAndPop(bool confirmed) {
    final m = Morph.of(context);
    if (confirmed) {
      _commitAndReturn();
      // Flipping the flag is what swaps the app root to HomeScreen when
      // onboarding *is* the root; it's a harmless no-op otherwise.
      m.store.setOnboarded(true);
    }
    final nav = Navigator.of(context);
    // Popping the root route is what left a black screen before the fix:
    // there's no route to pop when onboarding is the app itself.
    if (nav.canPop()) {
      nav.pop(confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Builder(builder: (context) => Text(m.t('ob.welcome'))),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: m.t('common.close'),
            onPressed: () => _saveAndPop(false),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text(m.t('ob.sub'),
                      style: T.body.copyWith(height: 1.5, fontSize: 13)),

                  const SizedBox(height: 20),
                  _Section(label: m.t('ob.language')),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'de', label: Text('Deutsch')),
                    ],
                    selected: {_p.lang},
                    onSelectionChanged: (s) => setState(() =>
                        _p.lang = s.first),
                  ),
                  const SizedBox(height: 18),
                  _Section(label: m.t('ob.name')),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                        hintText: 'a name, a nickname…'),
                    onChanged: (v) => setState(() => _p.name = v.trim()),
                  ),
                  const SizedBox(height: 18),
                  _Section(label: m.t('ob.diet'), sub: m.t('ob.diet.sub')),
                  for (final f in m.c.compoundFlags)
                    CheckboxListTile(
                      dense: true,
                      value: _p.avoidFlags.contains(f.id),
                      title: Text(
                          f.label.s(m.lang).isEmpty ? f.id : f.label.s(m.lang),
                          style: T.body.copyWith(color: Palette.ink)),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _p.avoidFlags.add(f.id);
                          } else {
                            _p.avoidFlags.remove(f.id);
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  _Section(label: m.t('ob.avoid'), sub: m.t('ob.avoid.sub')),
                  _AvoidPicker(
                    selected: _p.avoidIngredients,
                    onSelect: (id) {
                      setState(() {
                        if (_p.avoidIngredients.contains(id)) {
                          _p.avoidIngredients.remove(id);
                        } else {
                          _p.avoidIngredients.add(id);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _Section(label: '${m.t('ob.calories')} · ${m.t('ob.time')} · ${m.t('ob.effort')}'),
                  _CalorieSlider(
                      value: _p.calorieTarget,
                      lo: 200,
                      hi: 1400,
                      onDone: (v) => setState(() => _p.calorieTarget = v)),
                  const SizedBox(height: 8),
                  _CalorieSlider(
                      value: _p.maxTimeMinutes,
                      lo: 15,
                      hi: 240,
                      onDone: (v) => setState(
                          () => _p.maxTimeMinutes = v)),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final e in ['easy', 'medium', 'hard'])
                        TagChip(
                            label: m.t('effort.$e'),
                            selected: _p.preferredEffort == e,
                            onTap: () =>
                                setState(() => _p.preferredEffort = e)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: InkButton(
                label: m.t('ob.begin'),
                icon: Icons.play_arrow,
                onTap: () => _saveAndPop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, this.sub});
  final String label;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              label.toUpperCase(),
              style: T.section.copyWith(letterSpacing: 2.4)),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub!, style: T.caption.copyWith(height: 1.5)),
          ],
        ],
      ),
    );
  }
}

class _CalorieSlider extends StatelessWidget {
  const _CalorieSlider(
      {required this.value,
      required this.lo,
      required this.hi,
      required this.onDone});
  final int value;
  final double lo;
  final double hi;
  final void Function(int) onDone;

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: value.toDouble(),
      min: lo,
      max: hi,
      label: '$value',
      onChanged: (v) => onDone(v.round()),
    );
  }
}

class _AvoidPicker extends StatefulWidget {
  const _AvoidPicker({required this.selected, required this.onSelect});
  final Set<String> selected;
  final void Function(String) onSelect;

  @override
  State<_AvoidPicker> createState() => _AvoidPickerState();
}

class _AvoidPickerState extends State<_AvoidPicker> {
  final TextEditingController _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final q = _q.trim().toLowerCase();
    final hits = m.c.ingredients.values.where((met) =>
        q.isEmpty ||
        met.name.s('en').toLowerCase().contains(q) ||
        met.name.s('de').toLowerCase().contains(q) ||
        met.id.contains(q)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
                hintText: 'apples, cilantro, bell peppers…'),
            onChanged: (v) => setState(() => _q = v)),
        const SizedBox(height: 6),
        SizedBox(
            height: 190,
            child: ListView(
                children: [
                  for (final met in hits)
                    CheckboxListTile(
                      dense: true,
                      value: widget.selected.contains(met.id),
                      title: Text(met.name.s(m.lang),
                          style: T.body.copyWith(color: Palette.ink)),
                      subtitle: Text(met.aisle, style: T.caption),
                      onChanged:
                          (v) => widget.onSelect(met.id),
                    ),
                ])),
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in widget.selected)
                  TagChip(
                      label: '${m.c.ingredients[id]?.name.s(m.lang) ?? id} ✕',
                      onTap: () => widget.onSelect(id)),
              ],
            ),
          ),
      ],
    );
  }
}
