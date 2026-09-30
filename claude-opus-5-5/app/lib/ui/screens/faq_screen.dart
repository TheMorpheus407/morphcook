import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../../models/reference.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/paper.dart';

/// Searchable help center with category filters. Opened with an entry id
/// from contextual links across the app, that entry starts expanded.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialEntryId, this.initialCategory});
  final String? initialEntryId;
  final String? initialCategory;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _query = TextEditingController();
  String? _category;
  late final Set<String> _open = {if (widget.initialEntryId != null) widget.initialEntryId!};
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    if (widget.initialEntryId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.initialEntryId]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.1);
      });
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _jump(String id) {
    final catalog = context.read<CorpusRepository>().faqs;
    final entry = catalog.byId(id);
    setState(() {
      _query.clear();
      _category = null;
      _open.add(id);
    });
    if (entry == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: motionRead(context, const Duration(milliseconds: 300)), alignment: 0.1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final catalog = context.read<CorpusRepository>().faqs;
    final results = catalog.search(_query.text, category: _category, lang: lang);
    return Scaffold(
      appBar: AppBar(title: Text(tr('faq.title'))),
      body: PaperBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                key: const Key('faq-search'),
                controller: _query,
                onChanged: (_) => setState(() {}),
                style: MT.serif(16),
                decoration: InputDecoration(
                  hintText: tr('faq.search'),
                  prefixIcon: const Icon(Icons.search, color: MC.inkSoft),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                children: [
                  InkChip(
                    dense: true,
                    label: tr('faq.all'),
                    selected: _category == null,
                    onTap: () => setState(() => _category = null),
                  ),
                  for (final c in catalog.categories) ...[
                    const SizedBox(width: 6),
                    InkChip(
                      key: Key('faq-cat-${c.id}'),
                      dense: true,
                      label: c.label.of(lang),
                      selected: _category == c.id,
                      onTap: () => setState(() => _category = _category == c.id ? null : c.id),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(tr('faq.none'), style: MT.hand(22, color: MC.inkSoft)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        children: [
                          for (final e in results)
                            _FaqTile(
                              key: _keys.putIfAbsent(e.id, GlobalKey.new),
                              entry: e,
                              catalog: catalog,
                              open: _open.contains(e.id),
                              onToggle: () =>
                                  setState(() => _open.contains(e.id) ? _open.remove(e.id) : _open.add(e.id)),
                              onRelated: _jump,
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    super.key,
    required this.entry,
    required this.catalog,
    required this.open,
    required this.onToggle,
    required this.onRelated,
  });

  final FaqEntry entry;
  final FaqCatalog catalog;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onRelated;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final lang = tr.lang;
    final category = catalog.categories.where((c) => c.id == entry.category).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: open,
          child: InkWell(
            key: Key('faq-${entry.id}'),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (category != null) MonoLabel(category.label.of(lang), size: 9.5, color: MC.coralDeep),
                        const SizedBox(height: 2),
                        Text(entry.question.of(lang), style: MT.display(19)),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.remove : Icons.add, size: 18, color: MC.inkSoft),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: motion(context, const Duration(milliseconds: 220)),
          alignment: Alignment.topLeft,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.answer.of(lang), style: MT.serif(15.5, height: 1.55)),
                      if (entry.related.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        MonoLabel(tr('faq.related'), size: 10),
                        for (final r in entry.related)
                          if (catalog.byId(r) != null)
                            TextLink(
                              catalog.byId(r)!.question.of(lang),
                              icon: Icons.arrow_forward,
                              onTap: () => onRelated(r),
                            ),
                      ],
                    ],
                  ),
                ),
        ),
        const DashedRule(),
      ],
    );
  }
}
