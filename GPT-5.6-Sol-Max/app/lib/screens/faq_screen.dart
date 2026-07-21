import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/brand.dart';
import '../core/copy.dart';
import '../models/content.dart';
import '../models/localized_text.dart';
import '../state/app_controller.dart';
import '../widgets/paper.dart';
import '../widgets/states.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialCategory, this.initialQuery = ''});
  final String? initialCategory;
  final String initialQuery;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late String? _category = widget.initialCategory;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final lang = app.language;
    final normalized = _query.text.trim().toLowerCase();
    final entries = app.content.faqs.where((entry) {
      if (_category != null && entry.category != _category) return false;
      if (normalized.isEmpty) return true;
      final haystack = [
        entry.question.value(lang),
        entry.answer.value(lang),
        ...entry.keywords,
      ].join(' ').toLowerCase();
      return haystack.contains(normalized);
    }).toList();
    final categories =
        app.content.faqs.map((item) => item.category).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(Copy.text('help', lang))),
      body: PaperBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: Copy.text('faq_search', lang),
                ),
              ),
            ),
            SizedBox(
              height: 43,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(Copy.text('all', lang)),
                      selected: _category == null,
                      onSelected: (_) => setState(() => _category = null),
                    ),
                  ),
                  for (final category in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(_categoryLabel(category, lang)),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: DashedRule(),
            ),
            Expanded(
              child: entries.isEmpty
                  ? EmptyPageNote(
                      icon: Icons.help_outline,
                      title: Copy.text('no_results', lang),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _FaqTile(entry: entries[index], language: lang),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(String value, String lang) {
    const de = {
      'dietary': 'ernährung',
      'features': 'funktionen',
      'privacy': 'datenschutz',
      'troubleshooting': 'fehlerhilfe',
      'accessibility': 'barrierefreiheit',
    };
    return lang == 'de' ? de[value] ?? value : value;
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry, required this.language});
  final FaqEntry entry;
  final String language;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF9F5EA),
      border: Border.all(color: BrandColors.ink, width: 1.1),
    ),
    child: ExpansionTile(
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        entry.question.value(language),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        entry.category.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: BrandColors.coral),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 40, 18),
          child: Text(entry.answer.value(language)),
        ),
      ],
    ),
  );
}
