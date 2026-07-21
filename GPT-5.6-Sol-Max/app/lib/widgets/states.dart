import 'package:flutter/material.dart';

import '../core/brand.dart';

class EmptyPageNote extends StatelessWidget {
  const EmptyPageNote({
    super.key,
    required this.icon,
    required this.title,
    this.action,
  });

  final IconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: BrandColors.coral),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class EditorialSkeleton extends StatefulWidget {
  const EditorialSkeleton({super.key, this.rows = 3});
  final int rows;

  @override
  State<EditorialSkeleton> createState() => _EditorialSkeletonState();
}

class _EditorialSkeletonState extends State<EditorialSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .35, end: .75).animate(_controller),
    child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.rows,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, _) =>
          Container(height: 116, color: BrandColors.paperDeep),
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

void showPaperSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            color: BrandColors.paper,
          ),
        ),
        backgroundColor: BrandColors.ink,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
    );
}
