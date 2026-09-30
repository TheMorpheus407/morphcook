import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/palette.dart';
import '../../core/theme/typography.dart';

/// `mm:ss`, or `h:mm:ss` for long timers.
String clockText(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}

/// A countdown ring with the time in the middle.
class TimerRing extends StatelessWidget {
  const TimerRing({
    super.key,
    required this.remaining,
    required this.total,
    required this.running,
    required this.finished,
    this.size = 200,
  });

  final int remaining;
  final int total;
  final bool running;
  final bool finished;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    final color = finished ? Palette.coral : (running ? Palette.teal : Palette.nightSoft);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(fraction: finished ? 1 : fraction, color: color, track: Palette.nightRule),
          ),
          // The digits are part of the ring, so they shrink to it when the
          // system text size would make them wider than the circle.
          SizedBox(
            width: size * 0.78,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                clockText(remaining),
                style: AppText.mono(
                  size: size * 0.25,
                  color: finished ? Palette.coral : Palette.nightInk,
                  weight: FontWeight.w500,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color, required this.track});

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stroke = size.width * 0.045;
    final arcRect = rect.deflate(stroke);
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

/// Visual alert for deaf and hard-of-hearing cooks (and anyone across the
/// kitchen): a coral/teal flash over the whole screen when a timer finishes.
///
/// It pulses gently, below the three-flashes-per-second threshold that
/// photosensitive readers need. With reduced motion it does not flash at all:
/// it shows a still coral banner instead.
class TimerFlashOverlay extends StatefulWidget {
  const TimerFlashOverlay({super.key, required this.message, required this.dismissLabel, required this.onDismiss});

  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  State<TimerFlashOverlay> createState() => _TimerFlashOverlayState();
}

class _TimerFlashOverlayState extends State<TimerFlashOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _card({required bool still}) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: still ? Palette.coral : Palette.night.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Palette.nightInk, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active, color: Palette.nightInk, size: 34),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: AppText.display(size: 28, color: Palette.nightInk),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 140),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(color: Palette.nightInk, borderRadius: BorderRadius.circular(3)),
                child: Text(
                  widget.dismissLabel.toUpperCase(),
                  style: AppText.mono(size: 13, color: Palette.night, weight: FontWeight.w700, letterSpacing: 1.3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final still = context.reduceMotion;
    if (still) {
      // No flashing: a still banner at the top, and the rest of the screen stays usable.
      return Semantics(
        liveRegion: true,
        label: widget.message,
        child: Align(alignment: Alignment.topCenter, child: _card(still: true)),
      );
    }
    return Semantics(
      liveRegion: true,
      label: widget.message,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final color = Color.lerp(Palette.coral, Palette.teal, Curves.easeInOut.transform(_pulse.value))!;
          return Container(
            color: color.withValues(alpha: 0.72),
            alignment: Alignment.center,
            child: _card(still: false),
          );
        },
      ),
    );
  }
}
