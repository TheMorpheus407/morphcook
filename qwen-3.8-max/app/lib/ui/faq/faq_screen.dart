import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../data/models.dart';
import '../../state/app_model.dart';
import '../widgets.dart';

/// Help center: searchable FAQ entries with category filters.
class FaqScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const FaqScreen({super.key, this.initialQuery, this.initialCategory});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery ?? '');
  late String _category = widget.initialCategory ?? 'all';
  final Set<String> _open = {};

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  static const _categories = [
    'all',
    'matching',
    'variants',
    'shopping',
    'features',
    'backup',
  ];

  String _categoryLabel(Strings s, String category) {
    switch (category) {
      case 'all':
        return s.get('allCategories');
      case 'matching':
        return s.get('catMatching');
      case 'variants':
        return s.get('catVariants');
      case 'shopping':
        return s.get('catShopping');
      case 'features':
        return s.get('catFeatures');
      case 'backup':
        return s.get('catBackup');
      default:
        return category;
    }
  }

  List<Faq> _filtered(List<Faq> faqs) {
    final q = _query.text.trim().toLowerCase();
    return faqs.where((f) {
      if (_category != 'all' && f.category != _category) return false;
      if (q.isEmpty) return true;
      final hay = [
        tx(f.q, AppLang.en),
        tx(f.q, AppLang.de),
        tx(f.a, AppLang.en),
        tx(f.a, AppLang.de),
        ...f.tags,
      ].join(' ').toLowerCase();
      return q.split(RegExp(r'\s+')).every(hay.contains);
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;
    final faqs = _filtered(corpus.faqs);
    return PaperGrain(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Text('←',
                          style: Type.mono(size: 16, color: Paper.inkSoft)),
                    ),
                    const SizedBox(width: 14),
                    Text(s.get('helpCenter'),
                        style: Type.displayBold(size: 26)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: PaperField(
                  controller: _query,
                  hint: s.get('searchFaq'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final category in _categories)
                      PaperChip(
                        label: _categoryLabel(s, category),
                        selected: _category == category,
                        onTap: () => setState(() => _category = category),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: faqs.isEmpty
                    ? EmptyNote(title: s.get('noResults'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 8),
                        itemCount: faqs.length,
                        itemBuilder: (context, index) {
                          final faq = faqs[index];
                          final open = _open.contains(faq.id);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Paper.white,
                              border: Border.all(color: Paper.rule),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () => setState(() {
                                    open
                                        ? _open.remove(faq.id)
                                        : _open.add(faq.id);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(tx(faq.q, lang),
                                              style: Type.mono(
                                                  size: 12.5,
                                                  weight: FontWeight.w600)),
                                        ),
                                        Text(open ? '⌃' : '⌄',
                                            style: Type.mono(
                                                size: 13,
                                                color: Paper.inkSoft)),
                                      ],
                                    ),
                                  ),
                                ),
                                if (open)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 0, 14, 14),
                                    child: Text(tx(faq.a, lang),
                                        style: Type.mono(
                                            size: 12,
                                            color: Paper.inkSoft)),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
