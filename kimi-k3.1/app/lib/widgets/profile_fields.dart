import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/content.dart';
import '../models/profile.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'paper_widgets.dart';

class DietFields extends StatefulWidget {
  const DietFields({super.key, required this.profile, required this.onChanged});
  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  State<DietFields> createState() => _DietFieldsState();
}

class _DietFieldsState extends State<DietFields> {
  final TextEditingController ingredientController = TextEditingController();
  final FocusNode ingredientFocusNode = FocusNode();

  @override
  void dispose() {
    ingredientController.dispose();
    ingredientFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<AppState>().repository;
    final avoids = repository.ontology.avoidFlags.values.toList()
      ..sort((a, b) => a.name[context.lang].compareTo(b.name[context.lang]));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.t('allergies_note'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ...avoids.map((flag) {
          final selected = widget.profile.avoidFlags.contains(flag.id);
          return CheckboxListTile(
            value: selected,
            onChanged: (value) => _toggleAvoid(flag.id, value == true),
            title: Text(flag.name[context.lang]),
            subtitle: flag.expandsTo.isNotEmpty
                ? Text(
                    flag.expandsTo
                            .take(5)
                            .map((id) => id.replaceAll('-', ' '))
                            .join(' · ') +
                        (flag.expandsTo.length > 5 ? '…' : ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : null,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.teal,
            checkboxShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.11),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.teal),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.l10n.t('halal_note'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const DashedRule(),
        const SizedBox(height: 8),
        Text(
          context.l10n.t('avoid_ingredients'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        Autocomplete<IngredientEntry>(
          textEditingController: ingredientController,
          focusNode: ingredientFocusNode,
          displayStringForOption: (entry) => entry.name[context.lang],
          optionsBuilder: (value) => repository.ingredients
              .search(value.text, context.lang)
              .where(
                (entry) => !widget.profile.avoidIngredients.contains(entry.id),
              )
              .take(8),
          onSelected: (entry) {
            widget.onChanged(
              widget.profile.copyWith(
                avoidIngredients: {
                  ...widget.profile.avoidIngredients,
                  entry.id,
                },
              ),
            );
            ingredientController.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
              TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText: context.l10n.t('ingredient_typeahead'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: IconButton(
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: context.l10n.t('clear'),
                  ),
                ),
                onSubmitted: (_) => onSubmitted(),
              ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              color: AppColors.paperLight,
              elevation: 4,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 260,
                  maxWidth: 360,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final entry = options.elementAt(index);
                    return ListTile(
                      dense: true,
                      title: Text(entry.name[context.lang]),
                      subtitle: entry.ancestorIds.isEmpty
                          ? null
                          : Text(entry.ancestorIds.last.replaceAll('-', ' ')),
                      onTap: () => onSelected(entry),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.profile.avoidIngredients.isEmpty)
          Text(
            context.l10n.t('no_ingredients_avoided'),
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: widget.profile.avoidIngredients.map((id) {
              final name =
                  repository.ingredients.entries[id]?.name[context.lang] ?? id;
              return InputChip(
                label: Text(name),
                onDeleted: () {
                  final avoided = {...widget.profile.avoidIngredients}
                    ..remove(id);
                  widget.onChanged(
                    widget.profile.copyWith(avoidIngredients: avoided),
                  );
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  void _toggleAvoid(String id, bool selected) {
    final flags = {...widget.profile.avoidFlags};
    final required = {...widget.profile.requiredAttributes};
    if (selected) {
      flags.add(id);
      if (id == 'halal' || id == 'kosher') required.add(id);
    } else {
      flags.remove(id);
      required.remove(id);
    }
    widget.onChanged(
      widget.profile.copyWith(avoidFlags: flags, requiredAttributes: required),
    );
  }
}

class PreferenceFields extends StatelessWidget {
  const PreferenceFields({
    super.key,
    required this.profile,
    required this.onChanged,
  });
  final Profile profile;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final attributes = context.watch<AppState>().repository.ontology.attributes;
    String attribute(String id) => attributes[id]?.name[context.lang] ?? id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SliderLabel(
          label: context.l10n.t('calorie_target'),
          value: '${profile.calorieTarget} kcal',
        ),
        Slider(
          value: profile.calorieTarget.toDouble(),
          min: 250,
          max: 1200,
          divisions: 19,
          label: '${profile.calorieTarget} kcal',
          onChanged: (value) =>
              onChanged(profile.copyWith(calorieTarget: value.round())),
        ),
        _SliderLabel(
          label: context.l10n.t('calorie_tolerance'),
          value: '± ${profile.calorieTolerance} kcal',
        ),
        Slider(
          value: profile.calorieTolerance.toDouble(),
          min: 0,
          max: 300,
          divisions: 6,
          label: '± ${profile.calorieTolerance}',
          onChanged: (value) =>
              onChanged(profile.copyWith(calorieTolerance: value.round())),
        ),
        _SliderLabel(
          label: context.l10n.t('time_budget'),
          value: context.l10n.t('minutes', {
            'count': '${profile.maxTimeMinutes}',
          }),
        ),
        Slider(
          value: profile.maxTimeMinutes.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          label: '${profile.maxTimeMinutes} min',
          onChanged: (value) =>
              onChanged(profile.copyWith(maxTimeMinutes: value.round())),
        ),
        const SizedBox(height: 15),
        Text(
          context.l10n.t('preferred_effort'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: ['easy', 'medium', 'hard']
                .map(
                  (id) => ButtonSegment(value: id, label: Text(attribute(id))),
                )
                .toList(),
            selected: {profile.preferredEffort},
            onSelectionChanged: (selection) =>
                onChanged(profile.copyWith(preferredEffort: selection.first)),
          ),
        ),
      ],
    );
  }
}

class _SliderLabel extends StatelessWidget {
  const _SliderLabel({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      ),
      Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.teal),
      ),
    ],
  );
}
