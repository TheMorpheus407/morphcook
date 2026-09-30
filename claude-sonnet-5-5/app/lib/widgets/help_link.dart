import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// A contextual link from UI copy into the Help Center. It opens the FAQ
/// straight at [entryId] (or a [category]).
class HelpLink extends StatelessWidget {
  const HelpLink({super.key, required this.label, this.entryId, this.category, this.color = Palette.coralDeep});

  final String label;
  final String? entryId;
  final String? category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openFaq(context, entryId: entryId, category: category),
        borderRadius: BorderRadius.circular(3),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline, size: 16, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: AppText.mono(size: 11.5, color: color, weight: FontWeight.w500).copyWith(
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                      decorationColor: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
