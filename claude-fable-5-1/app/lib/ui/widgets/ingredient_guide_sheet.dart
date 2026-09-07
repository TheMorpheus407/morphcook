import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_controller.dart';
import '../../theme/palette.dart';
import '../../theme/paper.dart';
import '../../theme/typography.dart';
import '../../theme/widgets.dart';
import '../l10n.dart';

/// "Learn more" for an ingredient: the kitchen reference, plus a quick way
/// to avoid the ingredient from now on.
Future<void> showIngredientGuide(BuildContext context, String ingredientId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GuideSheet(ingredientId: ingredientId),
  );
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({required this.ingredientId});
  final String ingredientId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final s = context.s;
    final lang = app.lang;
    final node = app.repo.ingredients.byId[ingredientId];
    final entry = app.repo.guide[ingredientId];
    final avoiding = app.profile.avoidIngredients.contains(ingredientId) ||
        app.matchContext.avoidIngredients.contains(ingredientId);
    final ancestors = app.repo.ingredients.ancestors(ingredientId).map((a) => app.repo.ingredients.byId[a]?.name.of(lang) ?? a).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: entry == null ? 0.42 : 0.72,
      maxChildSize: 0.94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
        children: [
          MonoLabel(s('guide.title')),
          const SizedBox(height: 6),
          Text(node?.name.of(lang) ?? ingredientId, style: AppText.display(size: 28)),
          if (ancestors.isNotEmpty) ...[
            const SizedBox(height: 4),
            MetaLine(ancestors.reversed.toList(), color: Palette.inkFaint),
          ],
          const SizedBox(height: 14),
          const DashedRule(),
          const SizedBox(height: 14),
          if (entry == null)
            HandNote(s('guide.none'))
          else ...[
            _Block(kicker: s('guide.description'), text: entry.description.of(lang)),
            _Block(kicker: s('guide.usage'), text: entry.usageTips.of(lang)),
            _Block(kicker: s('guide.storage'), text: entry.storage.of(lang)),
            _Block(kicker: s('guide.where'), text: entry.whereToFind.of(lang)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PaperButton(
                  label: avoiding ? s('guide.avoiding') : s('guide.avoid'),
                  kind: PaperButtonKind.secondary,
                  icon: avoiding ? Icons.check : Icons.block_outlined,
                  expand: true,
                  onPressed: avoiding
                      ? null
                      : () async {
                          await app.updateProfile(app.profile.copyWith(avoidIngredients: {...app.profile.avoidIngredients, ingredientId}));
                          if (context.mounted) Navigator.of(context).pop();
                        },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.kicker, required this.text});
  final String kicker;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(kicker),
            const SizedBox(height: 4),
            Text(text, style: AppText.body(size: 14.5)),
          ],
        ),
      );
}
