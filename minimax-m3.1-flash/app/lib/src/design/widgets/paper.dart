import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;


import 'package:flutter/material.dart';

import '../palette.dart';

/// A cached, tileable paper-grain texture.
///
/// The grain is generated once at startup from a fixed seed, so the paper
/// looks identical on every device and every run — which matters for a
/// design-led app that promises pixel-identical output on iOS and Android.
class GrainTexture {
  GrainTexture._(this.image, this.paint);

  final ui.Image image;
  final ui.Paint paint;

  static GrainTexture? _cached;
  static Future<GrainTexture>? _pending;

  static GrainTexture? get cached => _cached;

  static Future<GrainTexture> load({int size = 128, int seed = 20260418}) {
    if (_cached != null) return Future.value(_cached);
    return _pending ??= _generate(size: size, seed: seed);
  }

  static Future<GrainTexture> _generate({required int size, required int seed}) async {
    final random = math.Random(seed);
    final pixels = Uint8List(size * size * 4);

    for (var i = 0; i < size * size; i++) {
      final roll = random.nextDouble();
      int r;
      int g;
      int b;
      int a;
      if (roll > 0.62) {
        // Dark fibre.
        r = 74;
        g = 62;
        b = 48;
        a = ((roll - 0.62) * 120).clamp(0, 255).toInt();
      } else if (roll < 0.16) {
        // Light fleck, like pulp in recycled paper.
        r = 255;
        g = 252;
        b = 240;
        a = ((0.16 - roll) * 110).clamp(0, 255).toInt();
      } else {
        r = 128;
        g = 128;
        b = 128;
        a = 0;
      }
      pixels[i * 4] = r;
      pixels[i * 4 + 1] = g;
      pixels[i * 4 + 2] = b;
      pixels[i * 4 + 3] = a;
    }

    final completer = Completer<GrainTexture>();
    ui.decodeImageFromPixels(
      pixels,
      size,
      size,
      ui.PixelFormat.rgba8888,
      (image) {
        final shader = ui.ImageShader(
          image,
          TileMode.repeated,
          TileMode.repeated,
          Float64List.fromList(const <double>[
            1, 0, 0, 0, //
            0, 1, 0, 0, //
            0, 0, 1, 0, //
            0, 0, 0, 1, //
          ]),
        );
        final texture = GrainTexture._(image, ui.Paint()..shader = shader);
        _cached = texture;
        completer.complete(texture);
      },
    );
    return completer.future;
  }
}

/// Paints the grain texture across the whole canvas.
class PaperGrain extends StatelessWidget {
  const PaperGrain({super.key, this.opacity = 0.85});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final texture = GrainTexture.cached;
    if (texture == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _GrainPainter(texture, opacity),
        size: Size.infinite,
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter(this.texture, this.opacity);

  final GrainTexture texture;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, texture.paint);
  }

  @override
  bool shouldRepaint(_GrainPainter old) =>
      old.texture != texture || old.opacity != opacity;
}

/// The warm page every screen sits on.
///
/// A soft cream base, a whisper of grain, and a vignette that pulls the eye
/// toward the middle of the page.
class PaperBackground extends StatelessWidget {
  const PaperBackground({
    required this.child,
    super.key,
    this.tint = MC.paper,
    this.grain = true,
  });

  final Widget child;
  final Color tint;
  final bool grain;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MC.paperWarm, MC.paper, MC.paperDeep],
          stops: <double>[0.0, 0.45, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (grain) const PaperGrain(),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.25,
                colors: MC.paperVignette,
                stops: const <double>[0.55, 1.0],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A torn-edge sheet of paper used for cards and panels.
class PaperSheet extends StatelessWidget {
  const PaperSheet({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
    this.color = MC.card,
    this.border = true,
    this.sharp = false,
    this.rotation = 0,
    this.shadow = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;
  final bool sharp;
  final double rotation;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final radius = sharp ? BorderRadius.zero : BorderRadius.circular(4);
    Widget sheet = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: border
            ? Border.all(color: MC.ruleFaint, width: 1)
            : null,
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x142C2823),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (rotation != 0) {
      sheet = Transform.rotate(angle: rotation, child: sheet);
    }
    return sheet;
  }
}
