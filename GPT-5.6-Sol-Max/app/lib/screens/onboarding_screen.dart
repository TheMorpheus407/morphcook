import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/content.dart';
import '../models/localized_text.dart';
import '../models/profile.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _ingredientController = TextEditingController();
  var _step = 0;
  var _profile = const UserProfile();
  String? _dietStyle;

  String get lang => _profile.language;

  @override
  void dispose() {
    _nameController.dispose();
    _ingredientController.dispose();
    super.dispose();
  }

  void _next() {
    FocusScope.of(context).unfocus();
    if (_step == 1) {
      _profile = _profile.copyWith(name: _nameController.text.trim());
    }
    if (_step < 4) {
      setState(() => _step++);
    } else {
      context.read<AppController>().finishOnboarding(_profile);
    }
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step > 0) setState(() => _step--);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: PaperBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    Text(
                      'MorphCook',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${_step + 1} / 5',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: LinearProgressIndicator(
                  value: (_step + 1) / 5,
                  minHeight: 3,
                  color: BrandColors.coral,
                  backgroundColor: BrandColors.paperDeep,
                  borderRadius: BorderRadius.zero,
                ),
              ),
              const SizedBox(height: 4),
              const DashedRule(),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduce
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(key: ValueKey(_step), child: _page()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _back,
                          child: Text(Copy.text('back', lang).toUpperCase()),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _canContinue ? _next : null,
                        child: Text(
                          Copy.text(
                            _step == 4 ? 'open_cookbook' : 'continue',
                            lang,
                          ).toUpperCase(),
                        ),
                      ),
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

  bool get _canContinue => _step != 1 || _nameController.text.trim().isNotEmpty;

  Widget _page() => switch (_step) {
    0 => _languagePage(),
    1 => _namePage(),
    2 => _dietPage(),
    3 => _limitsPage(),
    _ => _confirmPage(),
  };

  Widget _pageFrame({
    required String title,
    String? note,
    required List<Widget> children,
  }) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(22, 38, 22, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.displayMedium),
        if (note != null) ...[
          const SizedBox(height: 14),
          Text(note, style: Theme.of(context).textTheme.bodyLarge),
        ],
        const SizedBox(height: 30),
        ...children,
      ],
    ),
  );

  Widget _languagePage() => _pageFrame(
    title: Copy.text('onboarding_language_title', lang),
    note: Copy.text('onboarding_language_note', lang),
    children: [
      _LanguageChoice(
        title: 'English',
        note: 'the kitchen speaks English',
        selected: lang == 'en',
        onTap: () =>
            setState(() => _profile = _profile.copyWith(language: 'en')),
      ),
      const SizedBox(height: 14),
      _LanguageChoice(
        title: 'Deutsch',
        note: 'die küche spricht deutsch',
        selected: lang == 'de',
        onTap: () =>
            setState(() => _profile = _profile.copyWith(language: 'de')),
      ),
    ],
  );

  Widget _namePage() => _pageFrame(
    title: Copy.text('onboarding_name_title', lang),
    children: [
      TextField(
        controller: _nameController,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        maxLength: 40,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: Copy.text('name', lang).toUpperCase(),
          hintText: Copy.text('name_hint', lang),
          prefixIcon: const Icon(Icons.edit_outlined),
        ),
      ),
      const SizedBox(height: 22),
      Transform.rotate(
        angle: -.025,
        child: Text(
          lang == 'de'
              ? 'dein name kommt oben auf jede ausgabe.'
              : 'your name goes at the top of every edition.',
          style: const TextStyle(
            fontFamily: 'Caveat',
            fontSize: 26,
            color: BrandColors.coral,
          ),
        ),
      ),
    ],
  );

  Widget _dietPage() {
    final ontology = context.read<AppController>().ontology;
    final query = _ingredientController.text;
    final matches = ontology.searchIngredients(query, lang);
    return _pageFrame(
      title: Copy.text('onboarding_diet_title', lang),
      note: Copy.text('onboarding_diet_note', lang),
      children: [
        _smallTitle(Copy.text('diet_style', lang)),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: ['vegan', 'vegetarian', 'pescatarian']
              .map(
                (value) => ChoiceChip(
                  label: Text(_dietLabel(value)),
                  selected: _dietStyle == value,
                  onSelected: (selected) => setState(() {
                    final flags = {..._profile.avoidFlags}
                      ..removeAll(['vegan', 'vegetarian', 'pescatarian']);
                    _dietStyle = selected ? value : null;
                    if (selected) flags.add(value);
                    _profile = _profile.copyWith(avoidFlags: flags);
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        _smallTitle(lang == 'de' ? 'WERTE' : 'VALUES'),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: ['halal', 'kosher'].map((value) {
            final selected = _profile.requiredAttributes.contains(value);
            return FilterChip(
              label: Text(_dietLabel(value)),
              selected: selected,
              onSelected: (_) => setState(() {
                final attributes = {..._profile.requiredAttributes};
                selected ? attributes.remove(value) : attributes.add(value);
                _profile = _profile.copyWith(requiredAttributes: attributes);
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          Copy.text('halal_note', lang),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: BrandColors.fadedInk),
        ),
        const SizedBox(height: 20),
        _smallTitle(Copy.text('allergies', lang)),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children:
              [
                'dairy',
                'nuts',
                'shellfish',
                'gluten',
                'egg',
                'soy',
                'sesame',
                'mustard',
                'celery',
                'lupin',
                'sulphites',
                'alcohol',
                'caffeine',
                'low-fodmap',
                'sugar-free',
                'lactose-free',
              ].map((value) {
                final selected = _profile.avoidFlags.contains(value);
                return FilterChip(
                  label: Text(_allergyLabel(value)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    final flags = {..._profile.avoidFlags};
                    selected ? flags.remove(value) : flags.add(value);
                    _profile = _profile.copyWith(avoidFlags: flags);
                  }),
                );
              }).toList(),
        ),
        const SizedBox(height: 24),
        _smallTitle(Copy.text('specific_avoidance', lang)),
        TextField(
          controller: _ingredientController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: Copy.text('ingredient_search_hint', lang),
            prefixIcon: const Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: matches.map((IngredientNode item) {
            final selected = _profile.avoidIngredients.contains(item.id);
            return FilterChip(
              label: Text(item.name.value(lang)),
              selected: selected,
              onSelected: (_) => setState(() {
                final ingredients = {..._profile.avoidIngredients};
                selected
                    ? ingredients.remove(item.id)
                    : ingredients.add(item.id);
                _profile = _profile.copyWith(avoidIngredients: ingredients);
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _limitsPage() => _pageFrame(
    title: Copy.text('onboarding_limits_title', lang),
    children: [
      _sliderLabel(
        Copy.text('calorie_target', lang),
        '${_profile.calorieTarget} kcal',
      ),
      Slider(
        value: _profile.calorieTarget.toDouble(),
        min: 300,
        max: 1000,
        divisions: 14,
        label: '${_profile.calorieTarget}',
        onChanged: (value) => setState(
          () => _profile = _profile.copyWith(calorieTarget: value.round()),
        ),
      ),
      const SizedBox(height: 18),
      _sliderLabel(
        Copy.text('time_budget', lang),
        '${_profile.maxTimeMinutes} min',
      ),
      Slider(
        value: _profile.maxTimeMinutes.toDouble(),
        min: 15,
        max: 120,
        divisions: 7,
        label: '${_profile.maxTimeMinutes}',
        onChanged: (value) => setState(
          () => _profile = _profile.copyWith(maxTimeMinutes: value.round()),
        ),
      ),
      const SizedBox(height: 22),
      _smallTitle(Copy.text('effort', lang)),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: ['easy', 'medium', 'hard']
            .map(
              (value) => ButtonSegment(
                value: value,
                label: Text(Copy.text(value, lang)),
              ),
            )
            .toList(),
        selected: {_profile.preferredEffort},
        onSelectionChanged: (value) => setState(
          () => _profile = _profile.copyWith(preferredEffort: value.first),
        ),
      ),
    ],
  );

  Widget _confirmPage() => _pageFrame(
    title: Copy.text('confirm_title', lang),
    note: Copy.text('confirm_note', lang),
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F5EA),
          border: Border.all(color: BrandColors.ink, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _nameController.text.trim(),
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const DashedRule(),
            const SizedBox(height: 12),
            _summaryLine(Icons.schedule, '${_profile.maxTimeMinutes} min'),
            _summaryLine(
              Icons.local_fire_department_outlined,
              '${_profile.calorieTarget} kcal ± ${_profile.calorieTolerance}',
            ),
            _summaryLine(
              Icons.restaurant_menu,
              Copy.text(_profile.preferredEffort, lang),
            ),
            if (_profile.avoidFlags.isNotEmpty)
              _summaryLine(
                Icons.no_food_outlined,
                _profile.avoidFlags.map(_dietLabel).join(' · '),
              ),
            if (_profile.avoidIngredients.isNotEmpty)
              _summaryLine(
                Icons.spa_outlined,
                '${_profile.avoidIngredients.length} ${Copy.text('specific_avoidance', lang).toLowerCase()}',
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Text(
        lang == 'de' ? 'dieses buch gehört dir.' : 'this book belongs to you.',
        style: const TextStyle(
          fontFamily: 'Caveat',
          fontSize: 29,
          color: BrandColors.coral,
        ),
      ),
    ],
  );

  Widget _smallTitle(String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Text(
      value.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge,
    ),
  );

  Widget _sliderLabel(String label, String value) => Row(
    children: [
      Expanded(child: _smallTitle(label)),
      Text(value, style: Theme.of(context).textTheme.labelLarge),
    ],
  );

  Widget _summaryLine(IconData icon, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: BrandColors.coral),
        const SizedBox(width: 10),
        Expanded(child: Text(value)),
      ],
    ),
  );

  String _dietLabel(String value) =>
      context.read<AppController>().ontology.label(value, lang);

  String _allergyLabel(String value) =>
      context.read<AppController>().ontology.label(value, lang);
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.title,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String note;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? BrandColors.coralLight : const Color(0xFFF9F5EA),
    shape: RoundedRectangleBorder(
      side: BorderSide(color: BrandColors.ink, width: selected ? 2 : 1.2),
    ),
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(note, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? BrandColors.coral : BrandColors.ink,
            ),
          ],
        ),
      ),
    ),
  );
}
