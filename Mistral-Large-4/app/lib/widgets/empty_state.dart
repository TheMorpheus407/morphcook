import 'package:flutter/material.dart';

import '../core/theme/palette.dart';
import 'paper.dart';

/// Centered empty state: handwritten headline + mono body.
class EmptyState extends StatelessWidget {
  final String title;
  final String? body;
  final Widget? action;

  const EmptyState({super.key, required this.title, this.body, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HandNote(title, size: 24, color: Palette.inkSoft),
              if (body != null) ...[
                const SizedBox(height: 8),
                Text(
                  body!,
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                    color: Palette.inkFaint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      );
}
