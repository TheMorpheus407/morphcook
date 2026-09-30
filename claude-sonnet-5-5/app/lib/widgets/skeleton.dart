import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme/palette.dart';

/// A paper-toned loading bar with a slow highlight sweep. With reduced motion
/// it stays still.
class SkeletonBar extends StatefulWidget {
  const SkeletonBar({super.key, this.width, this.height = 14, this.radius = 2});

  final double? width;
  final double height;
  final double radius;

  @override
  State<SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<SkeletonBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1.4 + 2.8 * t, 0),
                end: Alignment(-0.4 + 2.8 * t, 0),
                colors: const [Palette.paperDeep, Palette.paperLight, Palette.paperDeep],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A skeleton list row: thumbnail and two lines of text.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SkeletonBar(width: height - 24, height: height - 24),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBar(width: 170, height: 16),
                  SizedBox(height: 10),
                  SkeletonBar(width: 110, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Several [SkeletonRow]s while the first page loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 5, this.rowHeight = 96, this.padding = EdgeInsets.zero});

  final int count;
  final double rowHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(children: [for (var i = 0; i < count; i++) SkeletonRow(height: rowHeight)]),
    );
  }
}
