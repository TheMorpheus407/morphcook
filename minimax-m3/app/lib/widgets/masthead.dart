import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';
import 'dashed_rule.dart';

/// Newspaper-masthead: a title set huge in italic Playfair with the issue
/// number and date typed in a mono caption underneath. Sits at the top of
/// the home feed and (smaller) over section headers.
class Masthead extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? issueLabel; // e.g. "issue 042 · sun mar 16"
  final TextAlign align;
  final double titleSize;

  const Masthead({
    super.key,
    required this.title,
    this.subtitle,
    this.issueLabel,
    this.align = TextAlign.center,
    this.titleSize = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (issueLabel != null) ...[
          Text(issueLabel!, style: MCTypography.eyebrow()),
          const SizedBox(height: 4),
          const DashedRule(),
          const SizedBox(height: 12),
        ],
        Text(
          title.toLowerCase(),
          style: MCTypography.masthead(color: MCColors.ink).copyWith(fontSize: titleSize),
          textAlign: align,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!.toLowerCase(),
            style: MCTypography.italic(size: 14, color: MCColors.inkFaded),
            textAlign: align,
          ),
        ],
        const SizedBox(height: 14),
        const DashedRule(),
      ],
    );
  }
}

/// A smaller-scaled section header used between feed sections — three pieces of
/// text (eyebrow, title, optional caption) wrapped in dashed rules.
class SectionHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? caption;

  const SectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DashedRule(),
          const SizedBox(height: 12),
          if (eyebrow != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(eyebrow!.toUpperCase(), style: MCTypography.eyebrow()),
            ),
          Text(
            title.toLowerCase(),
            style: MCTypography.title(size: 26),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: MCTypography.italic(size: 14, color: MCColors.inkFaded),
            ),
          ],
        ],
      ),
    );
  }
}
