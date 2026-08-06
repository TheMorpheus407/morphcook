import 'package:flutter/material.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

/// Typeahead against the hierarchical ingredient dictionary, used for
/// specific avoidance in onboarding and settings.
class IngredientTypeahead extends StatefulWidget {
  final TextEditingController controller;
  final IngredientDictionary dictionary;
  final AppLang lang;
  final Set<String> selected;
  final VoidCallback onChanged;

  const IngredientTypeahead({
    super.key,
    required this.controller,
    required this.dictionary,
    required this.lang,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<IngredientTypeahead> createState() => _IngredientTypeaheadState();
}

class _IngredientTypeaheadState extends State<IngredientTypeahead> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  String _query = '';

  List<IngredientNode> _matches() {
    final q = _query.trim().toLowerCase();
    final all = widget.dictionary.allNodes();
    if (q.isEmpty) return [];
    final scored = <(IngredientNode, int)>[];
    for (final node in all) {
      final en = tx(node.name, AppLang.en).toLowerCase();
      final de = tx(node.name, AppLang.de).toLowerCase();
      if (en.startsWith(q) || de.startsWith(q)) {
        scored.add((node, 0));
      } else if (en.contains(q) || de.contains(q)) {
        scored.add((node, 1));
      }
    }
    scored.sort((a, b) {
      final byScore = a.$2.compareTo(b.$2);
      if (byScore != 0) return byScore;
      return tx(a.$1.name, widget.lang)
          .compareTo(tx(b.$1.name, widget.lang));
    });
    return [for (final m in scored.take(8)) m.$1];
  }

  void _showOverlay() {
    _hideOverlay();
    final matches = _matches();
    if (matches.isEmpty) return;
    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 280,
        child: CompositedTransformFollower(
          link: _link,
          offset: const Offset(0, 46),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Paper.white,
                border: Border.all(color: Paper.ink),
                boxShadow: [
                  BoxShadow(
                    color: Paper.ink.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final node in matches)
                    InkWell(
                      onTap: () => _pick(node),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(tx(node.name, widget.lang),
                                  style: Type.mono(size: 12)),
                            ),
                            if (node.children.isNotEmpty)
                              Text('+${node.children.length}',
                                  style: Type.mono(
                                      size: 9, color: Paper.inkFaint)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _pick(IngredientNode node) {
    setState(() {
      widget.selected.add(node.id);
    });
    widget.controller.clear();
    _query = '';
    _hideOverlay();
    widget.onChanged();
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              children: [
                for (final id in widget.selected)
                  GestureDetector(
                    onTap: () {
                      setState(() => widget.selected.remove(id));
                      widget.onChanged();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8, bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Paper.ink,
                        border: Border.all(color: Paper.ink),
                      ),
                      child: Text(
                        '${tx(widget.dictionary[id]?.name, widget.lang)} ×',
                        style: Type.mono(size: 11, color: Paper.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        CompositedTransformTarget(
          link: _link,
          child: PaperFieldLocal(
            controller: widget.controller,
            hint: '…',
            onChanged: (v) {
              setState(() => _query = v);
              _showOverlay();
            },
          ),
        ),
      ],
    );
  }
}

/// Local copy of the paper field to avoid a circular import with widgets.dart.
class PaperFieldLocal extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const PaperFieldLocal({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Paper.white,
        border: Border.all(color: Paper.rule),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: Type.mono(size: 13),
        cursorColor: Paper.coral,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: Type.mono(size: 12, color: Paper.inkFaint),
          border: InputBorder.none,
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
