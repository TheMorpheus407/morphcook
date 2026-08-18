import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';

/// Full profile editor: name, avoids (class + specific), budgets.
class ProfileEditorScreen extends StatefulWidget {
  const ProfileEditorScreen({super.key});

  @override
  State<ProfileEditorScreen> createState() => _ProfileEditorScreenState();
}

class _ProfileEditorScreenState extends State<ProfileEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _typeahead;
  late Set<String> _diets;
  late Set<String> _avoidIngredients;
  late int _calorieTarget;
  late int _maxTime;
  late String _effort;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppStore>().profile;
    _name = TextEditingController(text: profile.name);
    _typeahead = TextEditingController();
    _avoidIngredients = profile.avoidIngredients.toSet();

    // Recover compound diets from expanded avoid flags.
    final ontology = context.read<Corpus>().ontology;
    _diets = {};
    for (final entry in ontology.compoundAvoidFlags.entries) {
      final expanded = entry.value;
      if (expanded.isNotEmpty &&
          profile.avoidFlags.containsAll(expanded)) {
        _diets.add(entry.key);
      }
    }
    // Exact match guard: only claim a diet if we avoid at least its core.
    _diets = _diets.where((d) => ontology.expand(d).isNotEmpty).toSet();

    _calorieTarget = profile.calorieTarget;
    _maxTime = profile.maxTimeMinutes;
    _effort = profile.preferredEffort;
  }

  @override
  void dispose() {
    _name.dispose();
    _typeahead.dispose();
    super.dispose();
  }

  void _save() {
    final store = context.read<AppStore>();
    final corpus = context.read<Corpus>();
    final avoids = corpus.ontology.expandAll(_diets);
    final required = <String>{
      if (_diets.contains('halal')) 'halal-compatible',
      if (_diets.contains('kosher')) 'kosher-compatible',
    };
    store.updateProfile(store.profile.copyWith(
      name: _name.text.trim(),
      avoidFlags: avoids,
      avoidIngredients: _avoidIngredients,
      requiredAttributes: required,
      calorieTarget: _calorieTarget,
      maxTimeMinutes: _maxTime,
      preferredEffort: _effort,
    ));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final loc = context.read<LocaleController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('stProfile')),
        actions: [
          TextButton(onPressed: _save, child: Text(context.t('save'))),
        ],
      ),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextField(
              controller: _name,
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
                fontSize: 20,
                fontStyle: FontStyle.italic,
                color: MC.ink,
              ),
            ),
            const SizedBox(height: 20),
            Text(context.t('obStep3'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final diet in corpus.ontology.compoundAvoidFlags.keys)
                  FilterChip(
                    label: Text(loc.t('diet.$diet')),
                    selected: _diets.contains(diet),
                    onSelected: (v) => setState(() {
                      v ? _diets.add(diet) : _diets.remove(diet);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(context.t('obAvoidTitle'),
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            TextField(
              controller: _typeahead,
              decoration: InputDecoration(
                hintText: context.t('obSpecificPlaceholder'),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_typeahead.text.trim().length >= 2)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
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
                        .take(8))
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
                        onTap: () => setState(() {
                          _avoidIngredients.add(node.id);
                          _typeahead.clear();
                        }),
                      ),
                  ],
                ),
              ),
            if (_avoidIngredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in _avoidIngredients.toList())
                    InputChip(
                      label: Text(
                        context.ingredientName(id),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onDeleted: () =>
                          setState(() => _avoidIngredients.remove(id)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text(context.t('obCalorieHint'),
                style: Theme.of(context).textTheme.bodySmall),
            Row(
              children: [
                Text(
                  '$_calorieTarget',
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: MC.coralDeep,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(context.t('kcal'),
                      style: Theme.of(context).textTheme.titleSmall),
                ),
              ],
            ),
            Slider(
              value: _calorieTarget.toDouble(),
              min: 300,
              max: 1000,
              divisions: 14,
              onChanged: (v) =>
                  setState(() => _calorieTarget = v.round()),
            ),
            const SizedBox(height: 12),
            Text(context.t('obTimeHint'),
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in const [15, 30, 60, 90, 120])
                  ChoiceChip(
                    label: Text('≤ $m ${context.t('minutes')}'),
                    selected: _maxTime == m,
                    onSelected: (_) => setState(() => _maxTime = m),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
      ),
    );
  }
}
