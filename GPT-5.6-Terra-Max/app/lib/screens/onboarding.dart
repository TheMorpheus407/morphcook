import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../copy.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _ingredientSearch = TextEditingController();
  var _step = 0;
  var _draft = Profile.fresh();
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _draft = MorphCookScope.of(context).profile;
    _name.text = _draft.name;
    _ready = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _ingredientSearch.dispose();
    super.dispose();
  }

  String get _lang => _draft.lang;
  String _t(String key) => Copybook.t(key, _lang);

  void _toggleFlag(String flag) {
    final values = {..._draft.avoidFlags};
    if (!values.add(flag)) values.remove(flag);
    setState(() => _draft = _draft.copyWith(avoidFlags: values));
  }

  void _toggleIngredient(String id) {
    final values = {..._draft.avoidIngredients};
    if (!values.add(id)) values.remove(id);
    setState(() => _draft = _draft.copyWith(avoidIngredients: values));
  }

  Future<void> _next() async {
    if (_step == 1) {
      _draft = _draft.copyWith(name: _name.text.trim());
    }
    if (_step < 4) {
      setState(() => _step++);
    } else {
      await MorphCookScope.of(context).completeOnboarding(_draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Masthead(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: List.generate(
                5,
                (index) => Expanded(
                  child: Container(
                    height: 3,
                    margin: EdgeInsets.only(right: index == 4 ? 0 : 5),
                    color: index <= _step
                        ? MorphColors.coral
                        : MorphColors.paperDeep,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: SingleChildScrollView(
                key: ValueKey(_step),
                padding: const EdgeInsets.fromLTRB(20, 34, 20, 18),
                child: _buildStep(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: [
                if (_step > 0)
                  TextButton(
                    onPressed: () => setState(() => _step--),
                    child: Text(_t('back')),
                  ),
                const Spacer(),
                InkButton(
                  label: _step == 4 ? _t('ready') : _t('next'),
                  icon: _step == 4 ? Icons.auto_stories : Icons.arrow_forward,
                  onPressed: _next,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case 0:
        return _languageStep(context);
      case 1:
        return _nameStep(context);
      case 2:
        return _dietStep(context);
      case 3:
        return _goalsStep(context);
      default:
        return _confirmStep(context);
    }
  }

  Widget _headline(BuildContext context, String headline, String subhead) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline, style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 13),
          Text(subhead, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 32),
        ],
      );

  Widget _languageStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _headline(context, _t('pickLanguage'), _t('welcome')),
      _ChoiceTile(
        selected: _draft.lang == 'en',
        title: 'English',
        subtitle: 'hello, darling kitchen',
        onTap: () => setState(() => _draft = _draft.copyWith(lang: 'en')),
      ),
      const SizedBox(height: 12),
      _ChoiceTile(
        selected: _draft.lang == 'de',
        title: 'Deutsch',
        subtitle: 'hallo, liebe küche',
        onTap: () => setState(() => _draft = _draft.copyWith(lang: 'de')),
      ),
    ],
  );

  Widget _nameStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _headline(context, _t('whatCallYou'), _t('welcome')),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        style: Theme.of(context).textTheme.titleLarge,
        decoration: InputDecoration(labelText: _t('name'), hintText: 'Mara'),
      ),
      const SizedBox(height: 17),
      Text(
        _lang == 'de'
            ? 'Nur auf diesem Gerät. Kein Konto, kein Sammeln, kein Lärm.'
            : 'Only on this device. No account, no collecting, no noise.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: MorphColors.mutedInk),
      ),
    ],
  );

  Widget _dietStep(BuildContext context) {
    final state = MorphCookScope.of(context);
    final suggestions = state.repository.ingredientIndex.search(
      _ingredientSearch.text,
      _lang,
    );
    final flags = <String>[
      'vegan',
      'vegetarian',
      'pescatarian',
      'dairy',
      'gluten',
      'nuts',
      'halal',
      'kosher',
      'low-fodmap',
      'sugar-free',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(
          context,
          _t('dietQuestion'),
          _lang == 'de'
              ? 'Wir entfernen keine Gerichte. Wir zeigen dir die vollständig geschriebenen, passenden Versionen.'
              : 'We do not erase dishes. We show their fully written, right-for-you versions.',
        ),
        Text(
          _t('avoid').toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: flags
              .map(
                (flag) => FilterChip(
                  label: Text(_flagLabel(flag)),
                  selected: _draft.avoidFlags.contains(flag),
                  selectedColor: MorphColors.coral.withValues(alpha: .17),
                  checkmarkColor: MorphColors.coral,
                  onSelected: (_) => _toggleFlag(flag),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        Text(
          _t('specificAvoid').toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ingredientSearch,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: _lang == 'de'
                ? 'z. B. Koriander, Äpfel, Paprika'
                : 'e.g. cilantro, apples, bell peppers',
          ),
        ),
        if (_draft.avoidIngredients.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _draft.avoidIngredients.map((id) {
              final item = state.repository.ingredients[id];
              return InputChip(
                label: Text(item?.nameFor(_lang) ?? id),
                onDeleted: () => _toggleIngredient(id),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 7),
        ...suggestions
            .take(6)
            .map(
              (ingredient) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(ingredient.nameFor(_lang)),
                subtitle: ingredient.parentId == null
                    ? null
                    : Text(
                        state.repository.ingredients[ingredient.parentId]
                                ?.nameFor(_lang) ??
                            '',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                trailing: Icon(
                  _draft.avoidIngredients.contains(ingredient.id)
                      ? Icons.check_circle
                      : Icons.add_circle_outline,
                  color: _draft.avoidIngredients.contains(ingredient.id)
                      ? MorphColors.coral
                      : MorphColors.mutedInk,
                ),
                onTap: () => _toggleIngredient(ingredient.id),
              ),
            ),
        const SizedBox(height: 20),
        Text(
          _t('requirements').toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 7),
        FilterChip(
          label: Text(_t('halal')),
          selected: _draft.requiredAttributes.contains('halal'),
          onSelected: (selected) {
            final required = {..._draft.requiredAttributes};
            if (selected) {
              required.add('halal');
            } else {
              required.remove('halal');
            }
            setState(
              () => _draft = _draft.copyWith(requiredAttributes: required),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          _t('halalNote'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: MorphColors.mutedInk),
        ),
      ],
    );
  }

  Widget _goalsStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _headline(
        context,
        _t('goalsQuestion'),
        _lang == 'de'
            ? 'Du kannst das später jederzeit in den Einstellungen ändern.'
            : 'You can change every one of these in settings later.',
      ),
      _sliderRow(
        context,
        _t('timeBudget'),
        '${_draft.maxTimeMinutes} min',
        Slider(
          value: _draft.maxTimeMinutes.toDouble(),
          min: 15,
          max: 90,
          divisions: 5,
          activeColor: MorphColors.teal,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(maxTimeMinutes: value.round()),
          ),
        ),
      ),
      const SizedBox(height: 18),
      _sliderRow(
        context,
        _t('calorieTarget'),
        '${_draft.calorieTarget} kcal',
        Slider(
          value: _draft.calorieTarget.toDouble(),
          min: 400,
          max: 900,
          divisions: 5,
          activeColor: MorphColors.coral,
          onChanged: (value) => setState(
            () => _draft = _draft.copyWith(calorieTarget: value.round()),
          ),
        ),
      ),
      const SizedBox(height: 25),
      Text(
        _t('preferredEffort').toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: ['easy', 'medium', 'hard']
            .map(
              (effort) => ChoiceChip(
                label: Text(_t(effort)),
                selected: _draft.preferredEffort == effort,
                selectedColor: MorphColors.teal.withValues(alpha: .17),
                onSelected: (_) => setState(
                  () => _draft = _draft.copyWith(preferredEffort: effort),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );

  Widget _sliderRow(
    BuildContext context,
    String label,
    String value,
    Widget slider,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
      slider,
    ],
  );

  Widget _confirmStep(BuildContext context) {
    final state = MorphCookScope.of(context);
    final names = _draft.avoidIngredients
        .map((id) => state.repository.ingredients[id]?.nameFor(_lang) ?? id)
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(
          context,
          _t('confirmQuestion'),
          _lang == 'de'
              ? 'Hier ist die kleine Notiz, nach der MorphCook für dich arbeitet.'
              : 'Here is the small note MorphCook will use to cook for you.',
        ),
        _SummaryNote(
          label: _t('name'),
          value: _draft.name.isEmpty ? '—' : _draft.name,
        ),
        _SummaryNote(
          label: _t('avoid'),
          value:
              [
                ..._draft.avoidFlags.map(_flagLabel),
                if (names.isNotEmpty) names,
              ].join(' · ').isEmpty
              ? (_lang == 'de' ? 'nichts ausgewählt' : 'nothing selected')
              : [
                  ..._draft.avoidFlags.map(_flagLabel),
                  if (names.isNotEmpty) names,
                ].join(' · '),
        ),
        _SummaryNote(
          label: _t('timeBudget'),
          value: '${_draft.maxTimeMinutes} min',
        ),
        _SummaryNote(
          label: _t('calorieTarget'),
          value: '${_draft.calorieTarget} kcal',
        ),
        const SizedBox(height: 25),
        StripePlaceholder(
          color: MorphColors.teal,
          caption: _lang == 'de'
              ? 'dein Rezeptbuch wartet bereits'
              : 'your cookbook is already waiting',
          height: 165,
        ),
      ],
    );
  }

  String _flagLabel(String flag) {
    switch (flag) {
      case 'dairy':
        return _lang == 'de' ? 'milchprodukte' : 'dairy';
      case 'gluten':
        return 'gluten';
      case 'nuts':
        return _lang == 'de' ? 'nüsse' : 'nuts';
      case 'vegetarian':
        return _lang == 'de' ? 'vegetarisch' : 'vegetarian';
      case 'pescatarian':
        return _lang == 'de' ? 'pescetarisch' : 'pescatarian';
      case 'low-fodmap':
        return 'low-FODMAP';
      case 'sugar-free':
        return _lang == 'de' ? 'zuckerfrei' : 'sugar-free';
      default:
        return _t(flag);
    }
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? MorphColors.teal.withValues(alpha: .12)
        : Colors.white.withValues(alpha: .42),
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? MorphColors.teal : const Color(0xffa79b89),
            width: selected ? 1.4 : .8,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? MorphColors.teal : MorphColors.mutedInk,
            ),
          ],
        ),
      ),
    ),
  );
}

class _SummaryNote extends StatelessWidget {
  const _SummaryNote({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .42),
      border: Border.all(color: const Color(0xffb3a593)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 3),
        Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
