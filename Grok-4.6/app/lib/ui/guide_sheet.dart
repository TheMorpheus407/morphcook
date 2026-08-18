import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_state.dart';
import 'strings.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showIngredientGuide(BuildContext context, String ingredientId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LedgerScope.colors(context).linen,
    builder: (_) => IngredientGuideSheet(ingredientId: ingredientId),
  );
}

class IngredientGuideSheet extends StatelessWidget {
  final String ingredientId;
  const IngredientGuideSheet({super.key, required this.ingredientId});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.lang);
    final entry = state.corpus.guide[ingredientId];
    final name = state.corpus.dictionary.nameOf(ingredientId, state.lang);
    return PaperBackdrop(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionLabel(s('kitchenReference')),
              const SizedBox(height: 8),
              Text(name, style: Theme.of(context).textTheme.displayMedium),
              if (entry == null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(s('comboUnavailable')),
                )
              else ...[
                const SizedBox(height: 12),
                Text(entry.description.of(state.lang)),
                const SizedBox(height: 16),
                SectionLabel(s('tips')),
                Text(entry.tips.of(state.lang)),
                const SizedBox(height: 16),
                SectionLabel(s('storage')),
                Text(entry.storage.of(state.lang)),
                const SizedBox(height: 16),
                SectionLabel(s('whereToFind')),
                Text(entry.whereToFind.of(state.lang)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
