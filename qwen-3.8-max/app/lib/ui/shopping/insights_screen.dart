import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/corpus_repository.dart';
import '../../domain/shopping.dart';
import '../../state/app_model.dart';
import '../../state/library_model.dart';
import '../widgets.dart';

/// Shopping Insights: variety score, top added ingredients with frequency,
/// seasonal breakdown by month.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppModel>();
    final library = context.watch<LibraryModel>();
    final corpus = context.read<CorpusRepository>();
    final s = app.strings;
    final lang = app.lang;

    final events = library.shoppingEvents();
    final variety = ShoppingInsights.varietyScore(events);
    final top = ShoppingInsights.topIngredients(events);
    final months = ShoppingInsights.byMonth(events);
    final maxMonth =
        months.isEmpty ? 1 : months.map((m) => m.count).reduce((a, b) => a > b ? a : b);

    return PaperGrain(
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text('←',
                                style: Type.mono(
                                    size: 16, color: Paper.inkSoft)),
                          ),
                          const SizedBox(width: 14),
                          Text(s.get('insights'),
                              style: Type.displayBold(size: 26)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // ---- variety score
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Paper.white,
                          border: Border.all(color: Paper.rule),
                        ),
                        child: Column(
                          children: [
                            Text('$variety',
                                style: Type.displayBold(size: 44)),
                            const SizedBox(height: 4),
                            Text(s.get('uniqueIngredients').toUpperCase(),
                                style: Type.label()),
                            const SizedBox(height: 6),
                            Text(s.get('varietyScore'),
                                style: Type.hand(size: 17)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SectionHeader(text: s.get('topIngredients')),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: top.isEmpty
                      ? EmptyNote(title: s.get('empty'))
                      : Column(
                          children: [
                            for (final entry in top)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        tx(corpus.ingredients[entry.ingredientId]?.name,
                                            lang),
                                        style: Type.mono(size: 12),
                                      ),
                                    ),
                                    Text('${entry.count} ${s.get('times')}',
                                        style: Type.mono(
                                            size: 11, color: Paper.teal)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: SectionHeader(text: s.get('byMonth')),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: months.isEmpty
                      ? EmptyNote(title: s.get('empty'))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final month in months)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      child: Text(month.month,
                                          style: Type.mono(
                                              size: 11,
                                              color: Paper.inkSoft)),
                                    ),
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(2),
                                        child: LinearProgressIndicator(
                                          value: month.count / maxMonth,
                                          minHeight: 10,
                                          backgroundColor: Paper.deep,
                                          color: Paper.coral
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('${month.count}',
                                        style: Type.mono(size: 11)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}
