import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/corpus_repository.dart';
import '../../i18n/strings.dart';
import '../theme.dart';
import 'common.dart';
import 'paper.dart';

/// The "kitchen reference" card for an ingredient.
Future<void> showGuideSheet(BuildContext context, String ingredientId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _GuideSheet(ingredientId: ingredientId),
  );
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({required this.ingredientId});
  final String ingredientId;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CorpusRepository>();
    final tr = context.tr;
    final lang = tr.lang;
    final entry = repo.guide[ingredientId];
    if (entry == null) return const SizedBox(height: 120);
    final path = repo.ingredients.pathOf(ingredientId);
    Widget section(String label, String body) => Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, color: MC.coralDeep),
          const SizedBox(height: 4),
          Text(body, style: MT.serif(15, height: 1.5)),
        ],
      ),
    );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          MonoLabel(tr('guide.title')),
          const SizedBox(height: 6),
          Text(repo.ingredients.name(ingredientId, lang).toLowerCase(), style: MT.display(34)),
          if (path.length > 1)
            Text(path.map((n) => n.name.of(lang)).join(' › '), style: MT.mono(10, color: MC.inkFaint)),
          const SizedBox(height: 12),
          const DashedRule(),
          const SizedBox(height: 12),
          Text(entry.description.of(lang), style: MT.serif(17, height: 1.5)),
          section(tr('guide.usage'), entry.usage.of(lang)),
          section(tr('guide.storage'), entry.storage.of(lang)),
          section(tr('guide.where'), entry.whereToFind.of(lang)),
        ],
      ),
    );
  }
}
