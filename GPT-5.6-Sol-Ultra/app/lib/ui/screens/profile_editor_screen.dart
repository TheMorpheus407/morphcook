import 'package:flutter/material.dart';

import '../../domain/models/ingredient.dart';
import '../../domain/models/user_profile.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({
    required this.profile,
    required this.ingredients,
    required this.hasMatchingRecipe,
    required this.onSave,
    super.key,
    this.onOpenMatchingFaq,
  });

  final UserProfile profile;
  final IngredientDictionary ingredients;
  final bool Function(UserProfile profile) hasMatchingRecipe;
  final Future<void> Function(UserProfile profile) onSave;
  final VoidCallback? onOpenMatchingFaq;

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late UserProfile _profile = widget.profile;
  late final TextEditingController _name = TextEditingController(
    text: widget.profile.name,
  );
  var _ingredientQuery = '';
  var _saving = false;

  bool get _canSave =>
      _name.text.trim().isNotEmpty && widget.hasMatchingRecipe(_profile);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _diet {
    for (final diet in const ['vegan', 'vegetarian', 'pescatarian']) {
      if (_profile.avoidFlags.contains(diet)) return diet;
    }
    for (final diet in const ['halal', 'kosher']) {
      if (_profile.requiredAttributes.contains(diet)) return diet;
    }
    return null;
  }

  void _setDiet(String? value) {
    final avoids = _profile.avoidFlags.difference({
      'vegan',
      'vegetarian',
      'pescatarian',
    });
    final required = _profile.requiredAttributes.difference({
      'halal',
      'kosher',
    });
    if (const {'vegan', 'vegetarian', 'pescatarian'}.contains(value)) {
      avoids.add(value!);
    }
    if (value == 'halal' || value == 'kosher') required.add(value!);
    setState(() {
      _profile = _profile.copyWith(
        avoidFlags: avoids,
        requiredAttributes: required,
      );
    });
  }

  void _toggleFlag(String flag) {
    final next = {..._profile.avoidFlags};
    final linkedFlags = flag == 'shellfish'
        ? const {'shellfish', 'molluscs'}
        : {flag};
    final selected = linkedFlags.any(next.contains);
    selected ? next.removeAll(linkedFlags) : next.addAll(linkedFlags);
    setState(() => _profile = _profile.copyWith(avoidFlags: next));
  }

  void _toggleIngredient(String id) {
    final next = {..._profile.avoidIngredientIds};
    next.contains(id) ? next.remove(id) : next.add(id);
    setState(() => _profile = _profile.copyWith(avoidIngredientIds: next));
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_profile.copyWith(name: _name.text.trim()));
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = widget.ingredients.search(
      _ingredientQuery,
      languageCode: _profile.languageCode,
      limit: 8,
    );
    const diets = [
      null,
      'vegan',
      'vegetarian',
      'pescatarian',
      'halal',
      'kosher',
    ];
    const flags = [
      'dairy',
      'gluten',
      'nuts',
      'shellfish',
      'egg',
      'soy',
      'sesame',
    ];
    return MorphStringsScope(
      languageCode: _profile.languageCode,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(context.strings('settings.profile')),
            actions: [
              TextButton(
                onPressed: _saving || !_canSave ? null : _save,
                child: Text(context.strings('common.save')),
              ),
            ],
          ),
          body: PaperSurface(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                SectionHeading(title: context.strings('settings.aboutYou')),
                TextField(
                  controller: _name,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: context.strings('onboarding.name.hint'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'en',
                      label: Text(
                        context.strings('onboarding.language.english'),
                      ),
                    ),
                    ButtonSegment(
                      value: 'de',
                      label: Text(
                        context.strings('onboarding.language.german'),
                      ),
                    ),
                  ],
                  selected: {_profile.languageCode},
                  onSelectionChanged: (selected) => setState(
                    () => _profile = _profile.copyWith(
                      languageCode: selected.first,
                    ),
                  ),
                ),
                SectionHeading(title: context.strings('onboarding.diet.title')),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final diet in diets)
                      MorphTag(
                        label: context.strings('diet.${diet ?? 'none'}'),
                        selected: _diet == diet,
                        onSelected: (_) => _setDiet(diet),
                      ),
                  ],
                ),
                if (_diet == 'halal' || _diet == 'kosher') ...[
                  const SizedBox(height: 12),
                  Semantics(
                    button: widget.onOpenMatchingFaq != null,
                    onTap: widget.onOpenMatchingFaq,
                    label:
                        '${context.strings('settings.compatibleNote')} ${context.strings('settings.compatibleLearnMore')}',
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: widget.onOpenMatchingFaq,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${context.strings('settings.compatibleNote')}\n${context.strings('settings.compatibleLearnMore')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                SectionHeading(
                  title: context.strings('onboarding.avoidClasses'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final flag in flags)
                      MorphTag(
                        label: context.strings('avoid.$flag'),
                        selected: flag == 'shellfish'
                            ? _profile.avoidFlags.any(
                                const {'shellfish', 'molluscs'}.contains,
                              )
                            : _profile.avoidFlags.contains(flag),
                        onSelected: (_) => _toggleFlag(flag),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) =>
                      setState(() => _ingredientQuery = value),
                  decoration: InputDecoration(
                    labelText: context.strings('onboarding.specific'),
                    hintText: context.strings('onboarding.specificHint'),
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                if (results.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: context.morph.ink.withValues(alpha: .35),
                      ),
                    ),
                    child: Column(
                      children: [
                        for (final ingredient in results)
                          CheckboxListTile(
                            dense: true,
                            title: Text(
                              ingredient.name.resolve(_profile.languageCode),
                            ),
                            value: _profile.avoidIngredientIds.contains(
                              ingredient.id,
                            ),
                            onChanged: (_) => _toggleIngredient(ingredient.id),
                          ),
                      ],
                    ),
                  ),
                if (_profile.avoidIngredientIds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    children: [
                      for (final id in _profile.avoidIngredientIds)
                        InputChip(
                          label: Text(
                            widget.ingredients[id]?.name.resolve(
                                  _profile.languageCode,
                                ) ??
                                id,
                          ),
                          onDeleted: () => _toggleIngredient(id),
                        ),
                    ],
                  ),
                ],
                SectionHeading(
                  title: context.strings('onboarding.goals.title'),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.strings('onboarding.calories').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Text(
                      '${_profile.calorieTarget} kcal',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                Slider(
                  min: 300,
                  max: 1000,
                  divisions: 14,
                  value: _profile.calorieTarget.toDouble(),
                  onChanged: (value) => setState(
                    () => _profile = _profile.copyWith(
                      calorieTarget: (value / 50).round() * 50,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.strings('onboarding.tolerance').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Text('± ${_profile.calorieTolerance} kcal'),
                  ],
                ),
                Slider(
                  min: 50,
                  max: 300,
                  divisions: 5,
                  value: _profile.calorieTolerance.toDouble(),
                  onChanged: (value) => setState(
                    () => _profile = _profile.copyWith(
                      calorieTolerance: value.round(),
                    ),
                  ),
                ),
                Text(
                  context.strings('onboarding.time').toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7,
                  children: [
                    for (final minutes in const [15, 30, 45, 60, 90])
                      MorphTag(
                        label: context.strings.format('common.recipeMinutes', {
                          'minutes': minutes,
                        }),
                        selected: _profile.maxTimeMinutes == minutes,
                        onSelected: (_) => setState(
                          () => _profile = _profile.copyWith(
                            maxTimeMinutes: minutes,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  context.strings('onboarding.effort').toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 9),
                SegmentedButton<String>(
                  segments: [
                    for (final effort in const ['easy', 'medium', 'hard'])
                      ButtonSegment(
                        value: effort,
                        label: Text(context.strings('effort.$effort')),
                      ),
                  ],
                  selected: {_profile.preferredEffort},
                  onSelectionChanged: (selected) => setState(
                    () => _profile = _profile.copyWith(
                      preferredEffort: selected.first,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (!widget.hasMatchingRecipe(_profile)) ...[
                  Text(
                    context.strings('onboarding.noMatch'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.morph.coral,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                InkButton(
                  label: context.strings('common.save'),
                  icon: Icons.check_rounded,
                  expand: true,
                  onPressed: _saving || !_canSave ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
