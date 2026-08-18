import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/faq.dart';
import '../../core/models/localized_text.dart';
import '../../core/theme/app_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/chips.dart';
import '../../core/theme/dashed_rule.dart';
import '../../core/theme/paper.dart';
import '../../l10n/tr.dart';
import '../../state/app_state.dart';

/// FAQ / Help Center (SPEC): searchable entries with category filters,
/// reachable contextually from UI copy via `openFaq(context, entryId)`.
class FaqPage extends StatefulWidget {
  const FaqPage({super.key, this.initialEntryId});

  final String? initialEntryId;

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  final _controller = TextEditingController();
  String _query = '';
  String? _highlight;

  @override
  void initState() {
    super.initState();
    _highlight = widget.initialEntryId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lang = state.lang;
    final book = state.corpus.faqs;
    final results = book.search(_query, lang);

    return PaperScaffold(
      seed: 31,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
        title: Text('morphcook', style: AppFonts.display(size: 20)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('faq.title'),
                    style: AppFonts.display(size: 32, color: AppColors.ink)),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  onChanged: (v) => setState(() => _query = v),
                  style: AppFonts.serif(size: 15),
                  decoration: InputDecoration(
                    hintText: context.tr('faq.searchHint'),
                    hintStyle: AppFonts.mono(size: 11, color: AppColors.inkFaint),
                    prefixIcon: const Icon(Icons.search, color: AppColors.teal, size: 20),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.inkFaint),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _categoryChips(book, lang),
                const SizedBox(height: 6),
                const DashedRule(glyph: '?'),
              ],
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(context.tr('faq.empty'),
                        style: AppFonts.serif(size: 14, color: AppColors.inkSoft)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final faq = results[index];
                      return _FaqTile(
                        faq: faq,
                        lang: lang,
                        highlighted: faq.id == _highlight,
                        categoryLabel: book.categoryLabel(faq.category, lang),
                        onHighlight: () => setState(() => _highlight = null),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChips(FaqBook book, String lang) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        SelectablePill(
          label: context.tr('common.all'),
          selected: _query.isEmpty,
          onTap: () {
            _controller.clear();
            setState(() => _query = '');
          },
          compact: true,
        ),
        for (final category in book.categories)
          SelectablePill(
            label: book.categoryLabel(category.id, lang),
            selected: false,
            onTap: () {
              _controller.clear();
              setState(() => _query = book.categoryLabel(category.id, lang));
            },
            compact: true,
          ),
      ],
    );
  }
}
class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    required this.lang,
    required this.highlighted,
    required this.categoryLabel,
    required this.onHighlight,
  });

  final Faq faq;
  final String lang;
  final bool highlighted;
  final String categoryLabel;
  final VoidCallback onHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: highlighted ? AppColors.mustard.withOpacity(0.18) : null,
      child: ExpansionTile(
        onExpansionChanged: (_) => onHighlight(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 20),
        title: Text(
          lt(faq.question, lang),
          style: AppFonts.serif(size: 16, color: AppColors.ink),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(categoryLabel.toUpperCase(),
              style: AppFonts.mono(size: 8, color: AppColors.coral, letterSpacing: 1.4)),
        ),
        iconColor: AppColors.teal,
        collapsedIconColor: AppColors.inkFaint,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              lt(faq.answer, lang),
              style: AppFonts.serif(size: 14, color: AppColors.inkSoft, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }
}
