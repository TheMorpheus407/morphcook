import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../models/models.dart';
import 'widgets.dart';

class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(L10n.tFaq),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: svc.state,
        builder: (context, _) {
          final q = _query.trim().toLowerCase();
          final entries = svc.corpus.faqs.where((f) {
            if (q.isEmpty) return true;
            final question = T(f.question, lang).toLowerCase();
            final answer = T(f.answer, lang).toLowerCase();
            return question.contains(q) ||
                answer.contains(q) ||
                f.keywords.any((k) => k.toLowerCase().contains(q));
          }).toList();
          final groups = <String, List<FaqEntry>>{};
          for (final e in entries) {
            groups.putIfAbsent(e.category, () => []).add(e);
          }
          final known = svc.corpus.faqCategories.map((c) => c.id).toList();
          final orderedIds = [
            ...known.where(groups.containsKey),
            ...groups.keys.where((k) => !known.contains(k)),
          ];
          return SingleChildScrollView(
            child: Center(
              child: ZinePage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      onChanged: (v) => setState(() => _query = v),
                      style: AppText.mono(context, size: 12),
                      decoration: InputDecoration(
                        hintText: t(L10n.tSearchRecipes),
                        prefixIcon: const Icon(Icons.search, size: 17),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: t(L10n.tClear),
                                icon: const Icon(Icons.close, size: 17),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          t(L10n.tNoResults),
                          textAlign: TextAlign.center,
                          style: AppText.mono(
                              context, size: 11, color: AppColors.inkSoft),
                        ),
                      )
                    else
                      for (final id in orderedIds) ...[
                        SectionHeader(
                          title: _categoryLabel(svc, id, lang),
                          kicker: 'faq',
                        ),
                        for (final e in groups[id]!)
                          _entry(context, e, lang),
                        const DottedDivider(),
                      ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _categoryLabel(Services svc, String id, String lang) {
    final cat = svc.corpus.faqCategories.firstWhereOrNull((c) => c.id == id);
    if (cat == null) return id;
    final label = T(cat.label, lang);
    return label.isEmpty ? id : label;
  }

  Widget _entry(BuildContext context, FaqEntry e, String lang) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        backgroundColor: AppColors.paperBright,
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          T(e.question, lang),
          style: AppText.serif(context, size: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                T(e.answer, lang),
                style:
                    AppText.serif(context, size: 14, weight: FontWeight.w400)
                        .copyWith(height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}