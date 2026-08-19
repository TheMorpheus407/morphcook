/// FAQ / help center: searchable, category filters, related links.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../l10n.dart';
import '../state/app_state.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _query = '';
  String _category = 'all';

  static const _categories = [
    'all', 'general', 'recipes', 'matching', 'features', 'troubleshooting',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final lang = app.profile.lang;
    final faqs = app.corpus!.faqs;

    Iterable<FaqEntry> filtered = faqs;
    if (_category != 'all') {
      filtered = filtered.where((f) => f.category == _category);
    }
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      filtered = filtered.where((f) =>
          f.question.get(lang).toLowerCase().contains(q) ||
          f.answer.get(lang).toLowerCase().contains(q));
    }
    final list = filtered.toList();

    return Scaffold(
      appBar: AppBar(title: Text(L.t(lang, 'fqTitle'))),
      body: PaperGrain(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: L.t(lang, 'fqHint'),
                hintStyle: const TextStyle(
                    fontFamily: AppTheme.hand,
                    fontSize: 18,
                    color: AppTheme.inkFaint),
                prefixIcon:
                    const Icon(Icons.search, size: 18, color: AppTheme.inkSoft),
                border: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.ink, width: 1.4)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.coral, width: 1.8)),
              ),
              style: const TextStyle(fontFamily: AppTheme.display, fontSize: 17),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final c in _categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: StampChip(
                      label: c == 'all'
                          ? L.t(lang, 'fqAll')
                          : L.t(lang, 'fqCat${c[0].toUpperCase()}${c.substring(1)}'),
                      color: AppTheme.teal,
                      selected: _category == c,
                      onTap: () => setState(() => _category = c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: HandNote(text: L.t(lang, 'scNoResults')))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _FaqTile(
                      lang: lang,
                      entry: list[i],
                      faqs: faqs,
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final Lang lang;
  final FaqEntry entry;
  final List<FaqEntry> faqs;
  const _FaqTile({required this.lang, required this.entry, required this.faqs});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.line),
        color: AppTheme.paper,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: AppTheme.coral,
          collapsedIconColor: AppTheme.inkFaint,
          title: Text(
            entry.question.get(lang),
            style: const TextStyle(
                fontFamily: AppTheme.display,
                fontStyle: FontStyle.italic,
                fontSize: 16.5,
                height: 1.3,
                color: AppTheme.ink),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              entry.category,
              style: const TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 8.5,
                  letterSpacing: 1.4,
                  color: AppTheme.inkFaint),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                entry.answer.get(lang),
                style: const TextStyle(
                    fontFamily: AppTheme.display,
                    fontSize: 15,
                    height: 1.55,
                    color: AppTheme.ink),
              ),
            ),
            if (entry.relatedIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  L.t(lang, 'fqRelated').toUpperCase(),
                  style: const TextStyle(
                      fontFamily: AppTheme.mono,
                      fontSize: 9,
                      letterSpacing: 1.6,
                      color: AppTheme.inkFaint),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  for (final rid in entry.relatedIds)
                    if (faqs.any((f) => f.id == rid))
                      Builder(builder: (context) {
                        final related = faqs.firstWhere((f) => f.id == rid);
                        return GestureDetector(
                        onTap: () {
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: AppTheme.paper,
                            builder: (_) => Padding(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    related.question.get(lang),
                                    style: const TextStyle(
                                        fontFamily: AppTheme.display,
                                        fontStyle: FontStyle.italic,
                                        fontSize: 18,
                                        color: AppTheme.ink),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    related.answer.get(lang),
                                    style: const TextStyle(
                                        fontFamily: AppTheme.display,
                                        fontSize: 15,
                                        height: 1.55,
                                        color: AppTheme.inkSoft),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Text(
                          related.question.get(lang),
                          style: const TextStyle(
                              fontFamily: AppTheme.display,
                              fontSize: 13.5,
                              color: AppTheme.teal,
                              decoration: TextDecoration.underline,
                              decorationColor: AppTheme.line,
                              decorationThickness: 2),
                        ),
                      );
                      }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
