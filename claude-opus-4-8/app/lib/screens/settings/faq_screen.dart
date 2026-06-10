import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../core/localized.dart';
import '../../models/faq.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';
import '../../widgets/paper_background.dart';

/// The help center, pushed from settings. A search field over question/answer
/// text plus category-filter chips, then expandable entries. Pushed route, so
/// it owns a full Scaffold + AppBar and wraps its body in PaperBackground.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String _category = '_all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<FaqEntry> _filtered(BuildContext context) {
    final lang = context.lang;
    final q = _query.trim().toLowerCase();
    return context.scope.corpus.faqs.where((e) {
      if (_category != '_all' && e.category != _category) return false;
      if (q.isEmpty) return true;
      final question = e.question.resolve(lang).toLowerCase();
      final answer = e.answer.resolve(lang).toLowerCase();
      return question.contains(q) || answer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final entries = _filtered(context);
    final categories = context.scope.corpus.faqCategories;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          context.tr('faq.title').toLowerCase(),
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            fontSize: 24,
            color: AppColors.ink,
          ),
        ),
      ),
      body: PaperBackground(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _searchField(context),
              ),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _categoryChip(
                      context,
                      id: '_all',
                      label: context.tr('faq.all'),
                    ),
                    for (final cat in categories)
                      _categoryChip(
                        context,
                        id: cat.id,
                        label: context.loc(cat.label),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: DashedRule(),
              ),
              Expanded(
                child: entries.isEmpty
                    ? _empty(context)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: DashedRule(),
                        ),
                        itemBuilder: (context, i) => _FaqTile(entry: entries[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      style: const TextStyle(
        fontFamily: Fonts.display,
        fontSize: 16,
        color: AppColors.ink,
      ),
      decoration: InputDecoration(
        isDense: true,
        hintText: context.tr('faq.search'),
        hintStyle: const TextStyle(
          fontFamily: Fonts.display,
          fontStyle: FontStyle.italic,
          fontSize: 16,
          color: AppColors.inkFaint,
        ),
        prefixIcon: const Icon(Icons.search, size: 19, color: AppColors.inkSoft),
        suffixIcon: _query.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close, size: 17, color: AppColors.inkSoft),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                },
              ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.inkFaint),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.terracotta),
        ),
      ),
    );
  }

  Widget _categoryChip(BuildContext context,
      {required String id, required String label}) {
    final isOn = _category == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _category = id),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isOn ? AppColors.terracotta.withValues(alpha: 0.10) : null,
            border: Border.all(
              color: isOn ? AppColors.terracotta : AppColors.inkSoft,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: Fonts.mono,
              fontSize: 12,
              letterSpacing: 0.5,
              color: isOn ? AppColors.terracotta : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final de = context.lang == AppLang.de;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: HandNote(
          de
              ? 'nichts gefunden — versuch andere Worte'
              : 'nothing here — try different words',
          size: 22,
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.entry});
  final FaqEntry entry;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // ExpansionTile draws Material dividers by default; strip them so the
      // dashed rules carry the rhythm.
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 14, right: 8),
        iconColor: AppColors.inkSoft,
        collapsedIconColor: AppColors.inkSoft,
        title: Text(
          context.loc(entry.question),
          style: const TextStyle(
            fontFamily: Fonts.display,
            fontStyle: FontStyle.italic,
            fontSize: 19,
            color: AppColors.ink,
            height: 1.2,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.loc(entry.answer),
              style: const TextStyle(
                fontFamily: Fonts.display,
                fontSize: 16,
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
