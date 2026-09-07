// Reusable profile pieces, shared by onboarding and the profile editor.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ingredient.dart';
import '../../data/models/profile.dart';
import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';

/// A switch row in our voice: serif title, mono subtitle.
class PaperSwitchRow extends StatelessWidget {
  const PaperSwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged, this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 6)});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.body(size: 15)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: AppText.mono(color: Palette.inkFaint, size: 11.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      );
}

/// Compound "ways of eating": vegan, vegetarian, gluten-free… (halal and
/// kosher are requirements, not avoidances, and live in [RequirementsPicker]).
class DietStylePicker extends StatelessWidget {
  const DietStylePicker({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = context.lang;
    final compounds = app.repo.ontology.compoundFlags.where((c) => c.id != 'halal' && c.id != 'kosher').toList();
    final selected = compounds.where((c) => value.avoidFlags.contains(c.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in compounds)
              PaperChip(
                label: c.label.of(lang),
                selected: value.avoidFlags.contains(c.id),
                onTap: () {
                  final next = {...value.avoidFlags};
                  if (!next.remove(c.id)) next.add(c.id);
                  onChanged(value.copyWith(avoidFlags: next));
                },
              ),
          ],
        ),
        for (final c in selected) ...[
          const SizedBox(height: 8),
          HandNote('${c.label.of(lang)} — ${c.description.of(lang)}', size: 18, color: Palette.inkFaint),
        ],
      ],
    );
  }
}

/// Class-level avoidance checklist: all dairy, all nuts, all shellfish…
class AllergenPicker extends StatelessWidget {
  const AllergenPicker({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  static const _groups = ['allergen', 'animal', 'meat', 'seafood', 'lifestyle'];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final flags = app.repo.ontology.containsFlags.where((f) => f.parent == null && _groups.contains(f.group)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in _groups)
          if (flags.any((f) => f.group == g)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: MonoLabel(s('flaggroup.$g')),
            ),
            for (final f in flags.where((f) => f.group == g))
              InkWell(
                onTap: () => _toggle(f.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Checkbox(value: value.avoidFlags.contains(f.id), onChanged: (_) => _toggle(f.id)),
                      Expanded(child: Text(f.label.of(lang), style: AppText.body(size: 14.5))),
                    ],
                  ),
                ),
              ),
          ],
      ],
    );
  }

  void _toggle(String id) {
    final next = {...value.avoidFlags};
    if (!next.remove(id)) next.add(id);
    onChanged(value.copyWith(avoidFlags: next));
  }
}

/// Typeahead against the ingredient dictionary. Picking a group covers
/// everything under it.
class SpecificAvoidanceField extends StatefulWidget {
  const SpecificAvoidanceField({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  State<SpecificAvoidanceField> createState() => _SpecificAvoidanceFieldState();
}

class _SpecificAvoidanceFieldState extends State<SpecificAvoidanceField> {
  final _controller = TextEditingController();
  List<IngredientNode> _suggestions = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    final app = context.read<AppController>();
    setState(() {
      _suggestions = q.trim().length < 2 ? const [] : app.repo.ingredients.search(q, app.lang, limit: 8);
    });
  }

  void _add(String id) {
    widget.onChanged(widget.value.copyWith(avoidIngredients: {...widget.value.avoidIngredients, id}));
    _controller.clear();
    setState(() => _suggestions = const []);
  }

  void _remove(String id) {
    final next = {...widget.value.avoidIngredients}..remove(id);
    widget.onChanged(widget.value.copyWith(avoidIngredients: next));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final dict = app.repo.ingredients;
    final selected = widget.value.avoidIngredients.toList()
      ..sort((a, b) => (dict.byId[a]?.name.of(lang) ?? a).compareTo(dict.byId[b]?.name.of(lang) ?? b));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _search,
          style: AppText.body(size: 15),
          decoration: InputDecoration(hintText: s('profile.specific.hint'), prefixIcon: const Icon(Icons.search, size: 18)),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Palette.paperLight,
              border: Border.all(color: Palette.rule),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                for (final n in _suggestions)
                  InkWell(
                    onTap: () => _add(n.id),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          Expanded(child: Text(n.name.of(lang), style: AppText.body(size: 14.5))),
                          if (n.kind == IngredientKind.category)
                            MonoLabel('+${dict.subtree(n.id).length - 1}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in selected)
                PaperChip(
                  label: dict.byId[id]?.name.of(lang) ?? id,
                  selected: true,
                  trailing: const Icon(Icons.close, size: 13, color: Palette.paper),
                  onTap: () => _remove(id),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        HandNote(s('profile.specific.note'), size: 18, color: Palette.inkFaint),
      ],
    );
  }
}

/// Positive requirements: halal-compatible / kosher-compatible ingredients.
class RequirementsPicker extends StatelessWidget {
  const RequirementsPicker({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final id in const ['halal', 'kosher'])
          PaperSwitchRow(
            title: app.repo.ontology.compoundById[id]?.label.of(lang) ?? id,
            subtitle: app.repo.ontology.compoundById[id]?.description.of(lang),
            value: value.requiredAttributes.contains(id),
            padding: const EdgeInsets.symmetric(vertical: 6),
            onChanged: (on) {
              final next = {...value.requiredAttributes};
              if (on) {
                next.add(id);
              } else {
                next.remove(id);
              }
              onChanged(value.copyWith(requiredAttributes: next));
            },
          ),
        const SizedBox(height: 8),
        PaperNote(text: s('profile.halalKosher.note'), kicker: s('profile.required')),
      ],
    );
  }
}

class CalorieTargetField extends StatelessWidget {
  const CalorieTargetField({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final target = value.calorieTarget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperSwitchRow(
          title: s('profile.calories'),
          subtitle: target == null ? s('onb.targets.caloriesOff') : '$target kcal · ± ${value.calorieTolerance} kcal',
          value: target != null,
          padding: const EdgeInsets.symmetric(vertical: 4),
          onChanged: (on) => onChanged(value.copyWith(calorieTarget: on ? 600 : null)),
        ),
        if (target != null) ...[
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: target.clamp(300, 1200).toDouble(),
                  min: 300,
                  max: 1200,
                  divisions: 18,
                  onChanged: (v) => onChanged(value.copyWith(calorieTarget: v.round())),
                ),
              ),
              SizedBox(width: 74, child: Text('$target kcal', textAlign: TextAlign.end, style: AppText.mono(size: 12))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: MonoLabel(s('profile.tolerance')),
          ),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.calorieTolerance.clamp(50, 300).toDouble(),
                  min: 50,
                  max: 300,
                  divisions: 10,
                  onChanged: (v) => onChanged(value.copyWith(calorieTolerance: v.round())),
                ),
              ),
              SizedBox(width: 74, child: Text('± ${value.calorieTolerance}', textAlign: TextAlign.end, style: AppText.mono(size: 12))),
            ],
          ),
        ],
      ],
    );
  }
}

class TimeBudgetField extends StatelessWidget {
  const TimeBudgetField({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final minutes = value.maxTimeMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PaperSwitchRow(
          title: s('profile.time'),
          subtitle: minutes == null ? s('onb.targets.timeOff') : '$minutes min',
          value: minutes != null,
          padding: const EdgeInsets.symmetric(vertical: 4),
          onChanged: (on) => onChanged(value.copyWith(maxTimeMinutes: on ? 45 : null)),
        ),
        if (minutes != null)
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: minutes.clamp(10, 180).toDouble(),
                  min: 10,
                  max: 180,
                  divisions: 34,
                  onChanged: (v) => onChanged(value.copyWith(maxTimeMinutes: v.round())),
                ),
              ),
              SizedBox(width: 74, child: Text('$minutes min', textAlign: TextAlign.end, style: AppText.mono(size: 12))),
            ],
          ),
      ],
    );
  }
}

class EffortPicker extends StatelessWidget {
  const EffortPicker({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = context.lang;
    final efforts = app.repo.ontology.efforts;
    final current = efforts.where((e) => e.id == value.preferredEffort).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in efforts)
              PaperChip(
                label: e.label.of(lang),
                selected: value.preferredEffort == e.id,
                onTap: () => onChanged(value.copyWith(preferredEffort: e.id)),
              ),
          ],
        ),
        if (current.isNotEmpty && current.first.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          HandNote(current.first.description.of(lang), size: 18, color: Palette.inkFaint),
        ],
      ],
    );
  }
}

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, required this.value, required this.onChanged});
  final Profile value;
  final ValueChanged<Profile> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final code in const ['en', 'de'])
          PaperChip(
            label: s('lang.$code'),
            selected: value.lang == code,
            onTap: () => onChanged(value.copyWith(lang: code)),
          ),
      ],
    );
  }
}
