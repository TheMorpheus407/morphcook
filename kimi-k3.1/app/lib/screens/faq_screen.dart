import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../models/content.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/paper_widgets.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key, this.initialFaqId, this.onNavigate});
  final String? initialFaqId;
  final ValueChanged<String>? onNavigate;

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  final TextEditingController searchController = TextEditingController();
  String query = '';
  String category = 'all';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().repository.faqs.where(
      (entry) => entry.matches(query, context.lang, category),
    );
    const categories = [
      'all',
      'matching',
      'recipes',
      'cookbook',
      'cooking',
      'planning',
      'shopping',
      'backup',
      'troubleshooting',
    ];
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.t('help_center'))),
      body: Paper(
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.t('faq_title'),
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.handwritten
                        .copyWith(color: AppColors.coral),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: context.l10n.t('faq_hint'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              SizedBox(
                height: 43,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final id = categories[index];
                    return ChoiceChip(
                      label: Text(context.l10n.t('faq_$id')),
                      selected: category == id,
                      onSelected: (_) => setState(() => category = id),
                    );
                  },
                ),
              ),
              const DashedRule(),
              Expanded(
                child: entries.isEmpty
                    ? EmptyState(
                        title: context.l10n.t('faq_empty'),
                        body: context.l10n.t('tagline'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        itemCount: entries.length,
                        itemBuilder: (context, index) => _FaqTile(
                          entry: entries.elementAt(index),
                          initiallyExpanded:
                              entries.elementAt(index).id ==
                              widget.initialFaqId,
                          onNavigate: widget.onNavigate,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.entry,
    required this.initiallyExpanded,
    this.onNavigate,
  });
  final FaqEntry entry;
  final bool initiallyExpanded;
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.paperLight.withValues(alpha: 0.6),
        border: Border.all(color: AppColors.muted.withValues(alpha: 0.18)),
      ),
      child: ExpansionTile(
        key: PageStorageKey(entry.id),
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: AppColors.coral,
        collapsedIconColor: AppColors.teal,
        title: Text(
          entry.question.of(locale),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          context.l10n.t('faq_${entry.category}'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              entry.answer.of(locale),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          if (entry.relatedRoute.isNotEmpty && onNavigate != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onNavigate!(entry.relatedRoute),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(context.l10n.t('see_all')),
              ),
            ),
        ],
      ),
    );
  }
}
