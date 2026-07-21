import 'package:flutter/material.dart';

import '../../domain/models/faq.dart';
import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import '../widgets/morph_components.dart';
import '../widgets/paper_surface.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({
    required this.entries,
    required this.languageCode,
    super.key,
    this.initialQuery,
    this.initialCategory,
  });

  final List<FaqEntry> entries;
  final String languageCode;
  final String? initialQuery;
  final String? initialCategory;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  late final TextEditingController _query = TextEditingController(
    text: widget.initialQuery,
  );
  late String? _category = widget.initialCategory;

  List<FaqEntry> get _filtered {
    final needle = _fold(_query.text);
    return widget.entries.where((entry) {
      if (_category != null && entry.category != _category) return false;
      if (needle.isEmpty) return true;
      final corpus = [
        entry.question.resolve(widget.languageCode),
        entry.answer.resolve(widget.languageCode),
        ...?entry.keywords[widget.languageCode],
        ...?entry.keywords['en'],
      ].map(_fold).join(' ');
      return needle.split(RegExp(r'\s+')).every(corpus.contains);
    }).toList();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        widget.entries.map((entry) => entry.category).toSet().toList()..sort();
    final entries = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('faq.title'))),
      body: PaperSurface(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.strings('faq.hint'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _query.clear();
                                setState(() {});
                              },
                              tooltip: context.strings('common.clear'),
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height:
                        42 *
                        (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
                          1,
                          1.6,
                        ),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        MorphTag(
                          label: context.strings('common.all'),
                          selected: _category == null,
                          onSelected: (_) => setState(() => _category = null),
                        ),
                        const SizedBox(width: 7),
                        for (final category in categories) ...[
                          MorphTag(
                            label: context.strings.option(
                              'faq.category',
                              category,
                            ),
                            selected: _category == category,
                            onSelected: (_) =>
                                setState(() => _category = category),
                          ),
                          const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? MorphEmptyState(
                      icon: Icons.help_outline_rounded,
                      title: context.strings('common.noResults'),
                      message: context.strings('faq.hint'),
                      action: () {
                        _query.clear();
                        setState(() => _category = null);
                      },
                      actionLabel: context.strings('common.clear'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: entries.length.clamp(0, 50),
                      itemBuilder: (context, index) => _FaqTile(
                        entry: entries[index],
                        languageCode: widget.languageCode,
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
  const _FaqTile({required this.entry, required this.languageCode});

  final FaqEntry entry;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: context.morph.ink.withValues(alpha: .35)),
        color: context.morph.paper,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
        title: Text(
          entry.question.resolve(languageCode),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        subtitle: Text(
          context.strings.option('faq.category', entry.category).toUpperCase(),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.morph.coral),
        ),
        children: [
          const DashedRule(),
          const SizedBox(height: 13),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answer.resolve(languageCode),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

String _fold(String input) => input
    .trim()
    .toLowerCase()
    .replaceAll('ä', 'a')
    .replaceAll('ö', 'o')
    .replaceAll('ü', 'u')
    .replaceAll('ß', 'ss');
