import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:morphcook/app_scope.dart';
import 'package:morphcook/app_state.dart';
import 'package:morphcook/data.dart';
import 'package:morphcook/main.dart';
import 'package:morphcook/models.dart';
import 'package:morphcook/screens/onboarding.dart';
import 'package:morphcook/screens/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;
  late RecipeRepository repository;

  setUpAll(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('morphcook-test-');
    Hive.init(hiveDirectory.path);
    repository = await RecipeRepository.load();
  });

  tearDownAll(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  testWidgets('finishing onboarding opens the cookbook shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final box = await Hive.openBox<String>('onboarding-flow');
    final state = MorphCookState.forTesting(
      repository: repository,
      preferences: preferences,
      box: box,
    );

    await tester.pumpWidget(
      MorphCookScope(
        state: state,
        child: const MaterialApp(home: AppEntry()),
      ),
    );

    expect(find.byType(OnboardingScreen), findsOneWidget);

    await state.completeOnboarding(Profile.fresh());
    await tester.pump();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });
}
