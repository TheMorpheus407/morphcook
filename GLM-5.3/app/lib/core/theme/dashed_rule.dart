import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'app_theme.dart';

/// A dashed horizontal rule (the tumblr aesthetic) with an optional center
/// glyph — ampersands & little crosses are typical.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color, this.glyph, this.thickness = 1.2});

  final Color? color;
  final String? glyph;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.inkFaint;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      const dashWidth = 6.0;
      const dashGap = 5.0;
      const glyphSpace = 28.0;
      final dashCount = ((width - (glyph == null ? 0 : glyphSpace)) /
              (dashWidth + dashGap))
          .floor();
      return SizedBox(
        height: 14,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: [
                for (var i = 0; i < dashCount; i++) ...[
                  Container(
                    width: dashWidth,
                    height: thickness,
                    color: c,
                  ),
                  const SizedBox(width: dashGap),
                ],
              ],
            ),
            if (glyph != null)
              Container(
                color: AppColors.paper,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  glyph!,
                  style: AppFonts.mono(size: 12, color: c),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// A double rule — the newspaper masthead divider.
class DoubleRule extends StatelessWidget {
  const DoubleRule({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.ink;
    return Column(
      children: [
        Container(height: 2, color: c),
        const SizedBox(height: 2),
        Container(height: 1, color: c),
      ],
    );
  }
}
