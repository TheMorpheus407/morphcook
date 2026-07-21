import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('every iOS App Store icon is opaque RGB', () {
    final icons = Directory(
      'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    ).listSync().whereType<File>().where((file) => file.path.endsWith('.png'));
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      final decoded = image.decodePng(icon.readAsBytesSync());
      expect(decoded, isNotNull, reason: icon.path);
      expect(
        decoded!.numChannels,
        3,
        reason: '${icon.path} must have no alpha',
      );
    }
  });

  test(
    'production Android manifest is offline and release is not debug-signed',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(manifest, isNot(contains('android.permission.INTERNET')));
      expect(gradle, isNot(contains('signingConfigs.getByName("debug")')));
      expect(gradle, contains('signingConfigs.getByName("release")'));
    },
  );
}
