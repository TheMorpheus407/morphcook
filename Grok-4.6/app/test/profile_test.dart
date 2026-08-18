import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/models/localized.dart';
import 'package:morphcook/models/profile.dart';

void main() {
  test('localized falls back to english then any', () {
    const text = LocalizedText({'de': 'Hallo', 'en': 'Hello'});
    expect(text.of('de'), 'Hallo');
    expect(text.of('en'), 'Hello');
    expect(text.of('fr'), 'Hello');
    expect(const LocalizedText({'de': 'Hallo'}).of('fr'), 'Hallo');
  });

  test('profile json roundtrip', () {
    const profile = Profile(
      name: 'ada',
      lang: 'de',
      avoidFlags: {'vegan', 'nuts'},
      avoidIngredients: {'apple'},
      requiredAttributes: {'halal'},
      maxTimeMinutes: 45,
      calorieTarget: 600,
      preferredEffort: 'medium',
      showVariantTags: false,
      reduceMotion: true,
      visualAlertEnabled: false,
      quickNextTapEnabled: true,
    );
    final copy = Profile.fromJson(profile.toJson());
    expect(copy.name, 'ada');
    expect(copy.avoidFlags, {'vegan', 'nuts'});
    expect(copy.avoidIngredients, {'apple'});
    expect(copy.requiredAttributes, {'halal'});
    expect(copy.maxTimeMinutes, 45);
    expect(copy.calorieTarget, 600);
    expect(copy.preferredEffort, 'medium');
    expect(copy.showVariantTags, isFalse);
    expect(copy.reduceMotion, isTrue);
    expect(copy.visualAlertEnabled, isFalse);
    expect(copy.quickNextTapEnabled, isTrue);
  });
}
