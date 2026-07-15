import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/profile.dart';

void main() {
  test('appearance fields round-trip through json', () {
    const profile = Profile(themeMode: 'dark', readableText: true);
    final decoded = Profile.fromJson(
      json.decode(json.encode(profile.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.themeMode, 'dark');
    expect(decoded.readableText, isTrue);
  });

  test('appearance fields default for pre-existing profiles', () {
    // Old installs persisted false because decorative text was the default.
    final decoded = Profile.fromJson(const {
      'name': 'cedric',
      'readable_text': false,
    });
    expect(decoded.themeMode, 'system');
    expect(decoded.readableText, isTrue);
  });

  test('copyWith carries appearance fields', () {
    const profile = Profile();
    final dark = profile.copyWith(themeMode: 'dark');
    expect(dark.themeMode, 'dark');
    expect(dark.readableText, isTrue);
    final decorative = dark.copyWith(readableText: false);
    expect(decorative.themeMode, 'dark');
    expect(decorative.readableText, isFalse);
  });

  test('a new explicit decorative-text preference is preserved', () {
    const profile = Profile(readableText: false);
    final decoded = Profile.fromJson(
      json.decode(json.encode(profile.toJson())) as Map<String, dynamic>,
    );
    expect(decoded.readableText, isFalse);
  });
}
