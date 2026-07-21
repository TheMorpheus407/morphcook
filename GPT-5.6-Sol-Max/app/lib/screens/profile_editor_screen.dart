import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/content.dart';
import '../models/localized_text.dart';
import '../models/profile.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';
import 'faq_screen.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late UserProfile _draft;
  late TextEditingController _name;
  final _ingredientSearch = TextEditingController();
  var _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _draft = context.read<AppController>().profile;
      _name = TextEditingController(text: _draft.name);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _ingredientSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final lang = _draft.language;
    final ingredientMatches = app.ontology.searchIngredients(
      _ingredientSearch.text,
      lang,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(Copy.text('profile', lang)),
        actions: [
          IconButton(
            tooltip: Copy.text('help', lang),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FaqScreen(initialCategory: 'dietary'),
              ),
            ),
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 34),
          children: [
            _title(Copy.text('name', lang)),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: Copy.text('name_hint', lang),
              ),
            ),
            _title(Copy.text('diet_style', lang)),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['vegan', 'vegetarian', 'pescatarian']
                  .map(
                    (value) => FilterChip(
                      label: Text(_label(value, lang)),
                      selected: _draft.avoidFlags.contains(value),
                      onSelected: (_) => setState(() {
                        final flags = {..._draft.avoidFlags};
                        flags.contains(value)
                            ? flags.remove(value)
                            : flags.add(value);
                        _draft = _draft.copyWith(avoidFlags: flags);
                      }),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: ['halal', 'kosher'].map((value) {
                final selected = _draft.requiredAttributes.contains(value);
                return FilterChip(
                  label: Text(_label(value, lang)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    final required = {..._draft.requiredAttributes};
                    selected ? required.remove(value) : required.add(value);
                    _draft = _draft.copyWith(requiredAttributes: required);
                  }),
                );
              }).toList(),
            ),
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: BrandColors.tealLight.withValues(alpha: .45),
                border: Border.all(color: BrandColors.ink),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 19),
                  const SizedBox(width: 9),
                  Expanded(child: Text(Copy.text('halal_note', lang))),
                ],
              ),
            ),
            _title(Copy.text('allergies', lang)),
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
                    final selected = _draft.avoidFlags.contains(value);
                    return FilterChip(
                      label: Text(_label(value, lang)),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        final flags = {..._draft.avoidFlags};
                        selected ? flags.remove(value) : flags.add(value);
                        _draft = _draft.copyWith(avoidFlags: flags);
                      }),
                    );
                  }).toList(),
            ),
            _title(Copy.text('specific_avoidance', lang)),
            TextField(
              controller: _ingredientSearch,
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
              children: ingredientMatches.map((IngredientNode ingredient) {
                final selected = _draft.avoidIngredients.contains(
                  ingredient.id,
                );
                return FilterChip(
                  label: Text(ingredient.name.value(lang)),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    final ingredients = {..._draft.avoidIngredients};
                    selected
                        ? ingredients.remove(ingredient.id)
                        : ingredients.add(ingredient.id);
                    _draft = _draft.copyWith(avoidIngredients: ingredients);
                  }),
                );
              }).toList(),
            ),
            _title(Copy.text('calorie_target', lang)),
            _valueRow(
              '${_draft.calorieTarget} kcal',
              '± ${_draft.calorieTolerance}',
            ),
            Slider(
              value: _draft.calorieTarget.toDouble(),
              min: 300,
              max: 1000,
              divisions: 14,
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(calorieTarget: value.round()),
              ),
            ),
            Text(
              lang == 'de'
                  ? 'Das Ziel ist ein fester Filter mit ± ${_draft.calorieTolerance} kcal Toleranz. Am Gericht kannst du es einmalig übergehen.'
                  : 'This is a hard filter with ± ${_draft.calorieTolerance} kcal tolerance. You can override it on an individual dish.',
            ),
            _title(Copy.text('time_budget', lang)),
            _valueRow('${_draft.maxTimeMinutes} min', ''),
            Slider(
              value: _draft.maxTimeMinutes.toDouble(),
              min: 15,
              max: 120,
              divisions: 7,
              onChanged: (value) => setState(
                () => _draft = _draft.copyWith(maxTimeMinutes: value.round()),
              ),
            ),
            _title(Copy.text('effort', lang)),
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
              selected: {_draft.preferredEffort},
              onSelectionChanged: (values) => setState(
                () => _draft = _draft.copyWith(preferredEffort: values.first),
              ),
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: () async {
                final value = _draft.copyWith(name: _name.text.trim());
                await app.updateProfile(value);
                if (context.mounted) {
                  showPaperSnack(context, Copy.text('saved', lang));
                  Navigator.pop(context);
                }
              },
              child: Text(Copy.text('save', lang).toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: 27, bottom: 9),
    child: Row(
      children: [
        Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(width: 10),
        const Expanded(child: DashedRule()),
      ],
    ),
  );

  Widget _valueRow(String first, String second) => Row(
    children: [
      Text(first, style: Theme.of(context).textTheme.headlineMedium),
      const Spacer(),
      Text(second, style: Theme.of(context).textTheme.labelMedium),
    ],
  );

  String _label(String value, String lang) {
    return context.read<AppController>().ontology.label(value, lang);
  }
}
