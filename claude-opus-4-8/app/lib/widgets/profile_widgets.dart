import 'package:flutter/material.dart';

import '../core/context_ext.dart';
import '../models/ingredient_dict.dart';
import '../models/ontology.dart';
import '../theme/app_theme.dart';
import 'decor.dart';

/// Toggle chips for the ontology's compound diet flags (vegan, vegetarian,
/// halal, kosher, low-fodmap…). Selecting a chip adds that compound flag to the
/// profile's [Profile.avoidFlags]. Each chip shows the flag's localized label,
/// with its description as a tooltip and a small subtitle.
///
/// Reusable between onboarding and settings — give it the current set and an
/// onChanged that hands back the next set.
class DietPicker extends StatelessWidget {
  const DietPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final flags = context.scope.corpus.ontology.compoundFlags;
    if (flags.isEmpty) {
      return HandNote(
        context.lang.code == 'de' ? 'nichts einzustellen' : 'nothing to set',
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final flag in flags) _chip(context, flag)],
    );
  }

  Widget _chip(BuildContext context, CompoundFlag flag) {
    final isOn = selected.contains(flag.id);
    final label = context.loc(flag.label);
    final description = context.loc(flag.description);

    return Tooltip(
      message: description,
      waitDuration: const Duration(milliseconds: 400),
      child: GestureDetector(
        onTap: () {
          final next = Set<String>.from(selected);
          isOn ? next.remove(flag.id) : next.add(flag.id);
          onChanged(next);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 220),
          decoration: BoxDecoration(
            color: isOn ? AppColors.terracotta.withValues(alpha: 0.10) : null,
            border: Border.all(
              color: isOn ? AppColors.terracotta : AppColors.inkSoft,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOn)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check,
                          size: 13, color: AppColors.terracotta),
                    ),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: Fonts.mono,
                        fontSize: 13,
                        color: isOn ? AppColors.terracotta : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: Fonts.hand,
                  fontSize: 14,
                  color: AppColors.inkFaint,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A typeahead field that searches the ingredient dictionary and lets the user
/// build a set of specific avoided ingredient node ids
/// ([Profile.avoidIngredients]). Currently-avoided ingredients render above the
/// field as removable chips. Class avoidance (the [DietPicker]) and this
/// specific avoidance combine — the helper copy says so.
class IngredientAvoidanceField extends StatefulWidget {
  const IngredientAvoidanceField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<IngredientAvoidanceField> createState() =>
      _IngredientAvoidanceFieldState();
}

class _IngredientAvoidanceFieldState extends State<IngredientAvoidanceField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<IngredientNode> _results = const [];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQuery(String q) {
    final dict = context.scope.corpus.ingredients;
    setState(() {
      _results = dict
          .search(q, context.lang)
          .where((n) => !widget.selected.contains(n.id))
          .toList();
    });
  }

  void _add(IngredientNode node) {
    final next = Set<String>.from(widget.selected)..add(node.id);
    widget.onChanged(next);
    _controller.clear();
    setState(() => _results = const []);
    // keep focus so the user can add several in a row without re-tapping
    _focus.requestFocus();
  }

  void _remove(String id) {
    final next = Set<String>.from(widget.selected)..remove(id);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final de = context.lang.code == 'de';
    final dict = context.scope.corpus.ingredients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in widget.selected)
                _avoidedChip(context, id, dict),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onQuery,
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontSize: 16,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: de ? 'eine Zutat suchen…' : 'search an ingredient…',
            hintStyle: const TextStyle(
              fontFamily: Fonts.display,
              fontStyle: FontStyle.italic,
              fontSize: 16,
              color: AppColors.inkFaint,
            ),
            prefixIcon:
                const Icon(Icons.search, size: 18, color: AppColors.inkSoft),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkFaint),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.terracotta),
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppColors.paperDeep.withValues(alpha: 0.5),
              border: Border.all(color: AppColors.inkFaint.withValues(alpha: 0.6)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Column(
              children: [
                for (final node in _results)
                  InkWell(
                    onTap: () => _add(node),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          const Icon(Icons.add,
                              size: 15, color: AppColors.inkSoft),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.loc(node.label),
                              style: const TextStyle(
                                fontFamily: Fonts.display,
                                fontSize: 15,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (!node.isLeaf)
                            Text(
                              de ? 'gruppe' : 'group',
                              style: const TextStyle(
                                fontFamily: Fonts.mono,
                                fontSize: 10,
                                letterSpacing: 1.2,
                                color: AppColors.inkFaint,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          de
              ? 'Klassen oben und einzelne Zutaten hier wirken zusammen — beides wird gemieden.'
              : 'Diet classes above and single ingredients here work together — both are avoided.',
          style: const TextStyle(
            fontFamily: Fonts.hand,
            fontSize: 15,
            color: AppColors.inkFaint,
            height: 1.05,
          ),
        ),
      ],
    );
  }

  Widget _avoidedChip(BuildContext context, String id, IngredientDict dict) {
    final node = dict.node(id);
    final label = node != null ? context.loc(node.label) : id;
    return GestureDetector(
      onTap: () => _remove(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.clay.withValues(alpha: 0.10),
          border: Border.all(color: AppColors.clay.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontFamily: Fonts.mono,
                fontSize: 12,
                color: AppColors.clay,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.close, size: 13, color: AppColors.clay),
          ],
        ),
      ),
    );
  }
}

/// A small reusable selector for effort mood (easy / medium / hard), driven by
/// `corpus.ontology.effort`. Maps to [Profile.preferredEffort].
class EffortMoodPicker extends StatelessWidget {
  const EffortMoodPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final efforts = context.scope.corpus.ontology.effort;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in efforts)
          _chip(context, e.id, context.loc(e.label), selected == e.id),
      ],
    );
  }

  Widget _chip(BuildContext context, String id, String label, bool isOn) {
    return GestureDetector(
      onTap: () => onChanged(id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isOn ? AppColors.terracotta.withValues(alpha: 0.10) : null,
          border: Border.all(
            color: isOn ? AppColors.terracotta : AppColors.inkSoft,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: Fonts.mono,
            fontSize: 13,
            color: isOn ? AppColors.terracotta : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
