import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme/palette.dart';
import '../core/theme/typography.dart';
import 'paper.dart';
import 'paper_controls.dart';

/// Keeps content readable on tablets and in landscape: a centred column that
/// never grows wider than [maxWidth].
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // heightFactor 1: shrink-wrap the height, so the column can also sit in a
    // bounded slot such as a bottom bar without swallowing the screen.
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A titled block of a form: italic heading, optional handwritten note, content.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.child, this.note, this.trailing});

  final String title;
  final String? note;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: AmpersandText(title, style: AppText.display(size: 23), fitWords: true),
                ),
              ),
              ?trailing,
            ],
          ),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 1), child: HandNote(note!, size: 19)),
          const SizedBox(height: 8),
          const DashedRule(),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Title row for tab screens: big italic title, handwritten note and actions.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, required this.title, this.note, this.actions = const <Widget>[]});

  final String title;
  final String? note;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: AmpersandText(title, style: AppText.display(size: 36), fitWords: true),
                ),
              ),
              ...actions,
            ],
          ),
          if (note != null) HandNote(note!, size: 21),
          const SizedBox(height: 8),
          const DoubleRule(color: Palette.ink),
        ],
      ),
    );
  }
}

/// Animates a change of its child's size, or resizes at once when motion is
/// reduced. (A zero-duration [AnimatedSize] trips a layout assertion, so the
/// reduced-motion path uses no animation widget at all.)
class MotionSize extends StatelessWidget {
  const MotionSize({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) return child;
    return AnimatedSize(duration: duration, curve: curve, alignment: alignment, child: child);
  }
}

/// Buttons that share one line. When they do not fit, as with large text, the
/// last ones move to the next line instead of overflowing. The first button sits
/// at the start of the line and the last at its end.
class ButtonRow extends StatelessWidget {
  const ButtonRow({super.key, required this.children, this.spacing = 8});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: spacing,
      runSpacing: spacing,
      children: children,
    );
  }
}
