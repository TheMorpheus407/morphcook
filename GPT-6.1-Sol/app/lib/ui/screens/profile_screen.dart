import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

Future<String?> pickIngredient(BuildContext context) =>
    kitchenSheet<String>(context, const IngredientPicker());

class IngredientPicker extends StatefulWidget {
  const IngredientPicker({super.key});
  @override
  State<IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends State<IngredientPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final results = state.repository.dictionary.search(
      query,
      state.profile.lang,
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          const SizedBox(height: 10),
          const SizedBox(width: 35, child: Divider(thickness: 3)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              autofocus: true,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: t(context, 'ingredientHint'),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              addAutomaticKeepAlives: false,
              itemBuilder: (context, index) {
                final ingredient = results[index];
                return ListTile(
                  title: Text(
                    textFor(context, ingredient.name),
                    style: mono(13, color: KitchenColors.ink),
                  ),
                  trailing: const Icon(Icons.add, size: 18),
                  onTap: () => Navigator.pop(context, ingredient.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DietFields extends StatelessWidget {
  final Profile draft;
  final VoidCallback onChanged;
  const DietFields({super.key, required this.draft, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final ontology = AppScope.of(context).repository.ontology;
    final flags = (ontology.json['contains_flags'] as Map).keys.cast<String>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t(context, 'diet'), style: serif(22, italic: true)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ontology.diets
              .map(
                (diet) => ChoiceChip(
                  label: Text(textFor(context, ontology.label('diets', diet))),
                  selected: draft.diet == diet,
                  onSelected: (_) {
                    ontology.applyDiet(draft, diet);
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
        if (draft.diet == 'halal' || draft.diet == 'kosher') ...[
          const SizedBox(height: 12),
          NoteCard(
            child: Text(t(context, 'certificationNote'), style: mono(11)),
          ),
        ],
        const SizedBox(height: 28),
        Text(t(context, 'requiredAttributes'), style: serif(22, italic: true)),
        const SizedBox(height: 8),
        Text(t(context, 'requiredAttributesBody'), style: mono(11)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: ['halal', 'kosher', 'keto']
              .map(
                (attribute) => FilterChip(
                  label: Text(
                    textFor(context, ontology.label('diets', attribute)),
                  ),
                  selected: draft.requiredAttributes.contains(attribute),
                  onSelected: (value) {
                    if (value) {
                      draft.requiredAttributes.add(attribute);
                    } else {
                      draft.requiredAttributes.remove(attribute);
                    }
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
        if (draft.requiredAttributes.contains('halal') ||
            draft.requiredAttributes.contains('kosher')) ...[
          const SizedBox(height: 12),
          NoteCard(
            child: Text(t(context, 'certificationNote'), style: mono(11)),
          ),
        ],
        const SizedBox(height: 28),
        Text(t(context, 'allergies'), style: serif(22, italic: true)),
        const SizedBox(height: 8),
        Text(t(context, 'allergiesNote'), style: mono(11)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 3,
          children: flags
              .map(
                (flag) => FilterChip(
                  label: Text(
                    textFor(context, ontology.label('contains_flags', flag)),
                  ),
                  selected: draft.avoidFlags.contains(flag),
                  onSelected: (value) {
                    if (value) {
                      draft.avoidFlags.add(flag);
                    } else {
                      draft.avoidFlags.remove(flag);
                    }
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        Text(t(context, 'specificAvoidance'), style: serif(22, italic: true)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: draft.avoidIngredients
              .map(
                (id) => InputChip(
                  label: Text(
                    textFor(
                      context,
                      AppScope.of(
                            context,
                          ).repository.dictionary.entries[id]?.name ??
                          {'en': id, 'de': id},
                    ),
                  ),
                  onDeleted: () {
                    draft.avoidIngredients.remove(id);
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
        OutlinedButton.icon(
          onPressed: () async {
            final id = await pickIngredient(context);
            if (id != null) {
              draft.avoidIngredients.add(id);
              onChanged();
            }
          },
          icon: const Icon(Icons.add, size: 18),
          label: Text(t(context, 'avoidIngredient')),
        ),
      ],
    );
  }
}

class TargetFields extends StatelessWidget {
  final Profile draft;
  final VoidCallback onChanged;
  const TargetFields({super.key, required this.draft, required this.onChanged});
  Widget _slider(
    BuildContext context,
    String key,
    int value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChange,
    String display,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              t(context, key),
              style: mono(12, color: KitchenColors.ink),
            ),
          ),
          Text(display, style: hand(24)),
        ],
      ),
      Slider(
        value: value.toDouble().clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        label: display,
        onChanged: onChange,
      ),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final ontology = AppScope.of(context).repository.ontology;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _slider(
          context,
          'timeBudget',
          draft.maxTimeMinutes,
          10,
          120,
          22,
          (value) {
            draft.maxTimeMinutes = value.round();
            onChanged();
          },
          t(context, 'minutes', {'count': draft.maxTimeMinutes}),
        ),
        const SizedBox(height: 15),
        _slider(
          context,
          'calorieTarget',
          draft.calorieTarget,
          200,
          1200,
          20,
          (value) {
            draft.calorieTarget = value.round();
            onChanged();
          },
          t(context, 'kcal', {'count': draft.calorieTarget}),
        ),
        _slider(
          context,
          'calorieTolerance',
          draft.calorieTolerance,
          50,
          500,
          9,
          (value) {
            draft.calorieTolerance = value.round();
            onChanged();
          },
          '±${draft.calorieTolerance}',
        ),
        Text(
          t(context, 'calorieRange', {
            'min': (draft.calorieTarget - draft.calorieTolerance).clamp(
              0,
              10000,
            ),
            'max': draft.calorieTarget + draft.calorieTolerance,
          }),
          style: mono(11),
        ),
        const SizedBox(height: 30),
        Text(t(context, 'preferredEffort'), style: serif(22, italic: true)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: ['easy', 'medium', 'hard']
              .map(
                (value) => ChoiceChip(
                  label: Text(
                    textFor(context, ontology.valueLabel('effort', value)),
                  ),
                  selected: draft.preferredEffort == value,
                  onSelected: (_) {
                    draft.preferredEffort = value;
                    onChanged();
                  },
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Profile? draft;
  final nameController = TextEditingController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (draft == null) {
      draft = AppScope.of(context).profile.copy();
      nameController.text = draft!.name;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PaperScaffold(
    appBar: KitchenAppBar(title: t(context, 'profile')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Text(t(context, 'myKitchen'), style: serif(34, italic: true)),
        const SizedBox(height: 24),
        TextField(
          controller: nameController,
          maxLength: 100,
          decoration: InputDecoration(labelText: t(context, 'name')),
          onChanged: (value) => draft!.name = value.trim(),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: draft!.lang,
          decoration: InputDecoration(labelText: t(context, 'language')),
          items: ['en', 'de']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(t(context, value == 'en' ? 'english' : 'german')),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => draft!.lang = value!),
        ),
        const SizedBox(height: 30),
        const DashedRule(),
        const SizedBox(height: 25),
        DietFields(draft: draft!, onChanged: () => setState(() {})),
        const SizedBox(height: 30),
        const DashedRule(),
        const SizedBox(height: 25),
        Text(t(context, 'targets'), style: serif(25, italic: true)),
        const SizedBox(height: 22),
        TargetFields(draft: draft!, onChanged: () => setState(() {})),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () async {
            if (draft!.name.trim().isEmpty) {
              toast(context, 'nameRequired');
              return;
            }
            final state = AppScope.of(context);
            state.updateProfile(draft!);
            try {
              await state.flush();
            } catch (_) {
              return;
            }
            if (context.mounted) {
              toast(context, 'profileSaved');
              Navigator.pop(context);
            }
          },
          child: Text(t(context, 'save')),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );
}
