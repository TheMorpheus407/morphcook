import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/profile.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';

/// Editor for the dual avoidance model (SPEC):
/// - compound ways of eating (vegan, halal, low-fodmap …)
/// - class avoidance pills (dairy, nuts, gluten …)
/// - specific ingredient typeahead backed by the dictionary tree
/// - positive requirements (halal/kosher-style attributes)
/// Mutates the passed working-copy [profile] and calls [onChanged].
class DietEditor extends StatelessWidget {
  const DietEditor({super.key, required this.profile, required this.onChanged});

  final Profile profile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final ontology = state.corpus.ontology;
    final lang = state.lang;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context.tr('onb.diet.compound')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final compound in ontology.compounds)
              SelectablePill(
                label: ontology.flagLabel(compound.id, lang),
                selected: profile.avoidFlags.contains(compound.id),
                onTap: () => _toggleFlag(compound.id),
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _label(context.tr('onb.diet.classFlags')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final flag in ontology.flags)
              SelectablePill(
                label: ontology.flagLabel(flag.id, lang),
                selected: profile.avoidFlags.contains(flag.id),
                onTap: () => _toggleFlag(flag.id),
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _label(context.tr('onb.diet.specific')),
        _SpecificAvoidField(
          onPicked: (id) {
            if (profile.avoidIngredients.add(id)) onChanged();
          },
        ),
        if (profile.avoidIngredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in profile.avoidIngredients)
                  InputChip(
                    label: Text(
                      state.corpus.ingredients.nameOf(id, lang),
                      style: AppFonts.mono(size: 11, color: AppColors.inkSoft),
                    ),
                    onDeleted: () {
                      profile.avoidIngredients.remove(id);
                      onChanged();
                    },
                    deleteIconColor: AppColors.coral,
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(color: AppColors.inkFaint),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        _label(context.tr('onb.diet.required')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final attr in ['halal', 'kosher'])
              SelectablePill(
                label: ontology.attrLabel(attr, lang),
                selected: profile.requiredAttributes.contains(attr),
                onTap: () => _toggleRequired(attr),
                compact: true,
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('set.halalNote'),
          style: AppFonts.hand(size: 16, color: AppColors.inkSoft, height: 1.3),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: AppFonts.mono(size: 10, color: AppColors.coral, letterSpacing: 1.4),
        ),
      );

  void _toggleFlag(String id) {
    if (profile.avoidFlags.contains(id)) {
      profile.avoidFlags.remove(id);
    } else {
      profile.avoidFlags.add(id);
    }
    onChanged();
  }

  void _toggleRequired(String id) {
    if (profile.requiredAttributes.contains(id)) {
      profile.requiredAttributes.remove(id);
    } else {
      profile.requiredAttributes.add(id);
    }
    onChanged();
  }
}
/// The typeahead for specific ingredient avoidance — searches the bundled
/// dictionary tree in the current language.
class _SpecificAvoidField extends StatefulWidget {
  const _SpecificAvoidField({required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  State<_SpecificAvoidField> createState() => _SpecificAvoidFieldState();
}

class _SpecificAvoidFieldState extends State<_SpecificAvoidField> {
  final _controller = TextEditingController();
  List<_DictHit> _hits = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    final state = context.read<AppState>();
    if (query.trim().length < 2) {
      setState(() => _hits = const []);
      return;
    }
    final nodes = state.corpus.ingredients.search(query, state.lang, limit: 6);
    setState(() {
      _hits = nodes
          .map((n) => _DictHit(
                id: n.id,
                label: state.corpus.ingredients.nameOf(n.id, state.lang),
              ))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _onChanged,
          style: AppFonts.serif(size: 15),
          decoration: InputDecoration(
            hintText: context.tr('onb.diet.specificHint'),
            hintStyle: AppFonts.mono(size: 11, color: AppColors.inkFaint),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkFaint),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.teal),
            ),
            isDense: true,
          ),
        ),
        for (final hit in _hits)
          InkWell(
            onTap: () {
              widget.onPicked(hit.id);
              _controller.clear();
              setState(() => _hits = const []);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(hit.label, style: AppFonts.serif(size: 14)),
                  const Spacer(),
                  Text('＋', style: AppFonts.mono(size: 12, color: AppColors.teal)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DictHit {
  const _DictHit({required this.id, required this.label});

  final String id;
  final String label;
}
