import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../design/widgets/buttons.dart';
import '../../design/widgets/paper.dart';
import '../../design/widgets/rules.dart';
import '../../design/widgets/states.dart';
import '../../l10n/strings.dart';
import '../../models/faq.dart';
import '../../state/app_state.dart';

/// The Help Center — searchable FAQ entries with category filters.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _controller = TextEditingController();
  String _category = 'all';

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory ?? 'all';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final strings = state.strings;
    final repository = state.faqs;

    final query = _controller.text.trim();
    final entries = query.isEmpty
        ? repository.entries
        : repository.search(query);
    final filtered = _category == 'all'
        ? entries
        : entries.where((entry) => entry.category == _category).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PaperBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          strings.faqTitle,
                          style: Type.display(size: 30),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                        color: MC.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    style: Type.body(size: 14.5, color: MC.ink),
                    cursorColor: MC.coral,
                    decoration: InputDecoration(
                      hintText: strings.faqHint,
                      hintStyle: Type.body(size: 14, color: MC.inkGhost),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: MC.inkFaint,
                      ),
                      filled: true,
                      fillColor: MC.card,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: MC.ruleFaint),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: MC.ruleFaint),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(3),
                        borderSide: const BorderSide(color: MC.coral),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    children: <Widget>[
                      _CategoryChip(
                        label: strings.faqAll,
                        selected: _category == 'all',
                        onTap: () => setState(() => _category = 'all'),
                      ),
                      for (final category in FaqCategory.all)
                        _CategoryChip(
                          label: _categoryLabel(category, strings),
                          selected: _category == category,
                          onTap: () => setState(() => _category = category),
                        ),
                    ],
                  ),
                ),
              ),
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    title: strings.faqEmpty,
                    glyph: '∅',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _FaqEntryTile(
                        entry: entry,
                        strings: strings,
                        related: entry.relatedIds
                            .map(repository.byId)
                            .whereType<FaqEntry>()
                            .toList(),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryLabel(String category, Strings strings) {
    switch (category) {
      case FaqCategory.dietary:
        return strings.faqDietary;
      case FaqCategory.visibility:
        return strings.faqVisibility;
      case FaqCategory.features:
        return strings.faqFeatures;
      case FaqCategory.troubleshooting:
        return strings.faqTroubleshooting;
      case FaqCategory.backup:
        return strings.faqBackup;
      default:
        return category;
    }
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? MC.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: selected ? MC.teal : MC.rule),
          ),
          child: Text(
            label.toUpperCase(),
            style: Type.label(
              size: 9.5,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? MC.card : MC.inkSoft,
            ),
          ),
        ),
      ),
    );
  }
}

/// One expandable FAQ entry.
class _FaqEntryTile extends StatelessWidget {
  const _FaqEntryTile({
    required this.entry,
    required this.strings,
    required this.related,
  });

  final FaqEntry entry;
  final Strings strings;
  final List<FaqEntry> related;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        title: Text(
          entry.question.resolve(strings.lang),
          style: Type.bodyStrong(size: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _categoryLabel(entry.category),
            style: Type.label(size: 8.5),
          ),
        ),
        children: <Widget>[
          const DashedRule(),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answer.resolve(strings.lang),
              style: Type.body(size: 14.5),
            ),
          ),
          if (entry.linkTo != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: GhostButton(
                label: entry.linkTo == 'settings'
                    ? strings.faqOpenSettings
                    : strings.faqOpenSearch,
                icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ],
          if (related.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                strings.faqRelated.toUpperCase(),
                style: Type.label(size: 9),
              ),
            ),
            const SizedBox(height: 6),
            for (final other in related)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '· ${other.question.resolve(strings.lang)}',
                    style: Type.scriptSmall(size: 15),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _categoryLabel(String category) {
    switch (category) {
      case FaqCategory.dietary:
        return strings.faqDietary;
      case FaqCategory.visibility:
        return strings.faqVisibility;
      case FaqCategory.features:
        return strings.faqFeatures;
      case FaqCategory.troubleshooting:
        return strings.faqTroubleshooting;
      case FaqCategory.backup:
        return strings.faqBackup;
      default:
        return category;
    }
  }
}
