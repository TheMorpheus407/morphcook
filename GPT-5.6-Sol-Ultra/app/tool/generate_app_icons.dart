import 'dart:io';

import 'package:image/image.dart' as image;

void main() {
  const size = 1024;
  // Store icons as opaque RGB: App Store artwork must not contain alpha.
  final canvas = image.Image(width: size, height: size, numChannels: 3);
  final paper = image.ColorRgb8(247, 240, 226);
  final paperDeep = image.ColorRgb8(233, 221, 200);
  final ink = image.ColorRgb8(40, 35, 31);
  final teal = image.ColorRgb8(46, 116, 113);
  final coral = image.ColorRgb8(169, 71, 61);
  final mustard = image.ColorRgb8(210, 165, 66);

  image.fill(canvas, color: paper);
  for (var offset = -1000; offset < 1900; offset += 112) {
    image.drawLine(
      canvas,
      x1: offset,
      y1: size,
      x2: offset + size,
      y2: 0,
      color: teal,
      thickness: 44,
      antialias: true,
    );
  }

  // A paper label over the striped pantry pattern. Repeated circles make a
  // soft ink rim that survives the smallest launcher sizes.
  image.fillCircle(canvas, x: 512, y: 510, radius: 374, color: ink);
  image.fillCircle(canvas, x: 512, y: 510, radius: 347, color: paperDeep);
  image.fillCircle(canvas, x: 512, y: 510, radius: 330, color: paper);

  // A deliberately simple hand-drawn M; the full wordmark remains in-app.
  const points = <(int, int)>[
    (326, 654),
    (382, 356),
    (512, 536),
    (642, 356),
    (698, 654),
  ];
  for (var index = 0; index < points.length - 1; index++) {
    image.drawLine(
      canvas,
      x1: points[index].$1,
      y1: points[index].$2,
      x2: points[index + 1].$1,
      y2: points[index + 1].$2,
      color: ink,
      thickness: 48,
      antialias: true,
    );
  }
  image.fillCircle(canvas, x: 512, y: 707, radius: 47, color: coral);
  image.drawCircle(
    canvas,
    x: 512,
    y: 707,
    radius: 49,
    color: mustard,
    antialias: true,
  );

  Directory('assets/brand').createSync(recursive: true);
  File('assets/brand/app-icon.png').writeAsBytesSync(image.encodePng(canvas));

  const android = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
  };
  const ios = <String, int>{
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  for (final entry in android.entries) {
    _writeSized(canvas, entry.key, entry.value);
  }
  const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  for (final entry in ios.entries) {
    _writeSized(canvas, '$iosDirectory/${entry.key}', entry.value);
  }
}

void _writeSized(image.Image source, String path, int size) {
  final output = size == source.width
      ? source
      : image.copyResize(
          source,
          width: size,
          height: size,
          interpolation: image.Interpolation.average,
        );
  File(path).writeAsBytesSync(image.encodePng(output));
}
