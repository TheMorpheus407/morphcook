import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/corpus_repository.dart';
import '../../core/l10n.dart';
import '../../core/models/faq.dart';
import '../../core/models/local_text.dart';
import '../../core/storage/profile_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/paper_grain.dart';

/// Searchable, category-filtered FAQ from the bundled corpus.
class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  /// Stable display order for known categories; extras are appended.
  static const _categoryOrder = [
    'matching',
    'recipes',
    'features',
    'troubleshooting',
    'privacy',
  ];

  final _searchController = TextEditingController();
  String _query = '';
  String? _category; // null = all

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    final profile = context.watch<ProfileStore>().profile;
    final lang = profile.lang;
    final reduce =
        profile.reduceMotion ?? MediaQuery.disableAnimationsOf(context);
    final faqs = context.read<CorpusRepository>().faqs;

    final present = faqs.map((f) => f.category).toSet();
    final categories = [
      ..._categoryOrder.where(present.contains),
      ...present.where((c) => !_categoryOrder.contains(c)),
    ];

    final q = _query.trim().toLowerCase();
    final filtered = faqs.where((f) {
      if (_category != null && f.category != _category) return false;
      if (q.isEmpty) return true;
      return localize(f.question, lang).toLowerCase().contains(q) ||
          localize(f.answer, lang).toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('faq.title'), style: AppText.headline())),
      body: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: TextField(
                  controller: _searchController,
                  cursorColor: AppColors.coral,
                  style: AppText.body(size: 16),
                  decoration: InputDecoration(
                    hintText: s.t('faq.search.hint'),
                    hintStyle: AppText.body(size: 15, color: AppColors.inkSoft),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.inkSoft,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.inkSoft,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.inkSoft),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.coral),
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.t('faq.cat.all')),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final cat in categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s.t('faq.cat.$cat')),
                          selected: _category == cat,
                          onSelected: (_) => setState(() => _category = cat),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            s.t('faq.empty'),
                            textAlign: TextAlign.center,
                            style: AppText.handwritten(size: 22),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          Widget card = _FaqCard(
                            entry: filtered[i],
                            lang: lang,
                          );
                          if (!reduce) {
                            card = card.animate().fadeIn(duration: 220.ms);
                          }
                          return card;
                        },
                      ),
              ),
            ],
          ),
          const Positioned.fill(child: PaperGrain()),
        ],
      ),
    );
  }
}

/// One FAQ entry: question in Playfair italic, answer in body text, optional
/// quiet "read more →" link to a related route.
class _FaqCard extends StatelessWidget {
  final FaqEntry entry;
  final String lang;

  const _FaqCard({required this.entry, required this.lang});

  @override
  Widget build(BuildContext context) {
    final s = S(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.polaroid,
        border: Border.all(color: AppColors.inkSoft, width: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          iconColor: AppColors.inkSoft,
          collapsedIconColor: AppColors.inkSoft,
          title: Text(
            localize(entry.question, lang),
            style: AppText.headline(size: 17),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                localize(entry.answer, lang),
                style: AppText.body(size: 14),
              ),
            ),
            if (entry.relatedRoute != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    foregroundColor: AppColors.teal,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pushNamed(entry.relatedRoute!),
                  child: Text(
                    s.t('faq.readMore'),
                    style: AppText.monoLabel(size: 11, color: AppColors.teal),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
