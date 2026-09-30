import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_strings.dart';
import '../../core/labels.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';
import '../../data/corpus.dart';
import '../../data/models/ingredient_guide.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_controls.dart';

/// "Learn more" about an ingredient: what it is, how to use it, how to keep it
/// and where to find it (`assets/ingredient-guide.json`).
Future<void> showIngredientGuide(BuildContext context, String ingredientId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Palette.paperLight,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (context) => _GuideSheet(ingredientId: ingredientId),
  );
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({required this.ingredientId});

  final String ingredientId;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final corpus = context.read<Corpus>();
    final name = corpus.ingredients.nameOf(ingredientId, s.lang);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return PaperBackground(
          color: Palette.paperLight,
          child: FutureBuilder<IngredientGuide>(
            future: corpus.guide(),
            builder: (context, snapshot) {
              final entry = snapshot.data?.forIngredient(ingredientId);
              return ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(color: Palette.rule, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: MonoLabel(s('guide.kicker'), color: Palette.coralDeep)),
                      PaperIconButton(
                        icon: Icons.close,
                        tooltip: s('common.close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Semantics(header: true, child: Text(lower(name), style: AppText.display(size: 40))),
                  const SizedBox(height: 10),
                  const DashedRule(),
                  const SizedBox(height: 16),
                  if (entry == null && snapshot.connectionState == ConnectionState.done)
                    Text(s('guide.none'), style: AppText.serifItalic(size: 17))
                  else if (entry != null) ...[
                    _Block(title: s('guide.what'), text: entry.description.resolve(s.lang)),
                    _Block(title: s('guide.use'), text: entry.usage.resolve(s.lang)),
                    _Block(title: s('guide.store'), text: entry.storage.resolve(s.lang)),
                    _Block(title: s('guide.find'), text: entry.whereToFind.resolve(s.lang)),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HandNote(title, size: 24),
          const SizedBox(height: 2),
          Text(text, style: AppText.serif(size: 16.5, height: 1.55)),
        ],
      ),
    );
  }
}
