import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import 'strings.dart';
import 'widgets.dart';

class FaqScreen extends StatefulWidget {
  final String? highlightId;
  const FaqScreen({super.key, this.highlightId});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _query = '';
  String? _category;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final faqs = state.corpus.faqs;
    final entries = faqs.entries.where((e) {
      if (_category != null && e.category != _category) return false;
      return e.matches(_query, state.lang);
    }).toList();
    return PaperBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(s('helpCenter'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(hintText: s('faqSearchHint')),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                SoftChip(
                  label: s('all'),
                  selected: _category == null,
                  onTap: () => setState(() => _category = null),
                ),
                for (final c in faqs.categories)
                  SoftChip(
                    label: c.name.of(state.lang),
                    selected: _category == c.id,
                    onTap: () => setState(() => _category = c.id),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            for (final e in entries)
              ExpansionTile(
                initiallyExpanded: e.id == widget.highlightId,
                title: Text(e.question.of(state.lang)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(e.answer.of(state.lang)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

void openFaq(BuildContext context, {String? highlight}) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => FaqScreen(highlightId: highlight)),
  );
}
