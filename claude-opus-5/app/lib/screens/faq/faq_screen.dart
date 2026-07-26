import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../domain/models.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';

/// A contextual link from UI copy into the help centre. Every anchor in
/// `faqs.json` is addressable this way, so a caption can point at the exact
/// answer instead of a generic help page.
class FaqLink extends StatelessWidget {
  const FaqLink({super.key, required this.anchor, required this.label});

  final String anchor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FaqScreen(anchor: anchor)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.help_outline, size: 13, color: colors.secondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              style: MorphType.eyebrow(colors.secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.anchor});

  /// Opens with this entry expanded and scrolled into view.
  final String? anchor;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _query = TextEditingController();
  final Map<String, GlobalKey> _keys = {};

  String? _category;
  String? _expanded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToAnchor());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _jumpToAnchor() {
    final anchor = widget.anchor;
    if (anchor == null || !mounted) return;
    final entry = context.read<AppState>().repository.faqs.byAnchor(anchor);
    if (entry == null) return;
    setState(() => _expanded = entry.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _keys[entry.id];
      final target = key?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        duration: Motion.duration(context, MorphDurations.expand),
        alignment: 0.1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final faqs = state.repository.faqs;

    final entries = faqs.entries.where((e) {
      if (_category != null && e.category != _category) return false;
      return e.matches(_query.text, s.lang);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.faqTitle.toLowerCase())),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.faqSearchHint,
              prefixIcon: Icon(Icons.search, size: 18, color: colors.inkFaint),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkChip(
                    label: s.faqAllCategories,
                    dense: true,
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                ),
                for (final category in faqs.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkChip(
                      label: category.label(s.lang),
                      dense: true,
                      selected: _category == category.id,
                      onTap: () => setState(() => _category = category.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            EmptyNote(
              headline: s.faqNoResults,
              body: s.searchStartBody,
              icon: Icons.help_outline,
            )
          else
            for (final entry in entries)
              _FaqTile(
                key: _keys.putIfAbsent(entry.id, GlobalKey.new),
                entry: entry,
                lang: s.lang,
                expanded: _expanded == entry.id,
                onToggle: () => setState(
                  () => _expanded = _expanded == entry.id ? null : entry.id,
                ),
                onRelated: (id) {
                  setState(() {
                    _expanded = id;
                    _category = null;
                    _query.clear();
                  });
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final target = _keys[id]?.currentContext;
                    if (target == null) return;
                    Scrollable.ensureVisible(
                      target,
                      duration: Motion.duration(context, MorphDurations.expand),
                      alignment: 0.1,
                    );
                  });
                },
              ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    super.key,
    required this.entry,
    required this.lang,
    required this.expanded,
    required this.onToggle,
    required this.onRelated,
  });

  final FaqEntry entry;
  final String lang;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<String> onRelated;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(lang);
    final colors = context.colors;
    final faqs = state.repository.faqs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    entry.question(lang),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: Motion.duration(context, MorphDurations.expand),
                  child: Icon(
                    Icons.expand_more,
                    size: 18,
                    color: colors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
        MotionSize(
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.answer(lang),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (entry.related.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Eyebrow(s.faqRelated),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final id in entry.related)
                              if (faqs.byId(id) != null)
                                InkChip(
                                  label: faqs.byId(id)!.question(lang),
                                  dense: true,
                                  tone: colors.secondary,
                                  onTap: () => onRelated(id),
                                ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        DashedRule(color: colors.edge),
      ],
    );
  }
}
