import 'package:flutter/material.dart';

import '../core/i18n/app_strings.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'paper_controls.dart';

/// Empty list: a handwritten headline, one line of explanation, one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.action,
    this.onAction,
    this.icon = Icons.menu_book_outlined,
  });

  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HandNote(title, size: 30, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppText.serif(size: 16, color: Palette.inkSoft),
              ),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 18),
              PaperButton(label: action!, icon: icon, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// A load failed: say so and offer a retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HandNote(s('common.error'), size: 26),
          const SizedBox(height: 12),
          PaperButton(label: s('common.retry'), icon: Icons.refresh, onPressed: onRetry),
        ],
      ),
    );
  }
}
