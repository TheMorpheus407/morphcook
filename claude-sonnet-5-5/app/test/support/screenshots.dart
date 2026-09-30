import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

/// Writes the rendered image to a folder instead of comparing it with a golden
/// file, so a person can look at it.
class ScreenshotComparator extends GoldenFileComparator {
  ScreenshotComparator(this.dir);

  /// The default folder: `build/screenshots`.
  factory ScreenshotComparator.standard() => ScreenshotComparator(screenshotDir());

  final Directory dir;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await File('${dir.path}/${golden.pathSegments.last}').writeAsBytes(imageBytes);
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    await compare(imageBytes, golden);
  }

  @override
  Uri getTestUri(Uri key, int? version) => key;
}

/// Saves the app as `build/screenshots/<name>.png`.
Future<void> shot(WidgetTester tester, String name) async {
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('$name.png'));
}
