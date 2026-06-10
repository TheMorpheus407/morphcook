import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets/decor.dart';

/// Help center: searchable FAQ with category filters. UI copy elsewhere
/// deep-links here via [initialEntryId].
class FaqScreen extends StatefulWidget {
  final String? initialEntryId;
  const FaqScreen({super.key, this.initialEntryId});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  String _query = '';
  String? _category;
  late final Set<String> _expanded = {
    if (widget.initialEntryId != null) widget.initialEntryId!,
  };

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEntryId;
    if (initial != null) {
      // Focus the linked entry's category so it is visible immediately.
      final state = context.read<AppState>();
      _category = state.corpus.faqs.byId(initial)?.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final lang = state.lang;
    final faqs = state.corpus.faqs;

    final entries = faqs.entries
        .where((e) => _category == null || e.category == _category)
        .where((e) => e.matches(_query, lang))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s('helpCenter'),
            style: MorphText.display.copyWith(fontSize: 22)),
      ),
      body: PaperBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: MorphText.mono.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: s('faqSearchHint'),
                  hintStyle: MorphText.mono.copyWith(
                      fontSize: 13, color: MorphColors.inkFaint),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: MorphColors.inkSoft),
                  enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: MorphColors.line)),
                  focusedBorder: const UnderlineInputBorder(
                      borderSide:
                          BorderSide(color: MorphColors.terracotta)),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MonoChip(
                      label: s('all'),
                      selected: _category == null,
                      onTap: () => setState(() => _category = null),
                    ),
                  ),
                  for (final cat in faqs.categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MonoChip(
                        label: cat.name.of(lang),
                        selected: _category == cat.id,
                        onTap: () => setState(() => _category = cat.id),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  final expanded = _expanded.contains(entry.id);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => expanded
                            ? _expanded.remove(entry.id)
                            : _expanded.add(entry.id)),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(entry.question.of(lang),
                                    style: MorphText.serif
                                        .copyWith(fontSize: 15)),
                              ),
                              Icon(
                                expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 16,
                                color: MorphColors.inkSoft,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(entry.answer.of(lang),
                              style: MorphText.mono.copyWith(
                                  fontSize: 12,
                                  color: MorphColors.inkSoft)),
                        ),
                      const DashedDivider(height: 6),
                    ],
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
