import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/user_data.dart';
import 'package:morphcook/services/local_store.dart';
import 'package:morphcook/services/recipe_repository.dart';
import 'package:morphcook/state/app_state.dart';
import 'package:morphcook/theme/app_theme.dart';
import 'package:provider/provider.dart';

Future<AppState> makeTestApp(
  WidgetTester tester, {
  Profile profile = const Profile(onboardingComplete: true),
  UserSnapshot snapshot = const UserSnapshot(),
  DateTime? now,
}) async {
  final app = await tester.runAsync(() async {
    final repository = RecipeRepository();
    await repository.load();
    await initializeDateFormatting();
    final app = AppState(
      repository: repository,
      store: MemoryStateStore(profile: profile, snapshot: snapshot),
      clock: () => now ?? DateTime(2026, 4, 13, 7),
    );
    await app.initialize();
    return app;
  });
  return app!;
}

Future<void> pumpMorphCook(WidgetTester tester, AppState app) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(value: app, child: const MorphCookApp()),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

Future<void> pumpScreen(WidgetTester tester, AppState app, Widget home) async {
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: app,
      child: MaterialApp(theme: buildAppTheme(), home: home),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
