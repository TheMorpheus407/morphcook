import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/faq.dart';
import '../../state/app_controller.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';

/// Searchable FAQ with category filters. Deep-linked from UI copy via
/// [initialId].
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialId, this.initialCategory});
  final String? initialId;
  final String? initialCategory;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _query = TextEditingController();
  String? _category;
  final Set<String> _expanded = {};
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (widget.initialId != null) {
      _expanded.add(widget.initialId!);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(widget.initialId!));
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  void _scrollTo(String id) {
    final ctx = _keyFor(id).currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.1,
      duration: Motion.duration(context, const Duration(milliseconds: 300)),
      curve: Curves.easeOutCubic,
    );
  }

  void _openRelated(String id) {
    setState(() {
      _expanded.add(id);
      _category = null;
      _query.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(id));
  }

  bool _matches(FaqEntry e, String q, String lang) {
    if (q.isEmpty) return true;
    final hay = [
      e.question.of(lang),
      e.answer.of(lang),
      e.question.of('en'),
      e.answer.of('en'),
      ...e.keywords,
    ].join(' ').toLowerCase();
    return q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).every(hay.contains);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = context.lang;
    final faqs = app.repo.faqs;
    final q = _query.text.trim().toLowerCase();
    final entries = faqs.entries.where((e) => (_category == null || e.category == _category) && _matches(e, q, lang)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(s('faq.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), child: MonoLabel(s('faq.kicker'))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              style: AppText.body(size: 15),
              decoration: InputDecoration(
                hintText: s('faq.hint'),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: q.isEmpty ? null : IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(_query.clear)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                PaperChip(label: s('faq.all'), selected: _category == null, onTap: () => setState(() => _category = null)),
                for (final c in faqs.categories) ...[
                  const SizedBox(width: 8),
                  PaperChip(label: c.label.of(lang), selected: _category == c.id, onTap: () => setState(() => _category = c.id)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(20, 32, 20, 0), child: HandNote(s('faq.empty'), align: TextAlign.center))
          else
            for (final e in entries)
              _FaqTile(
                key: _keyFor(e.id),
                entry: e,
                lang: lang,
                expanded: _expanded.contains(e.id),
                onToggle: () => setState(() {
                  if (!_expanded.remove(e.id)) _expanded.add(e.id);
                }),
                related: [for (final id in e.related) if (faqs.byId(id) != null) faqs.byId(id)!],
                onRelated: _openRelated,
                relatedLabel: s('faq.related'),
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
    required this.related,
    required this.onRelated,
    required this.relatedLabel,
  });

  final FaqEntry entry;
  final String lang;
  final bool expanded;
  final VoidCallback onToggle;
  final List<FaqEntry> related;
  final void Function(String id) onRelated;
  final String relatedLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(entry.question.of(lang), style: AppText.title(size: 16))),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: Motion.duration(context, const Duration(milliseconds: 180)),
                  child: const Icon(Icons.expand_more, size: 20, color: Palette.inkFaint),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: Motion.duration(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.answer.of(lang), style: AppText.body(size: 14.5)),
                      if (related.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        MonoLabel(relatedLabel),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            for (final r in related)
                              InkWell(
                                onTap: () => onRelated(r.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    r.question.of(lang).toLowerCase(),
                                    style: AppText.mono(color: Palette.inkSoft, size: 11.5).copyWith(
                                      decoration: TextDecoration.underline,
                                      decorationColor: Palette.rule,
                                      decorationStyle: TextDecorationStyle.dashed,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: DashedRule()),
      ],
    );
  }
}
