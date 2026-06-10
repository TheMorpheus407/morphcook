import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morphcook/core/app_scope.dart';
import 'package:morphcook/data/corpus.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/screens/dish/dish_detail_screen.dart';
import 'package:morphcook/screens/root_shell.dart';
import 'package:morphcook/services/content_requests_service.dart';
import 'package:morphcook/services/cook_progress_service.dart';
import 'package:morphcook/services/cookbook_service.dart';
import 'package:morphcook/services/history_service.dart';
import 'package:morphcook/services/meal_plan_service.dart';
import 'package:morphcook/services/profile_service.dart';
import 'package:morphcook/services/shopping_list_service.dart';
import 'package:morphcook/services/stores.dart';
import 'package:morphcook/theme/app_theme.dart';

/// Boots the real UI against the real bundled corpus and an in-memory data
/// layer. This is the end-to-end "does it render without throwing" check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Corpus corpus;
  late Services services;
  late Directory tempDir;

  setUp(() async {
    await initializeDateFormatting();
    SharedPreferences.setMockInitialValues({});
    tempDir = Directory.systemTemp.createTempSync('morphcook_test');
    Hive.init(tempDir.path);
    final prefs = await SharedPreferences.getInstance();
    services = Services(
      profile: ProfileService(prefs),
      cookbook: CookbookService(await Hive.openBox('cookbook')),
      history: HistoryService(await Hive.openBox('history')),
      mealPlan: MealPlanService(await Hive.openBox('meal_plan')),
      shopping: ShoppingListService(await Hive.openBox('shopping')),
      contentRequests: ContentRequestsService(await Hive.openBox('content_requests')),
      cookProgress: CookProgressService(await Hive.openBox('cook_progress')),
    );
    await services.profile.update(const Profile(onboarded: true, name: 'Test'));
    corpus = await Corpus.load();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    tempDir.deleteSync(recursive: true);
  });

  Widget app(Widget home) => AppScope(
        corpus: corpus,
        services: services,
        child: MaterialApp(theme: AppTheme.light(), home: home),
      );

  testWidgets('root shell renders all tabs without error', (tester) async {
    await tester.pumpWidget(app(const RootShell()));
    await tester.pumpAndSettle();
    // masthead present
    expect(find.text('morphcook'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a nav tab switches without error', (tester) async {
    await tester.pumpWidget(app(const RootShell()));
    await tester.pumpAndSettle();
    // tap through each bottom-nav destination
    for (final icon in [Icons.search, Icons.bookmark_border, Icons.calendar_today_outlined, Icons.person_outline]) {
      await tester.tap(find.byIcon(icon).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('dish detail renders and switches a variant', (tester) async {
    final doener = corpus.dish('doener')!;
    await tester.pumpWidget(app(DishDetailScreen(dishId: doener.id)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // the dish name appears
    expect(find.text(doener.name.resolve(services.profile.lang)), findsWidgets);
    // ingredients + method section titles render
    expect(find.textContaining(RegExp('ingredients|Zutaten')), findsWidgets);
  });

  testWidgets('saving a variant persists to the cookbook and reflects in UI',
      (tester) async {
    final dish = corpus.dish('alfredo')!;
    await tester.pumpWidget(app(DishDetailScreen(dishId: dish.id)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Hive writes schedule real IO/timers that deadlock under the test's
    // fake-async clock, so persist via runAsync (real event loop).
    await tester.runAsync(
        () => services.cookbook.save(dish.variantRecipeIds.first));
    expect(services.cookbook.count, greaterThan(0));
    expect(services.cookbook.isSaved(dish.variantRecipeIds.first), isTrue);

    // A rebuild after the save renders cleanly.
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
