import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';

class FaqScreen extends StatefulWidget {
  final String? initialContextKey;
  final String? initialCategory;

  const FaqScreen({
    super.key,
    this.initialContextKey,
    this.initialCategory,
  });

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';
    final catalog = appState.faqs;
    final results = catalog.search(
      query: _searchCtrl.text,
      category: _selectedCategory,
      lang: lang,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isDe ? 'hilfe & faq-archiv' : 'faq & help center'),
      ),
      body: PaperGrainBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('faq_search_input'),
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: isDe
                          ? 'Hilfethemen durchsuchen (z. B. Halal, Kalorien, Backup)…'
                          : 'Search FAQ entries (e.g. halal, calories, backup)…',
                      hintStyle: NostalgicTheme.mono(fontSize: 11.5),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: NostalgicPalette.cardStock,
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          key: const ValueKey('faq_cat_all'),
                          selected: _selectedCategory == null,
                          label: Text(isDe ? 'Alle' : 'All'),
                          onSelected: (_) =>
                              setState(() => _selectedCategory = null),
                        ),
                        const SizedBox(width: 6),
                        for (final catEntry in catalog.categories.entries)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              key: ValueKey('faq_cat_${catEntry.key}'),
                              selected: _selectedCategory == catEntry.key,
                              label: Text(catEntry.value.resolve(lang)),
                              onSelected: (val) => setState(() {
                                _selectedCategory = val ? catEntry.key : null;
                              }),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: DashedRule(),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        isDe
                            ? 'Keine passenden FAQ-Einträge gefunden.'
                            : 'No matching FAQ entries found.',
                        style: NostalgicTheme.serifBody(
                          color: NostalgicPalette.fadedInk,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                      itemCount: results.length,
                      itemBuilder: (context, idx) {
                        final item = results[idx];
                        final isHighlightedContext =
                            widget.initialContextKey != null &&
                            item.contextKey == widget.initialContextKey;

                        return Container(
                          key: ValueKey('faq_item_${item.id}'),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isHighlightedContext
                                ? NostalgicPalette.saffron.withValues(alpha: 0.16)
                                : NostalgicPalette.cardStock,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isHighlightedContext
                                  ? NostalgicPalette.terracotta
                                  : NostalgicPalette.mutedRule,
                            ),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: isHighlightedContext || idx == 0,
                            title: Text(
                              item.question.resolve(lang),
                              style: NostalgicTheme.serifDisplay(
                                fontSize: 17.5,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            subtitle: Text(
                              catalog.categories[item.category]?.resolve(lang) ??
                                  item.category,
                              style: NostalgicTheme.mono(
                                fontSize: 10.5,
                                color: NostalgicPalette.terracotta,
                              ),
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            children: [
                              Text(
                                item.answer.resolve(lang),
                                style: NostalgicTheme.serifBody(fontSize: 14.5),
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
    );
  }
}
