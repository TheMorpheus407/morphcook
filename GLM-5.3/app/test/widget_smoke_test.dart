import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:morphcook/app.dart';
import 'package:morphcook/core/services/collection_store.dart';
import 'package:morphcook/core/services/profile_store.dart';
import 'package:morphcook/features/dish/dish_detail_page.dart';
import 'package:morphcook/state/app_state.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  configureAppForTests(); // no google_fonts HTTP fetches in tests

  late AppState state;

  setUpAll(() async {
    SharedPreferences.setMockValues({});
    final temp = await Directory.systemTemp.createTemp('morphcook_test');
    Hive.init(temp.path);
    final box = await Hive.openBox('morphcook_test_${DateTime.now().millisecondsSinceEpoch}');
    final corpus = await loadTestCorpus();
    state = AppState(
      corpus: corpus,
      profileStore: ProfileStore(await SharedPreferences.getInstance()),
      collections: CollectionStore(box),
    );
    await state.load();
  });

  testWidgets('onboarding greets and the shell takes over afterwards',
      (tester) async {
    await tester.pumpWidget(MorphCookApp(state: state));

    // Fresh profile → onboarding step 1 (language).
    expect(find.text('morphcook'), findsWidgets);
    expect(find.text('welcome'), findsOneWidget);

    // Finish onboarding → home shell with the newspaper masthead feed.
    await state.completeOnboarding(state.profile.copy()..name = 'ada');
    await tester.pumpAndSettle();
    expect(find.text('home'), findsWidgets);
    // Feed shows the featured dish section.
    expect(find.textContaining('tonight'), findsWidgets);
  });

  testWidgets('dish detail renders the variant switcher rows', (tester) async {
    await state.completeOnboarding(state.profile);
    await tester.pumpWidget(MorphCookApp(state: state));
    await tester.pumpAndSettle();

    // Open the döner detail page directly (needs the AppState provider).
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: state,
      child: const MaterialApp(home: DishDetailPage(dishId: 'doener')),
    ));
    await tester.pumpAndSettle();

    // The three dimension rows exist (diet / effort / calorie level).
    expect(find.textContaining('diet'), findsWidgets);
    expect(find.textContaining('effort'), findsWidgets);
    expect(find.textContaining('calorie'), findsWidgets);
    // The döner dish name renders (localized lowercase display).
    expect(find.text('döner'), findsOneWidget);
  });
}
