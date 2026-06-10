import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../localization/i18n.dart';
import '../../models/faq.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';
import '../../widgets/masthead.dart';
import '../../widgets/paper_background.dart';
import '../../widgets/tag_chip.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String? _category;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    final state = AppScope.of(context);
    final lang = state.profileRepo.profile.lang;
    final faq = state.faqRepo;

    final entries = _query.isNotEmpty
        ? faq.search(_query, lang)
        : faq.byCategory(_category);

    return Scaffold(
      appBar: AppBar(title: Text(s.faqTitle)),
      body: PaperBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
            children: [
              Masthead(title: s.faqTitle, align: TextAlign.left, titleSize: 32),
              const SizedBox(height: 16),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: s.faqSearchHint,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    TagChip(
                      label: s.faqAllCategories,
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                    const SizedBox(width: 6),
                    ...faq.categories.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: TagChip(
                            label: c.label.resolve(lang),
                            selected: _category == c.id,
                            accent: MCColors.teal,
                            onTap: () => setState(
                                () => _category = _category == c.id ? null : c.id),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const DashedRule(),
              for (final e in entries) _Entry(entry: e, lang: lang, faq: faq),
            ],
          ),
        ),
      ),
    );
  }
}

class _Entry extends StatefulWidget {
  final FaqEntry entry;
  final String lang;
  final dynamic faq;
  const _Entry({required this.entry, required this.lang, required this.faq});

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final s = I18n.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MCColors.polaroid,
        border: Border.all(color: MCColors.paperDark, width: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.entry.question.resolve(widget.lang),
                    style: MCTypography.title(size: 16),
                  ),
                ),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down, size: 18),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.entry.answer.resolve(widget.lang),
                    style: MCTypography.body(size: 14, color: MCColors.inkSoft),
                  ),
                  if (widget.entry.relatedTopics.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(s.faqRelated.toUpperCase(), style: MCTypography.eyebrow()),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: widget.entry.relatedTopics
                          .map((t) => TagChip(label: t))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}
