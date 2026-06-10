import 'package:flutter/material.dart';

import '../../core/context_ext.dart';
import '../../models/ingredient_guide.dart';
import '../../theme/app_theme.dart';
import '../../widgets/decor.dart';

/// "Learn more" kitchen reference for an ingredient, as a calm paper sheet.
Future<void> showIngredientGuide(BuildContext context, String ingredientId) {
  final guide = context.scope.corpus.guideFor(ingredientId);
  if (guide == null) return Future.value();
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.paper,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _GuideSheet(guide: guide),
  );
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({required this.guide});
  final GuideEntry guide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.loc(guide.title),
                style: const TextStyle(
                    fontFamily: Fonts.display,
                    fontStyle: FontStyle.italic,
                    fontSize: 30,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            Text(context.loc(guide.description),
                style: const TextStyle(
                    fontFamily: Fonts.display, fontSize: 16, color: AppColors.ink, height: 1.4)),
            const SizedBox(height: 16),
            const DashedRule(),
            _block(context, context.tr('guide.usage'), context.loc(guide.usage)),
            _block(context, context.tr('guide.storage'), context.loc(guide.storage)),
            _block(context, context.tr('guide.where'), context.loc(guide.whereToFind)),
          ],
        ),
      ),
    );
  }

  Widget _block(BuildContext context, String label, String body) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MonoLabel(label, color: AppColors.terracotta),
            const SizedBox(height: 4),
            Text(body,
                style: const TextStyle(
                    fontFamily: Fonts.display, fontSize: 15, color: AppColors.ink, height: 1.4)),
          ],
        ),
      );
}
