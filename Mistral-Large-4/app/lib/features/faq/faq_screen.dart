import 'dart:convert';

import 'package:flutter/material.dart' hide Typography;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/strings.dart';
import '../../core/model/faq.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../state/app_state.dart';
import '../../widgets/controls.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/paper.dart';

/// The help center: searchable FAQ entries with category filters. Contextual
/// HelpLinks across the app deep-link here (initialId expands and scrolls to
/// the entry).
class FaqScreen extends StatefulWidget {
  final String? initialId;
  final String? initialCategory;

  const FaqScreen({super.key, this.initialId, this.initialCategory});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<FaqEntry>? _entries;
  String? _error;
  String _query = '';
  String _category = 'all';
  final Set<String> _expanded = {};
  final Map<String, GlobalKey> _entryKeys = {};

  static const List<String> categories = [
    'dietary',
    'visibility',
    'features',
    'troubleshooting',
    'privacy',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && categories.contains(widget.initialCategory)) {
      _category = widget.initialCategory!;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/faqs.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final entries = (json['entries'] as List)
          .map((e) => FaqEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        if (widget.initialId != null && entries.any((e) => e.id == widget.initialId)) {
          _expanded.add(widget.initialId!);
        }
      });
      // Scroll the deep-linked entry into view after the first frame.
      if (widget.initialId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final key = _entryKeys[widget.initialId];
          if (key != null && mounted) {
            Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 350));
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final s = Strings(appState.profile.lang);
    final lang = appState.profile.lang;
    final entries = _entries;

    final filtered = entries == null
        ? const <FaqEntry>[]
        : entries.where((e) {
            if (_category != 'all' && e.category != _category) return false;
            if (_query.trim().isEmpty) return true;
            final q = _query.trim().toLowerCase();
            final haystack = [
              e.question.resolve(lang),
              e.answer.resolve(lang),
              ...e.tags,
            ].join(' ').toLowerCase();
            return q.split(RegExp(r'\s+')).every((token) => haystack.contains(token));
          }).toList();

    return PaperScaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                      child: Text('←', style: Typography.mono(14, color: Palette.teal)),
                    ),
                  ),
                  Text(s.faqTitle, style: Typography.display(26)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Palette.paperDeep.withValues(alpha: 0.4),
                  border: Border.all(color: Palette.ink, width: 1.4),
                ),
                child: TextField(
                  controller: _queryController,
                  style: Typography.hand(19),
                  decoration: InputDecoration(
                    hintText: s.faqSearchHint,
                    hintStyle: Typography.hand(19, color: Palette.inkFaint),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PaperChip(
                    label: s.faqAll,
                    selected: _category == 'all',
                    onTap: () => setState(() => _category = 'all'),
                  ),
                  for (final category in categories)
                    PaperChip(
                      label: s.faqCategoryLabel(category),
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
            ),
            const DashedRule(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8)),
            Expanded(
              child: entries == null
                  ? (_error != null
                      ? Center(child: Text(s.commonError, style: Typography.body(15, italic: true)))
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : filtered.isEmpty
                      ? EmptyState(title: s.faqEmpty)
                      : ListView.builder(
                          controller: _scrollController,
                          cacheExtent: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final expanded = _expanded.contains(entry.id);
                            final key = _entryKeys.putIfAbsent(entry.id, () => GlobalKey());
                            return Container(
                              key: key,
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Palette.paper,
                                border: Border.all(color: expanded ? Palette.ink : Palette.line, width: 1.2),
                              ),
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  if (expanded) {
                                    _expanded.remove(entry.id);
                                  } else {
                                    _expanded.add(entry.id);
                                  }
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              entry.question.resolve(lang),
                                              style: Typography.body(16, italic: true, color: Palette.ink),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(expanded ? '⌃' : '⌄',
                                              style: Typography.mono(12, color: Palette.coral)),
                                        ],
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          s.faqCategoryLabel(entry.category).toUpperCase(),
                                          style: Typography.mono(8.5, letterSpacing: 1.6, color: Palette.inkFaint),
                                        ),
                                      ),
                                      if (expanded) ...[
                                        const DashedRule(),
                                        Text(
                                          entry.answer.resolve(lang),
                                          style: Typography.body(14.5, color: Palette.inkSoft, height: 1.5),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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
