import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../core/palette.dart';
import '../core/paper.dart';
import '../state/app_state.dart';

/// Onboarding: language → name → diet & allergies →
/// calorie target + time budget → confirm.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _step = 0;

  String _lang = 'en';
  final TextEditingController _name = TextEditingController();
  final Set<String> _diets = {};
  final Set<String> _avoidIngredients = {};
  final TextEditingController _typeahead = TextEditingController();
  int _calorieTarget = 600;
  int _maxTime = 60;
  String _effort = 'medium';

  @override
  void dispose() {
    _page.dispose();
    _name.dispose();
    _typeahead.dispose();
    super.dispose();
  }

  void _go(int step) {
    setState(() => _step = step);
    _page.animateToPage(
      step,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() {
    final ontology = context.read<AppStore>();
    final corpus = context.read<Corpus>();
    final avoids = corpus.ontology.expandAll(_diets);
    final required = <String>{
      if (_diets.contains('halal')) 'halal-compatible',
      if (_diets.contains('kosher')) 'kosher-compatible',
    };
    ontology.updateProfile(
      ontology.profile.copyWith(
        name: _name.text.trim(),
        lang: _lang,
        avoidFlags: avoids,
        avoidIngredients: _avoidIngredients,
        requiredAttributes: required,
        calorieTarget: _calorieTarget,
        calorieTolerance: 150,
        maxTimeMinutes: _maxTime,
        preferredEffort: _effort,
        onboarded: true,
      ),
    );
    ontology.setLang(_lang);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.read<LocaleController>();
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  children: [
                    Text(
                      'morphcook',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                        color: MC.ink,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_step + 1} / 5',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        letterSpacing: 2,
                        color: MC.inkFaint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const DashedOrnament(),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _languageStep(context),
                    _nameStep(context),
                    _dietStep(context, loc),
                    _budgetStep(context),
                    _confirmStep(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepShell(Widget child, {List<Widget>? footer}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          const SizedBox(height: 26),
          if (footer != null) ...footer,
        ],
      ),
    );
  }

  Widget _primary(String label, VoidCallback onTap) => ElevatedButton(
        onPressed: onTap,
        child: Text(label),
      );

  Widget _backRow() => Row(
        children: [
          TextButton(
            onPressed: () => _go(_step - 1),
            child: Text(context.t('obBack')),
          ),
          const Spacer(),
        ],
      );

  // ------------------------------------------------------------ language

  Widget _languageStep(BuildContext context) {
    return _stepShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('obStep1'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(context.t('obLanguageHint'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          _LanguageCard(
            code: 'en',
            label: 'English',
            note: 'the tumblr cookbook, original voice',
            selected: _lang == 'en',
            onTap: () => setState(() => _lang = 'en'),
          ),
          const SizedBox(height: 12),
          _LanguageCard(
            code: 'de',
            label: 'Deutsch',
            note: 'das tumblr-kochbuch, originale stimme',
            selected: _lang == 'de',
            onTap: () => setState(() => _lang = 'de'),
          ),
        ],
      ),
      footer: [_primary(context.t('next'), () => _go(1))],
    );
  }

  // ---------------------------------------------------------------- name

  Widget _nameStep(BuildContext context) {
    return _stepShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('obStep2'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(context.t('obNameHint'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.t('obNameField'),
              labelStyle: TextStyle(
                fontFamily: 'Caveat',
                fontSize: 20,
                color: MC.inkSoft,
              ),
            ),
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: MC.ink,
            ),
            onSubmitted: (_) => _go(2),
          ),
        ],
      ),
      footer: [
        _primary(
            context.t('next'),
            () => _go(2)),
        const SizedBox(height: 8),
        _backRow(),
      ],
    );
  }

  // ---------------------------------------------------------------- diet

  Widget _dietStep(BuildContext context, LocaleController loc) {
    final corpus = context.read<Corpus>();
    return _stepShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('obStep3'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(context.t('obDietHint'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final diet in corpus.ontology.compoundAvoidFlags.keys)
                FilterChip(
                  label: Text(loc.t('diet.$diet')),
                  selected: _diets.contains(diet),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _diets.add(diet);
                    } else {
                      _diets.remove(diet);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(context.t('obAvoidTitle'),
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(context.t('obAvoidHint'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _typeahead,
            decoration: InputDecoration(
              hintText: context.t('obSpecificPlaceholder'),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          if (_typeahead.text.trim().length >= 2)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: MC.card,
                border: Border.all(color: MC.rule),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final node in corpus.ingredientTree
                      .search(_typeahead.text, loc.lang)
                      .take(10))
                    ListTile(
                      dense: true,
                      title: Text(
                        loc.pick(node.name),
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13,
                          color: MC.ink,
                        ),
                      ),
                      trailing: _avoidIngredients.contains(node.id)
                          ? const Icon(Icons.check,
                              size: 16, color: MC.coral)
                          : null,
                      onTap: () => setState(() {
                        _avoidIngredients.add(node.id);
                        _typeahead.clear();
                      }),
                    ),
                ],
              ),
            ),
          if (_avoidIngredients.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in _avoidIngredients.toList())
                  InputChip(
                    label: Text(context.ingredientName(id),
                        style: const TextStyle(fontSize: 12)),
                    onDeleted: () =>
                        setState(() => _avoidIngredients.remove(id)),
                  ),
              ],
            ),
          ],
        ],
      ),
      footer: [
        _primary(context.t('next'), () => _go(3)),
        const SizedBox(height: 8),
        _backRow(),
      ],
    );
  }

  // -------------------------------------------------------------- budget

  Widget _budgetStep(BuildContext context) {
    return _stepShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('obStep4'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          Text(context.t('obCalorieHint'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$_calorieTarget',
                style: const TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: MC.coralDeep,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  context.t('kcal'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          Slider(
            value: _calorieTarget.toDouble(),
            min: 300,
            max: 1000,
            divisions: 14,
            label: '$_calorieTarget',
            onChanged: (v) => setState(() => _calorieTarget = v.round()),
          ),
          const SizedBox(height: 14),
          Text(context.t('obTimeHint'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [15, 30, 60, 90, 120])
                ChoiceChip(
                  label: Text('≤ $m ${context.t('minutes')}'),
                  selected: _maxTime == m,
                  onSelected: (_) => setState(() => _maxTime = m),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(context.t('obEffortHint'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in const ['easy', 'medium', 'hard'])
                ChoiceChip(
                  label: Text(context.t('effort.$e')),
                  selected: _effort == e,
                  onSelected: (_) => setState(() => _effort = e),
                ),
            ],
          ),
        ],
      ),
      footer: [
        _primary(context.t('next'), () => _go(4)),
        const SizedBox(height: 8),
        _backRow(),
      ],
    );
  }

  // ------------------------------------------------------------- confirm

  Widget _confirmStep(BuildContext context) {
    final corpus = context.read<Corpus>();
    final dietLabels = _diets.isEmpty
        ? [context.t('diet.none')]
        : _diets.map((d) => context.t('diet.$d')).toList();
    return _stepShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.t('obStep5'),
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(context.t('obConfirmSub'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MC.card,
              border: Border.all(color: MC.rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.text.trim().isEmpty ? '—' : _name.text.trim(),
                  style: const TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 26,
                    color: MC.ink,
                  ),
                ),
                const SizedBox(height: 12),
                _summaryLine(
                  context,
                  context.t('obStep3'),
                  dietLabels.join(' · '),
                ),
                if (_avoidIngredients.isNotEmpty)
                  _summaryLine(
                    context,
                    context.t('obAvoidTitle'),
                    _avoidIngredients
                        .map((i) => context.ingredientName(i))
                        .join(', '),
                  ),
                _summaryLine(
                  context,
                  context.t('obStep4'),
                  '$_calorieTarget ${context.t('kcal')} · ≤ $_maxTime ${context.t('minutes')} · ${context.t('effort.$_effort')}',
                ),
                _summaryLine(context, context.t('stLanguage'),
                    _lang == 'en' ? 'english' : 'deutsch'),
                if (corpus.ontology.compoundAvoidFlags.isEmpty)
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
      footer: [
        _primary(context.t('obStart'), _finish),
        const SizedBox(height: 8),
        _backRow(),
      ],
    );
  }

  Widget _summaryLine(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 9.5,
                letterSpacing: 1.2,
                color: MC.inkFaint,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 12,
                color: MC.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.code,
    required this.label,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final String label;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? MC.ink : MC.card,
          border: Border.all(color: selected ? MC.ink : MC.rule),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Text(
              code.toUpperCase(),
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? MC.card : MC.ink,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: selected ? MC.card : MC.ink,
                    ),
                  ),
                  Text(
                    note,
                    style: TextStyle(
                      fontFamily: 'Caveat',
                      fontSize: 15,
                      color: selected ? MC.inkFaint : MC.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: MC.flashCoral, size: 20),
          ],
        ),
      ),
    );
  }
}
