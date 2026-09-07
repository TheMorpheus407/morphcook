import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morphcook/core/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'profile, collections and paused cooking survive closing and reopening storage',
    () async {
      // All fixture files stay in this project, including on hosts with a global TMPDIR.
      final parent = await Directory(
        '.dart_tool/persistence-fixtures',
      ).create(recursive: true);
      final directory = await parent.createTemp('state-');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => directory.absolute.path,
          );
      addTearDown(() async {
        await Hive.close();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      final first = await AppState.load();
      final recipe = first.repo.recipes.first;
      final profile = first.profile.copy()
        ..name = 'Mira'
        ..lang = 'de'
        ..avoidFlags = {'dairy'}
        ..onboarded = true;
      first.updateProfile(profile);
      first.toggleSaved(recipe.id);
      first.assignMeal('2026-W37', 'mon.dinner', recipe.id);
      first.addRecipesToShopping([recipe]);
      first.recordContentRequest('sushi');
      first.completeCooking(recipe);
      first.setCookProgress({
        'recipe_id': recipe.id,
        'step': 1,
        'servings': 2,
        'remaining_seconds': 42,
        'paused': true,
      });
      await first.flush();
      final snapshot = first.exportBackup()..remove('exported_at');
      first.dispose();
      await Hive.close();

      final reopened = await AppState.load();
      expect(reopened.profile.name, 'Mira');
      expect(reopened.profile.onboarded, isTrue);
      expect(reopened.exportBackup()..remove('exported_at'), snapshot);
      expect(reopened.repo.byId(recipe.id), isNotNull);
      reopened.dispose();
    },
  );
}
