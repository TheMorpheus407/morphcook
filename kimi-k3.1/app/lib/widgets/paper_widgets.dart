import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../localization/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class Paper extends StatelessWidget {
  const Paper({super.key, required this.child, this.color = AppColors.paper});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: color,
    child: CustomPaint(foregroundPainter: PaperGrainPainter(), child: child),
  );
}

class PaperGrainPainter extends CustomPainter {
  PaperGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()..strokeWidth = 0.55;
    for (var index = 0; index < 150; index++) {
      final x = ((math.sin(index * 91.73) + 1) / 2) * size.width;
      final y = ((math.cos(index * 47.11) + 1) / 2) * size.height;
      paint.color = (index.isEven ? AppColors.ink : Colors.white).withValues(
        alpha: index.isEven ? 0.025 : 0.09,
      );
      canvas.drawLine(Offset(x, y), Offset(x + 1.2, y + 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(PaperGrainPainter oldDelegate) => false;
}

class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color = AppColors.muted, this.height = 12});
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: DashedPainter(color)),
  );
}

class DashedPainter extends CustomPainter {
  const DashedPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 0.8;
    const width = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + width, size.width), y),
        paint,
      );
      x += width + gap;
    }
  }

  @override
  bool shouldRepaint(DashedPainter oldDelegate) => oldDelegate.color != color;
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.kicker, this.trailing});
  final String title;
  final String? kicker;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (kicker != null)
        Text(kicker!, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.handwritten,
            ),
          ),
          ?trailing,
        ],
      ),
      const DashedRule(),
    ],
  );
}

class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key, this.active = false, this.icon});
  final String label;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: active
          ? AppColors.teal.withValues(alpha: 0.13)
          : Colors.transparent,
      border: Border.all(
        color: active ? AppColors.teal : AppColors.muted.withValues(alpha: 0.5),
      ),
      borderRadius: BorderRadius.circular(2),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: AppColors.teal),
          const SizedBox(width: 4),
        ],
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: active ? AppColors.teal : AppColors.muted,
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

class Polaroid extends StatelessWidget {
  const Polaroid({
    super.key,
    required this.child,
    this.turns = -0.006,
    this.padding = 9,
  });
  final Widget child;
  final double turns;
  final double padding;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: turns * 2 * math.pi,
    child: Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: AppColors.paperLight,
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.11),
            blurRadius: 12,
            offset: const Offset(2, 5),
          ),
        ],
      ),
      child: child,
    ),
  );
}

class DishArtwork extends StatelessWidget {
  const DishArtwork({
    super.key,
    required this.caption,
    required this.stripeColor,
    this.height,
    this.figure = '01',
  });
  final String caption;
  final String stripeColor;
  final double? height;
  final String figure;

  Color get color {
    final hex = stripeColor.replaceFirst('#', '');
    return Color(int.parse(hex.length == 6 ? 'ff$hex' : hex, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final artwork = LayoutBuilder(
      builder: (context, constraints) => ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: StripePainter(color)),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                color: AppColors.paperLight.withValues(alpha: 0.86),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  'FIG. $figure / ${context.l10n.t('plate_study')}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(fontSize: 8),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.paperLight, width: 2),
                  color: AppColors.ink.withValues(alpha: 0.08),
                ),
                child: Icon(
                  Icons.restaurant_outlined,
                  color: AppColors.paperLight,
                  size: 31,
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 9,
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.handwritten
                    .copyWith(
                      color: AppColors.paperLight,
                      shadows: const [
                        Shadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      image: true,
      label: caption,
      child: height == null
          ? AspectRatio(aspectRatio: 1.25, child: artwork)
          : SizedBox(height: height, child: artwork),
    );
  }
}

class StripePainter extends CustomPainter {
  const StripePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
    final stripe = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.22)
      ..strokeWidth = 10;
    for (var x = -size.height; x < size.width + size.height; x += 28) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    final glaze = Paint()..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawRect(Offset.zero & size, glaze);
  }

  @override
  bool shouldRepaint(StripePainter oldDelegate) => oldDelegate.color != color;
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: Icon(icon ?? Icons.arrow_forward, size: 18),
    label: Text(label),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 44),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.auto_stories_outlined,
            size: 42,
            color: AppColors.coral,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[const SizedBox(height: 22), action!],
        ],
      ),
    ),
  );
}

class LoadingList extends StatelessWidget {
  const LoadingList({super.key, this.count = 3});
  final int count;

  @override
  Widget build(BuildContext context) => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: count,
    itemBuilder: (context, index) => Container(
      height: 118,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.paperLight.withValues(alpha: 0.55),
        border: Border.all(color: AppColors.muted.withValues(alpha: 0.12)),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
    ),
  );
}

class ServingScaler extends StatelessWidget {
  const ServingScaler({
    super.key,
    required this.value,
    required this.onChanged,
    this.dark = false,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? AppColors.darkPaper : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
          color: color,
          tooltip: '−',
        ),
        Column(
          children: [
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: color),
            ),
            Text(
              context.l10n.t('servings_short'),
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
        IconButton(
          onPressed: value < 12 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
          color: color,
          tooltip: '+',
        ),
      ],
    );
  }
}

bool reduceMotion(BuildContext context) {
  final preference = context.read<AppState>().profile.reduceMotion;
  return preference ?? MediaQuery.of(context).disableAnimations;
}

Duration motionDuration(BuildContext context, Duration normal) =>
    reduceMotion(context) ? Duration.zero : normal;
