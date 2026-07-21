import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/domain/models.dart';
import 'package:morphcook/services/profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('persists the complete profile as one JSON document', () async {
    final store = await SharedPreferencesProfileStore.create();
    final profile = UserProfile(
      name: 'Mira',
      languageCode: 'de',
      avoidFlags: const <String>{'dairy'},
      avoidIngredientIds: const <String>{'cilantro'},
      requiredAttributes: const <String>{'halal'},
      maxTimeMinutes: 30,
      calorieTarget: 550,
      preferredEffort: 'medium',
      showVariantTags: true,
      reduceMotion: true,
      visualAlertEnabled: false,
    );

    await store.saveProfile(profile);
    expect(await store.loadProfile(), profile);

    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(SharedPreferencesProfileStore.profileKey);
    expect(jsonDecode(raw!)['avoid_flags'], <String>['dairy']);
  });

  test('persists onboarding, quick-next and dismissed hints', () async {
    final store = await SharedPreferencesProfileStore.create();
    const settings = AppSettings(
      onboardingComplete: true,
      quickNextTapEnabled: true,
      dismissedHints: <String>{'meal-plan', 'switcher'},
    );

    await store.saveSettings(settings);
    final loaded = await store.loadSettings();
    expect(loaded.onboardingComplete, isTrue);
    expect(loaded.quickNextTapEnabled, isTrue);
    expect(loaded.dismissedHints, settings.dismissedHints);
  });

  test('deleteProfile leaves settings intact', () async {
    final store = await SharedPreferencesProfileStore.create();
    await store.saveProfile(UserProfile(name: 'Mira'));
    await store.saveSettings(const AppSettings(onboardingComplete: true));

    await store.deleteProfile();
    expect(await store.loadProfile(), isNull);
    expect((await store.loadSettings()).onboardingComplete, isTrue);
  });

  test(
    'malformed profile fails soft without deleting diagnostic data',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        SharedPreferencesProfileStore.profileKey: '{broken',
      });
      final store = await SharedPreferencesProfileStore.create();

      expect(await store.loadProfile(), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getString(SharedPreferencesProfileStore.profileKey),
        '{broken',
      );
    },
  );

  test('clear removes profile and settings', () async {
    final store = await SharedPreferencesProfileStore.create();
    await store.saveProfile(UserProfile(name: 'Mira'));
    await store.saveSettings(
      const AppSettings(onboardingComplete: true, quickNextTapEnabled: true),
    );

    await store.clear();
    expect(await store.loadProfile(), isNull);
    expect(await store.loadSettings(), const TypeMatcher<AppSettings>());
    expect((await store.loadSettings()).onboardingComplete, isFalse);
    expect((await store.loadSettings()).quickNextTapEnabled, isFalse);
  });
}
