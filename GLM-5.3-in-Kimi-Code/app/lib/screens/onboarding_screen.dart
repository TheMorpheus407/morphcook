/// Onboarding: language → name → diet & allergies → prefs → confirm.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../logic/profile.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  Profile _draft = const Profile();

  @override
  Widget build(BuildContext context) {
    final lang = _draft.lang;
    final app = context.watch<AppState>();
    final corpus = app.corpus!;
    final motion = Motion(_draft.reduceMotion ?? false);

    final pages = [
      _Welcome(lang: lang, onNext: _next),
      _LangStep(
        lang: lang,
        onPick: (l) => setState(() => _draft = _draft.copyWith(lang: l)),
        onNext: _next,
      ),
      _NameStep(
        lang: lang,
        name: _draft.name,
        onChanged: (n) => setState(() => _draft = _draft.copyWith(name: n)),
        onNext: _next,
      ),
      _DietStep(
        lang: lang,
        ontology: corpus.ontology,
        profile: _draft,
        onToggleCompound: _toggleCompound,
        onToggleClass: _toggleClass,
        onNext: _next,
        onBack: _back,
      ),
      _AvoidStep(
        lang: lang,
        index: corpus.ingredients,
        avoidIngredients: _draft.avoidIngredients,
        onAdd: (id) => setState(() =>
            _draft = _draft.copyWith(avoidIngredients: {..._draft.avoidIngredients, id})),
        onRemove: (id) => setState(() {
          final next = {..._draft.avoidIngredients}..remove(id);
          _draft = _draft.copyWith(avoidIngredients: next);
        }),
        onNext: _next,
        onBack: _back,
      ),
      _PrefsStep(
        lang: lang,
        profile: _draft,
        onChanged: (p) => setState(() => _draft = p),
        onNext: _next,
        onBack: _back,
      ),
      _ConfirmStep(
        lang: lang,
        ontology: corpus.ontology,
        profile: _draft,
        onFinish: () => app.completeOnboarding(_draft),
        onBack: _back,
      ),
    ];

    return Scaffold(
      body: PaperGrain(
        child: SafeArea(
          child: Column(children: [
            _StepRail(lang: lang, step: _step, total: pages.length, onBack: _back),
            Expanded(
              child: AnimatedSwitcher(
                duration: motion.medium,
                child: KeyedSubtree(key: ValueKey(_step), child: pages[_step]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _next() => setState(() => _step = (_step + 1).clamp(0, 6));
  void _back() => setState(() => _step = (_step - 1).clamp(0, 6));

  void _toggleCompound(String id) {
    final set = {..._draft.avoidFlags};
    final compound = id;
    if (set.contains(compound)) {
      // remove compound and its exclusive children selection markers
      set.remove(compound);
    } else {
      set.add(compound);
      // drop narrower compound flags that the new one subsumes (vegetarian vs vegan)
      const subsumption = {
        'vegan': ['vegetarian', 'pescatarian'],
        'vegetarian': ['pescatarian'],
      };
      for (final sub in subsumption[compound] ?? const <String>[]) {
        set.remove(sub);
      }
    }
    setState(() => _draft = _draft.copyWith(avoidFlags: set));
  }

  void _toggleClass(String flag) {
    final set = {..._draft.avoidFlags};
    if (!set.add(flag)) set.remove(flag);
    setState(() => _draft = _draft.copyWith(avoidFlags: set));
  }
}

class _StepRail extends StatelessWidget {
  final Lang lang;
  final int step;
  final int total;
  final VoidCallback onBack;
  const _StepRail({required this.lang, required this.step, required this.total, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          if (step > 0)
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.arrow_back, size: 20, color: AppTheme.inkSoft),
            )
          else
            const SizedBox(width: 20),
          const Spacer(),
          Text(
            'no. ${step + 1} / $total',
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 10,
                letterSpacing: 2,
                color: AppTheme.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  final Lang lang;
  final VoidCallback onNext;
  const _Welcome({required this.lang, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StripedPlate(
              color: AppTheme.coral,
              caption: '',
              height: 150,
              rotation: -1.5,
            ),
            const SizedBox(height: 34),
            Text(
              L.t(lang, 'obWelcomeTitle'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 18),
            Text(
              L.t(lang, 'obWelcomeBody'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.inkSoft),
            ),
            const SizedBox(height: 34),
            _InkButton(label: L.t(lang, 'next'), onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _InkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _InkButton({required this.label, required this.onTap, this.color = AppTheme.ink});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
        decoration: BoxDecoration(color: color, border: Border.all(color: color)),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontFamily: AppTheme.mono,
              fontSize: 11.5,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: AppTheme.paper),
        ),
      ),
    );
  }
}

class _LangStep extends StatelessWidget {
  final Lang lang;
  final ValueChanged<Lang> onPick;
  final VoidCallback onNext;
  const _LangStep({required this.lang, required this.onPick, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(L.t(lang, 'obLangTitle'), style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 26),
        Row(mainAxisSize: MainAxisSize.min, children: [
          StampChip(
            label: 'english',
            color: AppTheme.teal,
            selected: lang == Lang.en,
            onTap: () => onPick(Lang.en),
          ),
          const SizedBox(width: 12),
          StampChip(
            label: 'deutsch',
            color: AppTheme.teal,
            selected: lang == Lang.de,
            onTap: () => onPick(Lang.de),
          ),
        ]),
        const SizedBox(height: 34),
        _InkButton(label: L.t(lang, 'next'), onTap: onNext),
      ]),
    );
  }
}

class _NameStep extends StatefulWidget {
  final Lang lang;
  final String name;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  const _NameStep({required this.lang, required this.name, required this.onChanged, required this.onNext});

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.name);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(widget.name.isEmpty
              ? L.t(widget.lang, 'obNameTitle')
              : 'hey, ${widget.name}.'),
          const SizedBox(height: 26),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _c,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.words,
              onChanged: widget.onChanged,
              onSubmitted: widget.onChanged,
              decoration: InputDecoration(
                hintText: L.t(widget.lang, 'obNameHint'),
                hintStyle: const TextStyle(
                    fontFamily: AppTheme.hand, fontSize: 20, color: AppTheme.inkFaint),
                border: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.ink, width: 1.4),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.coral, width: 1.8),
                ),
              ),
              style: const TextStyle(fontFamily: AppTheme.hand, fontSize: 24, color: AppTheme.ink),
            ),
          ),
          const SizedBox(height: 34),
          _InkButton(label: L.t(widget.lang, 'next'), onTap: widget.onNext),
        ]),
      ),
    );
  }
}

class _DietStep extends StatelessWidget {
  final Lang lang;
  final Ontology ontology;
  final Profile profile;
  final void Function(String) onToggleCompound;
  final void Function(String) onToggleClass;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _DietStep({
    required this.lang,
    required this.ontology,
    required this.profile,
    required this.onToggleCompound,
    required this.onToggleClass,
    required this.onNext,
    required this.onBack,
  });

  static const _dietKeys = [
    'vegan', 'vegetarian', 'pescatarian', 'halal', 'kosher',
    'low-fodmap', 'sugar-free', 'lactose-free',
  ];
  static const _classKeys = [
    'pork', 'beef', 'lamb', 'poultry', 'fish', 'shellfish', 'molluscs',
    'egg', 'dairy', 'gluten', 'soy', 'peanuts', 'tree-nuts', 'sesame',
    'mustard', 'celery', 'lupin', 'sulphites', 'alcohol', 'caffeine',
    'added-sugar', 'high-fodmap', 'honey', 'almonds', 'walnuts', 'pistachios',
    'cashews', 'hazelnuts',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18), children: [
      Text(L.t(lang, 'obDietTitle'), style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 6),
      Text(L.t(lang, 'obDietBody'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft)),
      const SizedBox(height: 18),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final k in _dietKeys)
            StampChip(
              label: ontology.compoundFlags[k]!.label.get(lang),
              color: AppTheme.teal,
              selected: profile.avoidFlags.contains(k),
              onTap: () => onToggleCompound(k),
            ),
        ],
      ),
      const SizedBox(height: 26),
      RuleLabel(label: L.t(lang, 'obAvoidClassTitle')),
      const SizedBox(height: 10),
      Text(L.t(lang, 'obAvoidClassBody'),
          style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final k in _classKeys)
            StampChip(
              label: ontology.flagLabel(k).get(lang),
              color: AppTheme.coral,
              selected: profile.avoidFlags.contains(k),
              onTap: () => onToggleClass(k),
            ),
        ],
      ),
      const SizedBox(height: 30),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        TextButton(onPressed: onBack, child: Text(L.t(lang, 'back'))),
        _InkButton(label: L.t(lang, 'next'), onTap: onNext),
      ]),
    ]);
  }
}

class _AvoidStep extends StatefulWidget {
  final Lang lang;
  final IngredientIndex index;
  final Set<String> avoidIngredients;
  final void Function(String) onAdd;
  final void Function(String) onRemove;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _AvoidStep({
    required this.lang,
    required this.index,
    required this.avoidIngredients,
    required this.onAdd,
    required this.onRemove,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<_AvoidStep> createState() => _AvoidStepState();
}

class _AvoidStepState extends State<_AvoidStep> {
  final _controller = TextEditingController();
  List<IngredientNode> _suggestions = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      children: [
        Text(L.t(widget.lang, 'obAvoidSpecTitle'),
            style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(L.t(widget.lang, 'obAvoidSpecBody'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft)),
        const SizedBox(height: 18),
        TextField(
          controller: _controller,
          onChanged: (v) =>
              setState(() => _suggestions = widget.index.search(v)),
          decoration: InputDecoration(
            hintText: L.t(widget.lang, 'scHint'),
            hintStyle: const TextStyle(
                fontFamily: AppTheme.hand, fontSize: 18, color: AppTheme.inkFaint),
            border: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.ink, width: 1.4)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppTheme.coral, width: 1.8)),
          ),
          style: const TextStyle(fontFamily: AppTheme.display, fontSize: 18),
        ),
        const SizedBox(height: 8),
        for (final s in _suggestions)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(s.name.get(widget.lang),
                style: const TextStyle(fontFamily: AppTheme.display, fontSize: 16)),
            subtitle: Text(s.parent ?? '',
                style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 10)),
            trailing: const Icon(Icons.add, size: 18, color: AppTheme.teal),
            onTap: () {
              widget.onAdd(s.id);
              _controller.clear();
              setState(() => _suggestions = const []);
            },
          ),
        if (widget.avoidIngredients.isNotEmpty) ...[
          const SizedBox(height: 14),
          RuleLabel(label: L.t(widget.lang, 'remove')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in widget.avoidIngredients)
                StampChip(
                  label: widget.index.nodes[id]?.name.get(widget.lang) ?? id,
                  color: AppTheme.coral,
                  selected: true,
                  onTap: () => widget.onRemove(id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: widget.onBack, child: Text(L.t(widget.lang, 'back'))),
            _InkButton(label: L.t(widget.lang, 'next'), onTap: widget.onNext),
          ],
        ),
      ],
    );
  }
}

class _PrefsStep extends StatelessWidget {
  final Lang lang;
  final Profile profile;
  final ValueChanged<Profile> onChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PrefsStep({
    required this.lang,
    required this.profile,
    required this.onChanged,
    required this.onNext,
    required this.onBack,
  });

  static const _efforts = ['easy', 'medium', 'hard'];
  static const _times = [15, 30, 45, 60, 90, 120, 180];
  static const _calories = [400, 500, 600, 700, 800];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      children: [
        Text(L.t(lang, 'obPrefsTitle'), style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(L.t(lang, 'obPrefsBody'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft)),
        const SizedBox(height: 22),
        RuleLabel(label: '${L.t(lang, 'stCalorie')} — ${L.t(lang, 'kcal')}'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          StampChip(
            label: L.t(lang, 'obAnyCalorie'),
            color: AppTheme.teal,
            selected: profile.calorieTarget == null,
            onTap: () => onChanged(
                profile.copyWith(clearCalorieTarget: true)),
          ),
          for (final c in _calories)
            StampChip(
              label: '~$c',
              color: AppTheme.teal,
              selected: profile.calorieTarget == c,
              onTap: () => onChanged(profile.copyWith(calorieTarget: c)),
            ),
        ]),
        const SizedBox(height: 22),
        RuleLabel(label: L.t(lang, 'stTimeBudget')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in _times)
            StampChip(
              label: '≤ $t',
              color: AppTheme.teal,
              selected: profile.maxTimeMinutes == t,
              onTap: () => onChanged(profile.copyWith(maxTimeMinutes: t)),
            ),
        ]),
        const SizedBox(height: 22),
        RuleLabel(label: L.t(lang, 'stEffort')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in _efforts)
            StampChip(
              label: e,
              color: AppTheme.teal,
              selected: profile.preferredEffort == e,
              onTap: () => onChanged(profile.copyWith(preferredEffort: e)),
            ),
        ]),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: onBack, child: Text(L.t(lang, 'back'))),
          _InkButton(label: L.t(lang, 'next'), onTap: onNext),
        ]),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  final Lang lang;
  final Ontology ontology;
  final Profile profile;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const _ConfirmStep({
    required this.lang,
    required this.ontology,
    required this.profile,
    required this.onFinish,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final diets = profile.avoidFlags
        .where((f) => ontology.compoundFlags.containsKey(f))
        .map((f) => ontology.compoundFlags[f]!.label.get(lang))
        .toList();
    final classes = profile.avoidFlags
        .where((f) => ontology.containsFlags.containsKey(f))
        .map((f) => ontology.flagLabel(f).get(lang))
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      children: [
        Text(L.t(lang, 'obConfirmTitle'),
            style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 6),
        Text(L.t(lang, 'obConfirmBody'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.inkSoft)),
        const SizedBox(height: 22),
        _Row(label: L.t(lang, 'stName'), value: profile.name.isEmpty ? '—' : profile.name),
        _Row(label: L.t(lang, 'stLanguage'), value: profile.lang == Lang.de ? 'deutsch' : 'english'),
        _Row(
            label: L.t(lang, 'stDiets'),
            value: diets.isEmpty ? '—' : diets.join(', ')),
        _Row(
            label: L.t(lang, 'stAvoidClasses'),
            value: classes.isEmpty ? '—' : classes.join(', ')),
        _Row(
            label: L.t(lang, 'stAvoidSpecific'),
            value: profile.avoidIngredients.isEmpty
                ? '—'
                : profile.avoidIngredients.join(', ')),
        _Row(
            label: L.t(lang, 'stCalorie'),
            value: profile.calorieTarget == null
                ? L.t(lang, 'stCalorieOff')
                : '~${profile.calorieTarget} ${L.t(lang, 'kcal')}'),
        _Row(
            label: L.t(lang, 'stTimeBudget'),
            value: profile.maxTimeMinutes == null
                ? '—'
                : '≤ ${profile.maxTimeMinutes} ${L.t(lang, 'minutes')}'),
        _Row(label: L.t(lang, 'stEffort'), value: profile.preferredEffort),
        const SizedBox(height: 30),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: onBack, child: Text(L.t(lang, 'back'))),
          _InkButton(label: L.t(lang, 'obStart'), onTap: onFinish, color: AppTheme.coral),
        ]),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontFamily: AppTheme.mono,
                fontSize: 9.5,
                letterSpacing: 1.8,
                color: AppTheme.inkFaint)),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontSize: 16.5,
                height: 1.3,
                color: AppTheme.ink)),
        const DashedRule(),
      ]),
    );
  }
}
