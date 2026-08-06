import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../data/profile.dart';
import '../../state/app_model.dart';
import '../widgets.dart';
import 'ingredient_typeahead.dart';

/// Onboarding: language → name → diet & allergies → calorie target +
/// time budget → confirm.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pages = PageController();
  final Profile _draft = Profile();
  int _page = 0;

  void _next() {
    if (_page == 0) {
      // Language chosen: rebuild strings immediately.
      context.read<AppModel>().setLang(_draft.lang);
    }
    if (_page < 4) {
      _pages.nextPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pages.previousPage(
          duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
      setState(() => _page--);
    }
  }

  Future<void> _finish() async {
    final app = context.read<AppModel>();
    await app.replaceProfile(_draft);
    await app.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings(_draft.lang);
    return PaperGrain(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                child: Row(
                  children: [
                    if (_page > 0)
                      GestureDetector(
                        onTap: _back,
                        child: Text('← ${s.get('back')}',
                            style:
                                Type.mono(size: 11, color: Paper.inkSoft)),
                      ),
                    const Spacer(),
                    Text('${_page + 1} / 5',
                        style: Type.mono(size: 11, color: Paper.inkFaint)),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _LanguagePage(
                        draft: _draft,
                        s: s,
                        onChanged: () {
                          setState(() {});
                          context.read<AppModel>().setLang(_draft.lang);
                        },
                      ),
                    _NamePage(
                        draft: _draft, s: s, onChanged: () => setState(() {})),
                    _DietPage(draft: _draft, s: s),
                    _BudgetPage(draft: _draft, s: s),
                    _ConfirmPage(draft: _draft, s: s),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: PaperButton(
                      label: _page == 4
                          ? s.get('confirm')
                          : s.get('continue_'),
                      onTap: _page == 1 && _draft.name.trim().isEmpty
                          ? null
                          : _next,
                    ),
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

class _PageFrame extends StatelessWidget {
  final String kicker;
  final String title;
  final String? note;
  final Widget child;
  const _PageFrame({
    required this.kicker,
    required this.title,
    this.note,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker.toUpperCase(), style: Type.label(color: Paper.coral)),
          const SizedBox(height: 10),
          Text(title, style: Type.displayBold(size: 30)),
          if (note != null) ...[
            const SizedBox(height: 10),
            Text(note!, style: Type.mono(size: 11.5, color: Paper.inkSoft)),
          ],
          const SizedBox(height: 26),
          child,
        ],
      ),
    );
  }
}

class _LanguagePage extends StatelessWidget {
  final Profile draft;
  final Strings s;
  final VoidCallback onChanged;
  const _LanguagePage(
      {required this.draft, required this.s, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setState) {
      return _PageFrame(
        kicker: 'morphcook',
        title: s.get('chooseLanguage'),
        note: s.get('onboardingIntro'),
        child: Column(
          children: [
            for (final (lang, label) in [
              (AppLang.en, 'English'),
              (AppLang.de, 'Deutsch'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () {
                    draft.lang = lang;
                    onChanged();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: draft.lang == lang ? Paper.ink : Paper.white,
                      border: Border.all(color: Paper.ink),
                    ),
                    child: Text(
                      label,
                      style: Type.mono(
                        size: 13,
                        color:
                            draft.lang == lang ? Paper.white : Paper.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _NamePage extends StatefulWidget {
  final Profile draft;
  final Strings s;
  final VoidCallback onChanged;
  const _NamePage(
      {required this.draft, required this.s, required this.onChanged});

  @override
  State<_NamePage> createState() => _NamePageState();
}

class _NamePageState extends State<_NamePage> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.draft.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      kicker: '01 · ${widget.s.get('name')}',
      title: widget.s.get('whatShouldWeCallYou'),
      child: PaperField(
        controller: _controller,
        hint: widget.s.get('name'),
        onChanged: (v) {
          widget.draft.name = v;
          setState(() {});
          widget.onChanged();
        },
      ),
    );
  }
}

class _DietPage extends StatefulWidget {
  final Profile draft;
  final Strings s;
  const _DietPage({required this.draft, required this.s});

  @override
  State<_DietPage> createState() => _DietPageState();
}

class _DietPageState extends State<_DietPage> {
  final TextEditingController _typeahead = TextEditingController();

  @override
  void dispose() {
    _typeahead.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<CorpusRepository>();
    final ontology = corpus.ontology;
    final lang = widget.draft.lang;

    final compounds = ontology.compoundExpansions.keys.toList();
    final classFlags = [
      'dairy', 'gluten', 'egg', 'peanuts', 'tree-nuts', 'soy',
      'shellfish', 'fish', 'sesame', 'mustard', 'celery', 'pork',
      'alcohol', 'honey',
    ];

    return _PageFrame(
      kicker: '02 · ${widget.s.get('dietAndAllergies')}',
      title: widget.s.get('howDoYouEat'),
      note: widget.s.get('allergyNote'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              for (final flag in compounds)
                PaperChip(
                  label: tx(ontology.compoundLabels[flag], lang),
                  selected: widget.draft.avoidFlags.contains(flag),
                  onTap: () => setState(() {
                    widget.draft.avoidFlags.contains(flag)
                        ? widget.draft.avoidFlags.remove(flag)
                        : widget.draft.avoidFlags.add(flag);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const DashedLine(),
          const SizedBox(height: 14),
          Wrap(
            children: [
              for (final flag in classFlags)
                PaperChip(
                  label: tx(ontology.containsFlags[flag], lang),
                  selected: widget.draft.avoidFlags.contains(flag),
                  onTap: () => setState(() {
                    widget.draft.avoidFlags.contains(flag)
                        ? widget.draft.avoidFlags.remove(flag)
                        : widget.draft.avoidFlags.add(flag);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(widget.s.get('specificAvoidNote'),
              style: Type.mono(size: 11, color: Paper.inkSoft)),
          const SizedBox(height: 8),
          IngredientTypeahead(
            controller: _typeahead,
            dictionary: corpus.ingredients,
            lang: lang,
            selected: widget.draft.avoidIngredients,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 18),
          Text(widget.s.get('halalKosherNote'),
              style: Type.mono(size: 10, color: Paper.inkFaint)),
          const SizedBox(height: 8),
          Wrap(children: [
            PaperChip(
              label: 'halal',
              selected: widget.draft.requiredAttributes.contains('halal'),
              onTap: () => setState(() {
                if (widget.draft.requiredAttributes.contains('halal')) {
                  widget.draft.requiredAttributes.remove('halal');
                } else {
                  widget.draft.requiredAttributes.clear();
                  widget.draft.requiredAttributes.add('halal');
                }
              }),
            ),
            PaperChip(
              label: 'kosher',
              selected: widget.draft.requiredAttributes.contains('kosher'),
              onTap: () => setState(() {
                if (widget.draft.requiredAttributes.contains('kosher')) {
                  widget.draft.requiredAttributes.remove('kosher');
                } else {
                  widget.draft.requiredAttributes.clear();
                  widget.draft.requiredAttributes.add('kosher');
                }
              }),
            ),
          ]),
        ],
      ),
    );
  }
}

class _BudgetPage extends StatefulWidget {
  final Profile draft;
  final Strings s;
  const _BudgetPage({required this.draft, required this.s});

  @override
  State<_BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<_BudgetPage> {
  static const calorieSteps = [0, 400, 500, 600, 700, 800];
  static const timeSteps = [0, 15, 20, 30, 45, 60, 90];

  @override
  Widget build(BuildContext context) {
    final calorieIndex = calorieSteps
        .indexWhere((c) => c == (widget.draft.calorieTarget ?? 0));
    final timeIndex = timeSteps
        .indexWhere((t) => t == (widget.draft.maxTimeMinutes ?? 0));

    return _PageFrame(
      kicker: '03 · ${widget.s.get('yourDay')}',
      title: widget.s.get('calorieTarget'),
      note: widget.s.get('calorieNote'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.draft.calorieTarget == null
                ? widget.s.get('off')
                : '~${widget.draft.calorieTarget} ${widget.s.get('kcal')}',
            style: Type.display(size: 24),
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
              value: (calorieIndex < 0 ? 0 : calorieIndex).toDouble(),
              min: 0,
              max: (calorieSteps.length - 1).toDouble(),
              divisions: calorieSteps.length - 1,
              onChanged: (v) => setState(() {
                final target = calorieSteps[v.round()];
                widget.draft.calorieTarget = target == 0 ? null : target;
              }),
            ),
          ),
          const SizedBox(height: 26),
          Text(widget.s.get('timeNote'),
              style: Type.mono(size: 11.5, color: Paper.inkSoft)),
          const SizedBox(height: 8),
          Text(
            widget.draft.maxTimeMinutes == null
                ? widget.s.get('noLimit')
                : '${widget.draft.maxTimeMinutes} ${widget.s.get('minutes')}',
            style: Type.display(size: 24),
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
              value: (timeIndex < 0 ? 0 : timeIndex).toDouble(),
              min: 0,
              max: (timeSteps.length - 1).toDouble(),
              divisions: timeSteps.length - 1,
              onChanged: (v) => setState(() {
                final t = timeSteps[v.round()];
                widget.draft.maxTimeMinutes = t == 0 ? null : t;
              }),
            ),
          ),
          const SizedBox(height: 26),
          Text(widget.s.get('preferredEffort'),
              style: Type.mono(size: 11.5, color: Paper.inkSoft)),
          const SizedBox(height: 8),
          Wrap(children: [
            for (final effort in ['easy', 'medium', 'hard'])
              PaperChip(
                label: tx(context
                        .read<CorpusRepository>()
                        .ontology
                        .effortLabels[effort],
                    widget.draft.lang),
                selected: widget.draft.preferredEffort == effort,
                onTap: () =>
                    setState(() => widget.draft.preferredEffort = effort),
              ),
          ]),
        ],
      ),
    );
  }
}

class _ConfirmPage extends StatelessWidget {
  final Profile draft;
  final Strings s;
  const _ConfirmPage({required this.draft, required this.s});

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<CorpusRepository>();
    final lang = draft.lang;
    return _PageFrame(
      kicker: '04 · ${s.get('confirm')}',
      title: '${s.get('welcome')}, ${draft.name.trim()}.',
      note: s.get('confirmNote'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(s.get('dietAndAllergies'),
              draft.avoidFlags.isEmpty && draft.avoidIngredients.isEmpty
                  ? '—'
                  : [
                      ...draft.avoidFlags.map(
                          (f) => tx(corpus.ontology.compoundLabels[f] ??
                              corpus.ontology.containsFlags[f], lang)),
                      ...draft.avoidIngredients.map((i) =>
                          tx(corpus.ingredients[i]?.name, lang)),
                    ].join(', ')),
          _summaryRow(
              s.get('calorieTarget'),
              draft.calorieTarget == null
                  ? s.get('off')
                  : '~${draft.calorieTarget} kcal'),
          _summaryRow(
              s.get('timeBudget'),
              draft.maxTimeMinutes == null
                  ? s.get('noLimit')
                  : '${draft.maxTimeMinutes} min'),
          _summaryRow(s.get('preferredEffort'),
              tx(corpus.ontology.effortLabels[draft.preferredEffort], lang)),
          const SizedBox(height: 30),
          Text(s.get('aboutCorpus'),
              style: Type.mono(size: 10, color: Paper.inkFaint)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Type.label()),
          const SizedBox(height: 4),
          Text(value, style: Type.mono(size: 12.5)),
        ],
      ),
    );
  }
}
