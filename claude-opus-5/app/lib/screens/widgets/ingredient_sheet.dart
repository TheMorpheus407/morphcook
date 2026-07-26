import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/palette.dart';
import '../../design/widgets/common.dart';
import '../../design/widgets/paper.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';

/// The "Learn more" sheet: what it is, what to do with it, how to keep it,
/// where to find it. Only exists for ingredients that are easy to get wrong.
Future<void> showIngredientGuide(BuildContext context, String ingredientId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => IngredientGuideSheet(ingredientId: ingredientId),
  );
}

class IngredientGuideSheet extends StatelessWidget {
  const IngredientGuideSheet({super.key, required this.ingredientId});

  final String ingredientId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final colors = context.colors;
    final entry = state.repository.guideFor(ingredientId);
    final node = state.repository.ingredients[ingredientId];

    if (entry == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: EmptyNote(
          headline: node?.label(s.lang) ?? ingredientId,
          body: s.faqNoResults,
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 36),
        children: [
          Center(child: Container(width: 40, height: 3, color: colors.edge)),
          const SizedBox(height: 18),
          Text(
            entry.title(s.lang).toLowerCase(),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          if (node != null) ...[
            const SizedBox(height: 4),
            Text(
              state.repository.ingredients.aisleLabel(node.aisle)(s.lang),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: 16),
          DashedRule(color: colors.edge),
          const SizedBox(height: 18),
          _Block(label: s.guideWhatItIs, body: entry.summary(s.lang)),
          _Block(label: s.guideHowToUse, body: entry.usage(s.lang)),
          _Block(label: s.guideStorage, body: entry.storage(s.lang)),
          _Block(label: s.guideWhereToFind, body: entry.whereToFind(s.lang)),
          if (node != null && node.flags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Eyebrow(s.dishContains),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final flag in node.flags)
                  InkChip(
                    label: state.repository.ontology.labelForFlag(flag)(s.lang),
                    dense: true,
                    tone: colors.secondary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(label),
        const SizedBox(height: 6),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
