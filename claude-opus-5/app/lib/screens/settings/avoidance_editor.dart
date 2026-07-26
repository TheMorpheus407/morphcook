import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../domain/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';

/// Typeahead over the ingredient tree. Picking a parent covers everything
/// under it, and the chip says so rather than silently expanding.
class IngredientAvoidanceEditor extends StatefulWidget {
  const IngredientAvoidanceEditor({
    super.key,
    required this.lang,
    required this.selected,
    required this.onChanged,
  });

  final String lang;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<IngredientAvoidanceEditor> createState() =>
      _IngredientAvoidanceEditorState();
}

class _IngredientAvoidanceEditorState extends State<IngredientAvoidanceEditor> {
  final TextEditingController _controller = TextEditingController();
  List<IngredientNode> _matches = const [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _query(String value) {
    final dict = context.read<AppState>().repository.ingredients;
    setState(() {
      _matches = value.trim().length < 2
          ? const []
          : dict
                .search(value, widget.lang, limit: 8)
                .where((n) => !widget.selected.contains(n.id))
                .toList();
    });
  }

  void _add(IngredientNode node) {
    final next = Set<String>.from(widget.selected)..add(node.id);
    // Children are implied; keeping them would just be noise in the UI.
    final dict = context.read<AppState>().repository.ingredients;
    final covered = dict.expandDownwards([node.id])..remove(node.id);
    next.removeWhere(covered.contains);
    widget.onChanged(next);
    _controller.clear();
    setState(() => _matches = const []);
  }

  void _remove(String id) =>
      widget.onChanged(Set<String>.from(widget.selected)..remove(id));

  @override
  Widget build(BuildContext context) {
    final s = S(widget.lang);
    final colors = context.colors;
    final dict = context.watch<AppState>().repository.ingredients;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onChanged: _query,
          decoration: InputDecoration(
            hintText: s.settingsSpecificHint,
            prefixIcon: Icon(Icons.search, size: 18, color: colors.inkFaint),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _matches = const []);
                    },
                  ),
          ),
        ),
        if (_matches.isNotEmpty) ...[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.paperRaised,
              border: Border.all(color: colors.edge),
            ),
            child: Column(
              children: [
                for (final node in _matches)
                  ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    title: Text(
                      node.label(widget.lang),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    subtitle: _pathOf(dict, node).isEmpty
                        ? null
                        : Text(
                            _pathOf(dict, node),
                            style: MorphType.numeric(colors.inkFaint, size: 10),
                          ),
                    trailing: Icon(Icons.add, size: 16, color: colors.accent),
                    onTap: () => _add(node),
                  ),
              ],
            ),
          ),
        ],
        if (widget.selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in widget.selected.toList()..sort())
                InkChip(
                  label: dict[id]?.label(widget.lang) ?? id,
                  selected: true,
                  dense: true,
                  tone: colors.secondary,
                  trailing: const Icon(Icons.close),
                  tooltip: _coverageNote(dict, id, widget.lang),
                  onTap: () => _remove(id),
                ),
            ],
          ),
        ],
      ],
    );
  }

  static String _pathOf(IngredientDictionary dict, IngredientNode node) {
    final ancestors = dict.ancestorsOf(node.id).reversed;
    if (ancestors.isEmpty) return '';
    return ancestors.join(' › ');
  }

  static String _coverageNote(
    IngredientDictionary dict,
    String id,
    String lang,
  ) {
    final covered = dict.expandDownwards([id]).length - 1;
    if (covered <= 0) return dict[id]?.label(lang) ?? id;
    return lang == 'de'
        ? '${dict[id]?.label(lang)} und $covered weitere darunter'
        : '${dict[id]?.label(lang)} and $covered more beneath it';
  }
}
