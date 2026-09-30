import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/faq.dart';
import '../../widgets/layout.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';
import '../../widgets/state_views.dart';

/// Help Center: searchable FAQ with category filters. Other screens link
/// straight to an entry (`initialEntryId`) from their own copy.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialEntryId, this.initialCategory});

  final String? initialEntryId;
  final String? initialCategory;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController _query = TextEditingController();
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  late final Set<String> _open = {if (widget.initialEntryId != null) widget.initialEntryId!};
  late String? _category = widget.initialCategory;
  FaqLibrary? _library;
  bool _scrolled = false;

  @override
  void initState() {
    super.initState();
    context.read<Corpus>().faqs().then((library) {
      if (!mounted) return;
      setState(() => _library = library);
      final id = widget.initialEntryId;
      final entry = id == null ? null : library.entry(id);
      if (entry != null && _category != null && _category != entry.category) _category = null;
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _scrollToInitial() {
    final id = widget.initialEntryId;
    if (_scrolled || id == null) return;
    final context = _keys[id]?.currentContext;
    if (context == null) return;
    _scrolled = true;
    // Read without listening: this runs after the frame, outside of build.
    final duration = this.context.read<MotionPreferences>().scale(const Duration(milliseconds: 350));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) Scrollable.ensureVisible(context, duration: duration, alignment: 0.05);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final library = _library;
    final results = library?.search(_query.text, s.lang, category: _category) ?? const <FaqEntry>[];
    if (library != null) WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());

    return PaperScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(-12, 0),
                        child: PaperIconButton(
                          icon: Icons.arrow_back,
                          tooltip: s('common.back'),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                  TabHeader(title: s('faq.title'), note: s('faq.note')),
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.search,
                    style: AppText.serifItalic(size: 19),
                    decoration: InputDecoration(
                      hintText: s('faq.search'),
                      prefixIcon: const Icon(Icons.search, size: 22),
                      suffixIcon: _query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: s('common.clear'),
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => setState(_query.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (library != null)
                    SizedBox(
                      height: 46,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          PaperChip(
                            label: s('faq.all'),
                            style: PaperChipStyle.mono,
                            selected: _category == null,
                            onTap: () => setState(() => _category = null),
                          ),
                          for (final category in library.categories) ...[
                            const SizedBox(width: 8),
                            PaperChip(
                              label: category.name.resolve(s.lang),
                              style: PaperChipStyle.mono,
                              selected: _category == category.id,
                              onTap: () => setState(() => _category = _category == category.id ? null : category.id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (library == null)
                    const Padding(
                      padding: EdgeInsets.all(30),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (results.isEmpty)
                    SizedBox(
                      height: 260,
                      child: EmptyState(title: s('faq.empty.title'), body: s('faq.empty.body')),
                    )
                  else
                    for (final entry in results)
                      _FaqTile(
                        key: _keys.putIfAbsent(entry.id, GlobalKey.new),
                        entry: entry,
                        library: library,
                        open: _open.contains(entry.id),
                        onToggle: () =>
                            setState(() => _open.contains(entry.id) ? _open.remove(entry.id) : _open.add(entry.id)),
                        onRelated: (id) => setState(() {
                          _open.add(id);
                          _category = null;
                          _query.clear();
                          _scrolled = false;
                        }),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    super.key,
    required this.entry,
    required this.library,
    required this.open,
    required this.onToggle,
    required this.onRelated,
  });

  final FaqEntry entry;
  final FaqLibrary library;
  final bool open;
  final VoidCallback onToggle;
  final ValueChanged<String> onRelated;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final categoryName = library.categories
        .firstWhere((c) => c.id == entry.category, orElse: () => library.categories.first)
        .name
        .resolve(s.lang);
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Palette.rule)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: entry.question.resolve(s.lang),
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MonoLabel(categoryName, color: Palette.coralDeep),
                          const SizedBox(height: 3),
                          Text(
                            entry.question.resolve(s.lang),
                            style: AppText.serifItalic(size: 19, weight: FontWeight.w500, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: context.motion(const Duration(milliseconds: 180)),
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8, top: 14),
                        child: Icon(Icons.keyboard_arrow_down, color: Palette.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          MotionSize(
            duration: const Duration(milliseconds: 200),
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.answer.resolve(s.lang), style: AppText.serif(size: 16, height: 1.6)),
                        if (entry.related.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          HandNote(s('faq.related'), size: 21),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final id in entry.related)
                                if (library.entry(id) != null)
                                  PaperChip(
                                    label: library.entry(id)!.question.resolve(s.lang),
                                    dense: true,
                                    style: PaperChipStyle.mono,
                                    selected: false,
                                    onTap: () => onRelated(id),
                                  ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
