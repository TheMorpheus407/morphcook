import 'package:flutter/material.dart' hide Typography;

import '../core/theme/palette.dart';
import '../core/theme/typography.dart';

/// Contextual help link from UI copy into the FAQ. Opens the help center
/// scrolled to (and filtered by) the given entry id.
class HelpLink extends StatelessWidget {
  final String faqId;
  final String label;
  final void Function(String faqId) onOpen;

  const HelpLink({super.key, required this.faqId, required this.onOpen, this.label = '?' });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => onOpen(faqId),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Palette.teal, width: 1.2),
          ),
          child: Center(
            child: Text('?', style: Typography.mono(10, weight: FontWeight.w700, color: Palette.teal)),
          ),
        ),
      );
}

/// Small "learn more" text button used in ingredient lists.
class LearnMoreLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const LearnMoreLink({super.key, required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(
          label.toUpperCase(),
          style: Typography.mono(9, weight: FontWeight.w700, letterSpacing: 1.4, color: Palette.teal),
        ),
      );
}
