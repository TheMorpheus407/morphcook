import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../theme/morph_theme.dart';
import 'paper_surface.dart';
import 'striped_placeholder.dart';

class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color, this.dash = 5, this.gap = 5});

  final Color? color;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedRulePainter(
          color: color ?? context.morph.ink.withValues(alpha: .4),
          dash: dash,
          gap: gap,
        ),
      ),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter({
    required this.color,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, .5),
        Offset(math.min(x + dash, size.width), .5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    super.key,
    this.kicker,
    this.trailing,
    this.padding = const EdgeInsets.only(top: 26, bottom: 12),
  });

  final String title;
  final String? kicker;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kicker != null)
            Text(
              kicker!.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: context.morph.coral),
            ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          const DashedRule(),
        ],
      ),
    );
  }
}

class TapeLabel extends StatelessWidget {
  const TapeLabel({
    required this.text,
    super.key,
    this.angle = -.035,
    this.color,
  });

  final String text;
  final double angle;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: color ?? context.morph.tape,
          boxShadow: [
            BoxShadow(
              color: context.morph.ink.withValues(alpha: .08),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          style: morphHandwriting(context, size: 21, color: context.morph.ink),
        ),
      ),
    );
  }
}

class MorphTag extends StatelessWidget {
  const MorphTag({
    required this.label,
    super.key,
    this.selected = false,
    this.enabled = true,
    this.onSelected,
    this.icon,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      selected: selected,
      onSelected: enabled ? onSelected : null,
      avatar: icon == null ? null : Icon(icon, size: 15),
      showCheckmark: true,
      label: Text(label.toLowerCase()),
      tooltip: tooltip,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      hint: enabled
          ? tooltip
          : (tooltip ?? context.strings('common.unavailable')),
      child: ExcludeSemantics(child: chip),
    );
  }
}

class InkButton extends StatelessWidget {
  const InkButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.secondary = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label, textAlign: TextAlign.center)
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 9),
              if (expand)
                Expanded(child: Text(label, textAlign: TextAlign.center))
              else
                Text(label, textAlign: TextAlign.center),
            ],
          );
    final button = secondary
        ? OutlinedButton(onPressed: onPressed, child: child)
        : FilledButton(onPressed: onPressed, child: child);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class PolaroidRecipeCard extends StatelessWidget {
  const PolaroidRecipeCard({
    required this.title,
    required this.caption,
    required this.color,
    required this.onTap,
    super.key,
    this.meta,
    this.angle = -.018,
    this.saved = false,
    this.onSave,
    this.compact = false,
  });

  final String title;
  final String caption;
  final Color color;
  final VoidCallback onTap;
  final String? meta;
  final double angle;
  final bool saved;
  final VoidCallback? onSave;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.morph;
    return Semantics(
      button: true,
      label: '$title${meta == null ? '' : ', $meta'}',
      child: Transform.rotate(
        angle: angle,
        child: Material(
          color: palette.paper,
          elevation: 2,
          shadowColor: palette.ink.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      StripedPlaceholder(
                        caption: caption,
                        color: color,
                        height: compact ? 116 : 154,
                      ),
                      if (onSave != null)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: IconButton.filledTonal(
                            onPressed: onSave,
                            icon: Icon(
                              saved ? Icons.bookmark : Icons.bookmark_border,
                            ),
                            tooltip: saved
                                ? context.strings('common.removeFromCookbook')
                                : context.strings('common.saveToCookbook'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (meta != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      meta!.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MorphEmptyState extends StatelessWidget {
  const MorphEmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.auto_stories_outlined,
    this.action,
    this.actionLabel,
  });

  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 50, color: context.morph.teal),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center),
                    if (action != null && actionLabel != null) ...[
                      const SizedBox(height: 20),
                      InkButton(label: actionLabel!, onPressed: action),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MorphErrorState extends StatelessWidget {
  const MorphErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MorphEmptyState(
      icon: Icons.sentiment_dissatisfied_outlined,
      title: context.strings('common.errorTitle'),
      message: message,
      action: onRetry,
      actionLabel: context.strings('common.retry'),
    );
  }
}

class MorphSkeleton extends StatefulWidget {
  const MorphSkeleton({super.key, this.height = 120, this.radius = 2});

  final double height;
  final double radius;

  @override
  State<MorphSkeleton> createState() => _MorphSkeletonState();
}

class _MorphSkeletonState extends State<MorphSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
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
    final palette = context.morph;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = context.reduceMotion ? .45 : _controller.value;
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1.5 + t * 3, 0),
                end: Alignment(-.5 + t * 3, 0),
                colors: [palette.paperDeep, palette.paper, palette.paperDeep],
              ),
            ),
          );
        },
      ),
    );
  }
}

class NewspaperMasthead extends StatelessWidget {
  const NewspaperMasthead({
    required this.subtitle,
    super.key,
    this.trailing,
    this.title = 'MorphCook',
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 8),
          const DashedRule(dash: 2, gap: 3),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(title, style: Theme.of(context).textTheme.displayLarge),
          ),
          Text(
            context.strings('home.mastheadLine'),
            style: morphHandwriting(context, size: 20),
          ),
          const SizedBox(height: 9),
          const DashedRule(dash: 2, gap: 3),
        ],
      ),
    );
  }
}

class ResponsivePaperPage extends StatelessWidget {
  const ResponsivePaperPage({
    required this.child,
    super.key,
    this.maxWidth = 920,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.grain = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
    return grain ? PaperSurface(child: content) : content;
  }
}
