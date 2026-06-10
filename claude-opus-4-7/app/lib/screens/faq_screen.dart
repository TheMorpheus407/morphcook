import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/corpus.dart';
import '../l10n/strings.dart';
import '../models/faq.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/chip_tag.dart';
import '../widgets/dashed_rule.dart';
import '../widgets/masthead.dart';
import '../widgets/paper_background.dart';

class FaqScreen extends StatefulWidget {
  final String? contextFilter;
  const FaqScreen({super.key, this.contextFilter});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _category = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final corpus = context.watch<Corpus>();
    final lang = l.lang;
    final all = corpus.faqs;
    final categories = <String>{'all'};
    for (final f in all) {
      categories.add(f.category);
    }
    var visible = all.where((f) {
      if (widget.contextFilter != null &&
          !f.linkedContexts.contains(widget.contextFilter)) return false;
      if (_category != 'all' && f.category != _category) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return f.question.get(lang).toLowerCase().contains(q) ||
          f.answer.get(lang).toLowerCase().contains(q);
    }).toList();

    return PaperBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Masthead(
                title: 'help',
                edition: l.t('faq.title'),
                leftMeta: '${visible.length} entries',
                rightMeta: widget.contextFilter ?? '',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  cursorColor: MorphColors.ink,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: l.t('app.search'),
                    prefixIcon:
                        const Icon(Icons.search, color: MorphColors.ink),
                  ),
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final c in categories)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChipTag(
                          label: l.t('faq.category.$c'),
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              const DashedRule(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const DashedRule(),
                  itemBuilder: (ctx, i) =>
                      _FaqTile(entry: visible[i], lang: lang),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final FaqEntry entry;
  final String lang;
  const _FaqTile({required this.entry, required this.lang});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(widget.entry.question.get(widget.lang),
                      style: MorphType.headline(size: 18)),
                ),
                Icon(_open ? Icons.expand_less : Icons.expand_more),
              ],
            ),
            if (_open) ...[
              const SizedBox(height: 8),
              Text(widget.entry.answer.get(widget.lang),
                  style: MorphType.body(size: 15)),
            ],
          ],
        ),
      ),
    );
  }
}
