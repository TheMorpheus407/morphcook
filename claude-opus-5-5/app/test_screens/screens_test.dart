// Renders key screens to PNG for visual review (not part of `flutter test`).
//   flutter test test_screens/screens_test.dart --update-goldens
// Images land in test_screens/out/.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:morphcook/app.dart';
import 'package:morphcook/data/corpus_repository.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/state/kv_store.dart';
import 'package:morphcook/state/library_store.dart';
import 'package:morphcook/state/profile_controller.dart';
import 'package:morphcook/ui/screens/cook_mode_screen.dart';
import 'package:morphcook/ui/screens/dish_detail_screen.dart';

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

class H {
  H(Profile p) {
    prefs.data['profile'] = jsonEncode(p.toJson());
    profile = ProfileController(prefs);
    library = LibraryStore(hive, clock: () => DateTime(2026, 9, 22, 18, 30));
  }
  final prefs = MemoryKvStore();
  final hive = MemoryKvStore();
  final repo = CorpusRepository();
  late final ProfileController profile;
  late final LibraryStore library;
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<H> boot(WidgetTester t, Profile p) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  final h = H(p);
  await t.pumpWidget(MorphCookApp(repo: h.repo, profile: h.profile, library: h.library));
  for (var i = 0; i < 20 && !h.repo.isReady; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
  }
  await t.runAsync(h.repo.prefetchRemaining);
  await settle(t);
  return h;
}

Future<void> shot(WidgetTester t, String name) async {
  await settle(t);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '';
    final icons = '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
    if (File(icons).existsSync()) await loadFont('MaterialIcons', [icons]);
  });

  testWidgets('onboarding', (t) async {
    await boot(t, const Profile());
    await shot(t, '01_onboarding_lang');
    await t.tap(find.byKey(const Key('ob-next')));
    await settle(t);
    await t.tap(find.byKey(const Key('ob-next')));
    await settle(t);
    await t.tap(find.text('vegan').first);
    await shot(t, '02_onboarding_diet');
    await t.tap(find.byKey(const Key('ob-next')));
    await settle(t);
    await shot(t, '03_onboarding_limits');
    await t.tap(find.byKey(const Key('ob-next')));
    await settle(t);
    await shot(t, '03b_onboarding_confirm');
  });

  testWidgets('home', (t) async {
    final h = await boot(t, const Profile(onboarded: true, name: 'Ada'));
    await h.library.toggleSaved('pad-thai-vegan');
    await shot(t, '04_home_top');
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -1400));
    await shot(t, '05_home_grid');
  });

  testWidgets('dish', (t) async {
    await boot(t, const Profile(onboarded: true, avoidFlags: {'vegan'}));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const DishDetailScreen(dishId: 'doener')));
    await settle(t);
    await t.tap(find.byKey(const Key('dim-diet')));
    await shot(t, '06_dish_top');
    await t.tap(find.byKey(const Key('dim-diet')));
    await settle(t);
    await t.drag(find.byType(CustomScrollView).last, const Offset(0, -700));
    await shot(t, '07_dish_ingredients');
  });

  testWidgets('cook', (t) async {
    await boot(t, const Profile(onboarded: true));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => const CookModeScreen(recipeId: 'doener-classic')));
    await settle(t);
    await t.tap(find.byKey(const Key('cook-next')));
    await shot(t, '08_cook');
  });

  testWidgets('tabs', (t) async {
    final h = await boot(t, const Profile(onboarded: true));
    await h.library.toggleSaved('doener-vegan');
    await h.library.assign('2026-W39', 'tue.dinner', 'pad-thai-vegan');
    await h.library.assign('2026-W39', 'wed.lunch', 'lentil-soup-classic');
    await t.runAsync(() => h.repo.ensureRecipes(['doener-classic', 'chili-classic']));
    await h.library.addToShopping(h.repo.recipe('doener-classic')!, 4);
    await h.library.addToShopping(h.repo.recipe('chili-classic')!, 4);
    await t.tap(find.byKey(const Key('tab-1')));
    await settle(t);
    await t.enterText(find.byKey(const Key('search-field')), 'vegan');
    await shot(t, '09_search');
    await t.tap(find.byKey(const Key('tab-3')));
    await shot(t, '10_plan');
    await t.tap(find.byKey(const Key('tab-4')));
    await shot(t, '11_list');
  });

  testWidgets('settings', (t) async {
    await boot(t, const Profile(onboarded: true, lang: 'de'));
    await t.tap(find.byKey(const Key('open-settings')));
    await shot(t, '12_settings_de');
  });
}
