import 'package:flutter/material.dart';

import '../palette.dart';
import '../typography.dart';

/// A hand-drawn dashed rule, the way a pencil line runs under a heading.
class DashedRule extends StatelessWidget {
  const DashedRule({
    super.key,
    this.color = MC.rule,
    this.dash = 4,
    this.gap = 4,
    this.thickness = 1,
    this.height = 1,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height + (thickness > 1 ? thickness : 0),
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(
          color: color,
          dash: dash,
          gap: gap,
          thickness: thickness,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({
    required this.color,
    required this.dash,
    required this.gap,
    required this.thickness,
  });

  final Color color;
  final double dash;
  final double gap;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color ||
      old.dash != dash ||
      old.gap != gap ||
      old.thickness != thickness;
}

/// A heading with a dashed rule running out to the right.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    super.key,
    this.trailing,
    this.rule = true,
    this.color = MC.ink,
  });

  final String title;
  final Widget? trailing;
  final bool rule;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(title, style: Type.labelStrong(color: color)),
        if (rule) ...<Widget>[
          const SizedBox(width: 12),
          const Expanded(child: DashedRule()),
        ],
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}

/// A small mono eyebrow label, e.g. "no. 04 · 25 min".
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = MC.inkFaint});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Type.label(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A handwritten marginal note.
class Marginalia extends StatelessWidget {
  const Marginalia(this.text, {super.key, this.color = MC.inkFaint, this.size = 16});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Type.scriptSmall(size: size, color: color),
    );
  }
}
