import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../../theme/typography.dart';
import '../navigation.dart';

/// Contextual link into the FAQ, e.g. "why don't i see some dishes?".
class HelpLink extends StatelessWidget {
  const HelpLink({super.key, required this.faqId, required this.label, this.color = Palette.inkSoft, this.align = TextAlign.start});
  final String faqId;
  final String label;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Routes.openFaq(context, id: faqId),
        borderRadius: BorderRadius.circular(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: align == TextAlign.center ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Text('?', style: AppText.mono(color: color, size: 11, weight: FontWeight.w700)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toLowerCase(),
                  style: AppText.mono(color: color, size: 11.5).copyWith(decoration: TextDecoration.underline, decorationColor: Palette.rule, decorationStyle: TextDecorationStyle.dashed),
                ),
              ),
            ],
          ),
        ),
      );
}
