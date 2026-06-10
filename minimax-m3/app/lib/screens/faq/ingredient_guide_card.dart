import 'package:flutter/material.dart';

import '../../models/ingredient_guide.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../widgets/dashed_rule.dart';

class IngredientGuideCard extends StatelessWidget {
  final IngredientGuideEntry entry;
  final String lang;

  const IngredientGuideCard({super.key, required this.entry, required this.lang});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.name.resolve(lang).toLowerCase(),
              style: MCTypography.display(size: 30),
            ),
            const SizedBox(height: 10),
            const DashedRule(),
            const SizedBox(height: 16),
            _Section(label: 'description', body: entry.description.resolve(lang)),
            _Section(label: 'tips', body: entry.usageTips.resolve(lang)),
            _Section(label: 'storage', body: entry.storage.resolve(lang)),
            _Section(label: 'where to find', body: entry.whereToFind.resolve(lang)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  final String body;

  const _Section({required this.label, required this.body});

  @override
  Widget build(BuildContext context) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: MCTypography.eyebrow()),
          const SizedBox(height: 4),
          Text(body, style: MCTypography.body(size: 14.5, color: MCColors.inkSoft)),
        ],
      ),
    );
  }
}
