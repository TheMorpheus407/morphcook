import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/core/app_info.dart';

void main() {
  test('the version shown in Settings matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final version = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true).firstMatch(pubspec)!.group(1);
    expect(kAppVersion, version);
  });

  test('the product is called MorphCook', () {
    expect(kAppName, 'MorphCook');
    expect(File('pubspec.yaml').readAsStringSync(), contains('name: morphcook'));
  });
}
