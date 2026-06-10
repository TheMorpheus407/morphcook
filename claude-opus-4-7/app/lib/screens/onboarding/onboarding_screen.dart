import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/profile_store.dart';
import '../../data/corpus.dart';
import '../../l10n/strings.dart';
import '../../models/ingredient_dict.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/chip_tag.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/ink_button.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _index = 0;

  // Working draft
  String _lang = 'en';
  String _name = '';
  final Set<String> _avoidFlags = {};
  final Set<String> _avoidIngredients = {};
  final Set<String> _requiredAttributes = {};
  int _maxTime = 0;
  int _calorieTarget = 0;
  String _effort = 'medium';

  @override
  void initState() {
    super.initState();
    final p = context.read<ProfileStore>().profile;
    _lang = p.lang;
    _name = p.name;
    _avoidFlags.addAll(p.avoidFlags);
    _avoidIngredients.addAll(p.avoidIngredients);
    _requiredAttributes.addAll(p.requiredAttributes);
    _maxTime = p.maxTimeMinutes;
    _calorieTarget = p.calorieTarget;
    _effort = p.preferredEffort;
  }

  void _next() {
    if (_index < 4) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_index > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    final store = context.read<ProfileStore>();
    await store.update((p) => p.copyWith(
          lang: _lang,
          name: _name.trim(),
          avoidFlags: Set.of(_avoidFlags),
          avoidIngredients: Set.of(_avoidIngredients),
          requiredAttributes: Set.of(_requiredAttributes),
          maxTimeMinutes: _maxTime,
          calorieTarget: _calorieTarget,
          preferredEffort: _effort,
          onboarded: true,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l = L10n(_lang);
    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Masthead(
                title: 'morphcook',
                edition: l.t('app.tagline'),
                leftMeta: 'step ${_index + 1}/5',
                rightMeta: l.t('onb.title'),
              ),
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    _LangStep(
                      lang: _lang,
                      onChanged: (v) => setState(() => _lang = v),
                    ),
                    _NameStep(
                      l: l,
                      initial: _name,
                      onChanged: (v) => setState(() => _name = v),
                    ),
                    _DietStep(
                      l: l,
                      avoidFlags: _avoidFlags,
                      avoidIngredients: _avoidIngredients,
                      requiredAttributes: _requiredAttributes,
                      onChanged: () => setState(() {}),
                    ),
                    _BudgetStep(
                      l: l,
                      maxTime: _maxTime,
                      calorieTarget: _calorieTarget,
                      effort: _effort,
                      onChanged: (t, c, e) => setState(() {
                        _maxTime = t;
                        _calorieTarget = c;
                        _effort = e;
                      }),
                    ),
                    _ConfirmStep(
                      l: l,
                      name: _name,
                      lang: _lang,
                      avoidFlags: _avoidFlags,
                      avoidIngredients: _avoidIngredients,
                      maxTime: _maxTime,
                      calorieTarget: _calorieTarget,
                      effort: _effort,
                    ),
                  ],
                ),
              ),
              const DashedRule(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    if (_index > 0)
                      InkButton(
                        label: l.t('app.back'),
                        primary: false,
                        onPressed: _back,
                      ),
                    const Spacer(),
                    InkButton(
                      label: _index < 4
                          ? l.t('app.continue')
                          : l.t('app.done'),
                      onPressed: _canAdvance() ? _next : null,
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

  bool _canAdvance() {
    if (_index == 1) return _name.trim().isNotEmpty;
    return true;
  }
}

class _LangStep extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onChanged;
  const _LangStep({required this.lang, required this.onChanged});

  @override
  Widget build(BuildContext ctx) {
    final l = L10n(lang);
    return _StepShell(
      title: l.t('onb.lang.title'),
      body: l.t('onb.lang.body'),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ChipTag(
            label: 'English',
            selected: lang == 'en',
            onTap: () => onChanged('en'),
          ),
          ChipTag(
            label: 'Deutsch',
            selected: lang == 'de',
            onTap: () => onChanged('de'),
          ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  final L10n l;
  final String initial;
  final ValueChanged<String> onChanged;
  const _NameStep(
      {required this.l, required this.initial, required this.onChanged});

  @override
  Widget build(BuildContext ctx) {
    return _StepShell(
      title: l.t('onb.name.title'),
      body: l.t('onb.name.body'),
      child: TextFormField(
        initialValue: initial,
        autofocus: true,
        style: MorphType.headline(size: 26),
        cursorColor: MorphColors.ink,
        decoration: InputDecoration(
          hintText: l.t('onb.name.hint'),
          isDense: false,
        ),
        textInputAction: TextInputAction.done,
        onChanged: onChanged,
      ),
    );
  }
}

class _DietStep extends StatelessWidget {
  final L10n l;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final Set<String> requiredAttributes;
  final VoidCallback onChanged;
  const _DietStep({
    required this.l,
    required this.avoidFlags,
    required this.avoidIngredients,
    required this.requiredAttributes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext ctx) {
    final corpus = ctx.watch<Corpus>();
    final ontology = corpus.ontology;
    final compounds = ontology.compoundFlags.keys.toList()..sort();

    return _StepShell(
      title: l.t('onb.diet.title'),
      body: l.t('onb.diet.body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in compounds)
                ChipTag(
                  label: ontology.compoundFlagNames[id]?.get(l.lang) ?? id,
                  selected: avoidFlags.contains(id),
                  onTap: () {
                    if (avoidFlags.contains(id)) {
                      avoidFlags.remove(id);
                    } else {
                      avoidFlags.add(id);
                    }
                    onChanged();
                  },
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l.t('onb.allergies.body'),
              style: MorphType.body(size: 14)),
          const SizedBox(height: 10),
          _IngredientTypeahead(
            l: l,
            selected: avoidIngredients,
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          if (avoidIngredients.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in avoidIngredients)
                  ChipTag(
                    label: corpus.ingredientDict.nodes[id]?.name.get(l.lang) ?? id,
                    selected: true,
                    icon: Icons.close,
                    onTap: () {
                      avoidIngredients.remove(id);
                      onChanged();
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IngredientTypeahead extends StatefulWidget {
  final L10n l;
  final Set<String> selected;
  final VoidCallback onChanged;
  const _IngredientTypeahead({
    required this.l,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_IngredientTypeahead> createState() => _IngredientTypeaheadState();
}

class _IngredientTypeaheadState extends State<_IngredientTypeahead> {
  final _ctrl = TextEditingController();
  List<IngredientNode> _matches = const [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _query(String s) {
    final dict = context.read<Corpus>().ingredientDict;
    setState(() {
      _matches = dict.typeahead(s, widget.l.lang);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          onChanged: _query,
          cursorColor: MorphColors.ink,
          style: MorphType.body(size: 16, color: MorphColors.ink),
          decoration: const InputDecoration(
            hintText: 'apples, cilantro, bell pepper…',
            prefixIcon: Icon(Icons.search, size: 18),
          ),
        ),
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final n in _matches.take(20))
                ChipTag(
                  label: n.name.get(widget.l.lang),
                  selected: widget.selected.contains(n.id),
                  icon: Icons.add,
                  onTap: () {
                    widget.selected.add(n.id);
                    widget.onChanged();
                    setState(() {
                      _ctrl.clear();
                      _matches = const [];
                    });
                  },
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _BudgetStep extends StatelessWidget {
  final L10n l;
  final int maxTime;
  final int calorieTarget;
  final String effort;
  final void Function(int maxTime, int cal, String effort) onChanged;
  const _BudgetStep({
    required this.l,
    required this.maxTime,
    required this.calorieTarget,
    required this.effort,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext ctx) {
    return _StepShell(
      title: l.t('onb.budget.title'),
      body: l.t('onb.budget.cal.body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.t('onb.budget.cal').toUpperCase(),
              style: MorphType.smallCaps()),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: calorieTarget.toDouble(),
                  min: 0,
                  max: 1200,
                  divisions: 24,
                  activeColor: MorphColors.ink,
                  inactiveColor: MorphColors.inkFaint,
                  onChanged: (v) =>
                      onChanged(maxTime, v.round(), effort),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  calorieTarget == 0
                      ? '— kcal'
                      : '$calorieTarget kcal',
                  textAlign: TextAlign.end,
                  style: MorphType.mono(size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l.t('onb.budget.time').toUpperCase(),
              style: MorphType.smallCaps()),
          const SizedBox(height: 4),
          Text(l.t('onb.budget.time.body'),
              style: MorphType.body(size: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: maxTime.toDouble(),
                  min: 0,
                  max: 120,
                  divisions: 12,
                  activeColor: MorphColors.ink,
                  inactiveColor: MorphColors.inkFaint,
                  onChanged: (v) =>
                      onChanged(v.round(), calorieTarget, effort),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  maxTime == 0 ? '— min' : '$maxTime min',
                  textAlign: TextAlign.end,
                  style: MorphType.mono(size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l.t('onb.effort').toUpperCase(), style: MorphType.smallCaps()),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in ['easy', 'medium', 'hard'])
                ChipTag(
                  label: e,
                  selected: effort == e,
                  onTap: () => onChanged(maxTime, calorieTarget, e),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final L10n l;
  final String name;
  final String lang;
  final Set<String> avoidFlags;
  final Set<String> avoidIngredients;
  final int maxTime;
  final int calorieTarget;
  final String effort;
  const _ConfirmStep({
    required this.l,
    required this.name,
    required this.lang,
    required this.avoidFlags,
    required this.avoidIngredients,
    required this.maxTime,
    required this.calorieTarget,
    required this.effort,
  });

  @override
  Widget build(BuildContext ctx) {
    return _StepShell(
      title: l.t('onb.confirm.title'),
      body: l.t('onb.confirm.body'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('— ${name.toLowerCase()} —',
              style: MorphType.headline(size: 28)),
          const SizedBox(height: 24),
          _ConfirmRow(label: 'language', value: lang.toUpperCase()),
          _ConfirmRow(
            label: 'avoid',
            value: avoidFlags.isEmpty ? '— none —' : avoidFlags.join(', '),
          ),
          _ConfirmRow(
            label: 'ingredients',
            value: avoidIngredients.isEmpty ? '— none —' : avoidIngredients.join(', '),
          ),
          _ConfirmRow(
            label: 'time',
            value: maxTime == 0 ? '— no limit —' : '≤ $maxTime min',
          ),
          _ConfirmRow(
            label: 'calorie target',
            value:
                calorieTarget == 0 ? '— no target —' : '$calorieTarget kcal',
          ),
          _ConfirmRow(label: 'effort', value: effort),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;
  const _ConfirmRow({required this.label, required this.value});

  @override
  Widget build(BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label.toUpperCase(),
                style: MorphType.smallCaps(size: 10)),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Text(value, style: MorphType.body(size: 15))),
        ],
      ),
    );
  }
}

class _StepShell extends StatelessWidget {
  final String title;
  final String body;
  final Widget child;
  const _StepShell(
      {required this.title, required this.body, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MorphType.display(size: 30)),
          const SizedBox(height: 10),
          Text(body, style: MorphType.body(size: 16)),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }
}
