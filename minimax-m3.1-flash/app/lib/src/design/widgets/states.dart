import 'package:flutter/material.dart';

import '../motion.dart';
import '../palette.dart';
import '../typography.dart';
import 'rules.dart';

/// A calm, apologetic empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    super.key,
    this.message,
    this.action,
    this.glyph = '✳',
  });

  final String title;
  final String? message;
  final Widget? action;
  final String glyph;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              glyph,
              style: Type.scriptLarge(size: 40, color: MC.inkGhost),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Type.title(size: 18, color: MC.inkSoft),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Type.small(color: MC.inkFaint),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A shimmering paper placeholder used while a page loads.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 3,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MotionScope.reduceOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduce ? 0.45 : _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(MC.paperDeep, MC.ruleFaint, t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// A stack of skeleton lines standing in for a list.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.lineHeight = 14});

  final int count;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SkeletonBox(
              height: lineHeight,
              width: i.isEven ? double.infinity : null,
            ),
          ),
      ],
    );
  }
}

/// A small banner used for contextual notes and warnings.
class PaperNote extends StatelessWidget {
  const PaperNote({
    required this.text,
    super.key,
    this.accent = MC.mustard,
    this.icon,
    this.title,
  });

  final String text;
  final Color accent;
  final IconData? icon;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border(
          left: BorderSide(color: accent.withValues(alpha: 0.7), width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: accent),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!.toUpperCase(),
                    style: Type.label(size: 9.5, weight: FontWeight.w700, color: accent),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(text, style: Type.small(size: 13.5, color: MC.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A loading footer for paginated lists.
class PageLoadingIndicator extends StatelessWidget {
  const PageLoadingIndicator({super.key, this.visible = true});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(strokeWidth: 1.6),
            ),
            const SizedBox(width: 10),
            Text('turning the page…', style: Type.scriptSmall(size: 15)),
          ],
        ),
      ),
    );
  }
}

/// A soft divider for the bottom of a list.
class ListEndMark extends StatelessWidget {
  const ListEndMark({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 30),
      child: Column(
        children: <Widget>[
          const Eyebrow('fin'),
          if (label != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(label!, style: Type.scriptSmall(size: 15)),
          ],
        ],
      ),
    );
  }
}
