import 'package:flutter/material.dart' hide Typography;
import 'package:provider/provider.dart';

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import '../state/app_state.dart';
import 'controls.dart';

/// Specific-ingredient avoidance typeahead, backed by the ingredient
/// dictionary. Picks any tree level; avoidance propagation to descendants is
/// automatic at match time.
class IngredientTypeahead extends StatefulWidget {
  final String lang;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String hint;

  const IngredientTypeahead({
    super.key,
    required this.lang,
    required this.selected,
    required this.onChanged,
    required this.hint,
  });

  @override
  State<IngredientTypeahead> createState() => _IngredientTypeaheadState();
}

class _IngredientTypeaheadState extends State<IngredientTypeahead> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<AppState>().corpus;
    final matches = _query.isEmpty
        ? const <String>[]
        : corpus.ingredients.searchable
            .where((n) => !widget.selected.contains(n.id))
            .where((n) => n.name.resolve(widget.lang).toLowerCase().contains(_query))
            .take(6)
            .map((n) => n.id)
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in widget.selected)
              PaperChip(
                label: corpus.ingredients.nameOf(id, widget.lang),
                selected: true,
                onTap: () {
                  final next = {...widget.selected}..remove(id);
                  widget.onChanged(next);
                },
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          focusNode: _focus,
          style: Typography.hand(20),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: Typography.hand(20, color: Palette.inkFaint),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.line, width: 1.4)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Palette.ink, width: 1.4)),
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        if (matches.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Palette.paper,
              border: Border.all(color: Palette.line),
            ),
            child: Column(
              children: [
                for (final id in matches)
                  ListTile(
                    dense: true,
                    title: Text(corpus.ingredients.nameOf(id, widget.lang),
                        style: Typography.body(15, italic: true)),
                    trailing: Icon(Icons.add, size: 16, color: Palette.teal),
                    onTap: () {
                      final next = {...widget.selected, id};
                      widget.onChanged(next);
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
