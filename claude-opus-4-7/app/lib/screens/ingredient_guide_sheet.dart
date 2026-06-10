import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/corpus.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../widgets/dashed_rule.dart';

class IngredientGuideSheet extends StatelessWidget {
  final String ingredientId;
  final String fallbackName;
  const IngredientGuideSheet(
      {super.key, required this.ingredientId, required this.fallbackName});

  @override
  Widget build(BuildContext context) {
    final corpus = context.read<Corpus>();
    final l = L10n.of(context);
    final lang = l.lang;
    final entry = corpus.guide[ingredientId];
    final name =
        corpus.ingredientDict.nodes[ingredientId]?.name.get(lang) ??
            fallbackName;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                color: MorphColors.inkFaint,
              ),
            ),
            const SizedBox(height: 18),
            Text(name.toLowerCase(),
                style: MorphType.display(size: 32)),
            const SizedBox(height: 4),
            Text('— a kitchen reference —',
                style: MorphType.hand(
                    size: 22, color: MorphColors.coral)),
            const SizedBox(height: 16),
            if (entry == null)
              Text('no further notes yet.',
                  style: MorphType.body(size: 15))
            else ...[
              _Section(title: 'what it is', body: entry.description.get(lang)),
              const DashedRule(),
              _Section(title: 'how to use', body: entry.usage.get(lang)),
              const DashedRule(),
              _Section(title: 'how to store', body: entry.storage.get(lang)),
              const DashedRule(),
              _Section(
                  title: 'where to find', body: entry.whereToFind.get(lang)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: MorphType.smallCaps(size: 10)),
          const SizedBox(height: 6),
          Text(body, style: MorphType.body(size: 15)),
        ],
      ),
    );
  }
}
