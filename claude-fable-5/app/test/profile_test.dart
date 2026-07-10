import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';

void main() {
  test('appearance fields round-trip through json', () {
    const profile = Profile(themeMode: 'dark', readableText: true);
    final decoded = Profile.fromJson(
        json.decode(json.encode(profile.toJson())) as Map<String, dynamic>);
    expect(decoded.themeMode, 'dark');
    expect(decoded.readableText, isTrue);
  });

  test('appearance fields default for pre-existing profiles', () {
    // A stored profile from an older app version carries neither key.
    final decoded = Profile.fromJson(const {'name': 'cedric'});
    expect(decoded.themeMode, 'system');
    expect(decoded.readableText, isFalse);
  });

  test('copyWith carries appearance fields', () {
    const profile = Profile();
    final dark = profile.copyWith(themeMode: 'dark');
    expect(dark.themeMode, 'dark');
    expect(dark.readableText, isFalse);
    final readable = dark.copyWith(readableText: true);
    expect(readable.themeMode, 'dark');
    expect(readable.readableText, isTrue);
  });
}
