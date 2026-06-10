import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'dashed_rule.dart';

/// Newspaper-style masthead: ornamental top rule, wordmark in Playfair italic,
/// date strip in JetBrains Mono small caps, second dashed rule underneath.
class Masthead extends StatelessWidget {
  final String title;
  final String? edition;
  final String? leftMeta;
  final String? rightMeta;
  const Masthead({
    super.key,
    required this.title,
    this.edition,
    this.leftMeta,
    this.rightMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DashedRule(thickness: 1.2, dashWidth: 6, dashSpace: 4),
          const SizedBox(height: 14),
          Center(
            child: Text(
              title.toLowerCase(),
              style: MorphType.display(size: 44),
              textAlign: TextAlign.center,
            ),
          ),
          if (edition != null) ...[
            const SizedBox(height: 6),
            Center(
              child: Text(
                edition!,
                style: MorphType.hand(size: 22, color: MorphColors.coral),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text((leftMeta ?? '—').toUpperCase(),
                  style: MorphType.smallCaps(size: 10)),
              Text('vol. 01',
                  style: MorphType.smallCaps(size: 10)),
              Text((rightMeta ?? '—').toUpperCase(),
                  style: MorphType.smallCaps(size: 10)),
            ],
          ),
          const SizedBox(height: 6),
          const DashedRule(thickness: 0.8),
        ],
      ),
    );
  }
}
