import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/palette.dart';
import '../core/paper.dart';
import '../models/faq.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';

/// FAQ / Help Center — searchable entries with category filters.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _query = TextEditingController();
  String _category = 'all';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final loc = context.read<LocaleController>();
    final q = _query.text.trim().toLowerCase();

    final filtered = corpus.faqs.where((f) {
      if (_category != 'all' && f.category != _category) return false;
      if (q.isEmpty) return true;
      final question = (f.question[loc.lang] ?? f.question['en'] ?? '')
          .toLowerCase();
      final answer =
          (f.answer[loc.lang] ?? f.answer['en'] ?? '').toLowerCase();
      return question.contains(q) ||
          answer.contains(q) ||
          f.tags.any((t) => t.contains(q));
    }).toList();

    final categories = <String>{
      'all',
      for (final f in corpus.faqs) f.category,
    };

    return Scaffold(
      appBar: AppBar(title: Text(context.t('faqTitle'))),
      body: PaperBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _query,
                decoration: InputDecoration(
                  hintText: context.t('faqSearch'),
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  for (final c in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                          c == 'all' ? context.t('faqAll') : context.t('faq${_cap(c)}'),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        context.t('searchNoResults'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) => _faqTile(context, filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _faqTile(BuildContext context, FaqEntry f) {
    final loc = context.read<LocaleController>();
    final question = f.question[loc.lang] ?? f.question['en'] ?? '';
    final answer = f.answer[loc.lang] ?? f.answer['en'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: MC.card,
        border: Border.all(color: MC.rule),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            question,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MC.ink,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CustomPaint(
              painter: DashedRulePainter(color: MC.rule),
              size: Size(double.infinity, 1),
            ),
            const SizedBox(height: 10),
            Text(
              answer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
