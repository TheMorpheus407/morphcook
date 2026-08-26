/// Help center: search over the bundled FAQ corpus, grouped by category.
library;

import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'morph.dart';
import 'widgets.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _ctrl = TextEditingController();
  String _q = '';
  String _cat = 'all';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = Morph.of(context);
    final faqs = m.c.faqs;
    final cats = <String>[
      'all',
      ...m.c.faqCategories.keys.where((c) => c != 'all'),
    ];

    final q = _q.trim().toLowerCase();
    List<FaqEntry> hits = q.isEmpty
        ? faqs
        : faqs
            .where((f) =>
                f.q.s(m.lang).toLowerCase().contains(q) ||
                f.a.s(m.lang).toLowerCase().contains(q))
            .toList();
    if (_cat != 'all') {
      hits = hits.where((f) => f.category == _cat).toList();
    }

    return Scaffold(
      appBar: AppBar(title: Text(m.t('faq.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(m.t('faq.sub'), style: T.body.copyWith(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 16),
                hintText: m.t('common.search'),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in cats) ...[
                    TagChip(
                      label: c == 'all'
                          ? m.t('faq.all')
                          : m.c.faqCategories[c]?[m.lang] ??
                                m.c.faqCategories[c]?['en'] ??
                                c,
                      selected: _cat == c,
                      onTap: () => setState(() => _cat = c),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hits.isEmpty)
              EmptyState(title: m.t('faq.none'), sub: '')
            else
              for (final f in hits)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Palette.cardPaper,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Palette.ink.withValues(alpha: 0.09)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            f.q.s(m.lang),
                            style: const TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 17,
                                color: Palette.ink)),
                        const SizedBox(height: 6),
                        Text(f.a.s(m.lang),
                            style: T.body.copyWith(fontSize: 13, height: 1.5)),
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
