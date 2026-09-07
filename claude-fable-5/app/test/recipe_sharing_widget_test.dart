import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/data/app_state.dart';
import 'package:morphcook/data/store.dart';
import 'package:morphcook/logic/local_file_bytes.dart';
import 'package:morphcook/logic/sharing/native_recipe_share.dart';
import 'package:morphcook/logic/sharing/recipe_share.dart';
import 'package:morphcook/models/personal_recipe.dart';
import 'package:morphcook/models/profile.dart';
import 'package:morphcook/models/recipe_image.dart';
import 'package:morphcook/ui/screens/recipe_sharing_screen.dart';
import 'package:morphcook/ui/strings.dart';
import 'package:morphcook/ui/theme.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'helpers.dart';

PersonalRecipe shareFixture(String title) => PersonalRecipe.create(
  title: title,
  timeMinutes: 10,
  servings: 2,
  ingredients: [PersonalRecipeIngredient(name: 'rice', qty: 100, unit: 'g')],
  steps: [PersonalRecipeStep(text: 'Cook gently.', timerMinutes: 10)],
);

Future<AppState> shareState() async {
  final state = AppState(
    store: MemoryStore(),
    corpus: await loadRealCorpus(all: false),
  );
  await state.load();
  await state.completeOnboarding(
    const Profile(name: 'private profile', lang: 'en'),
  );
  return state;
}

Widget shareApp(AppState state, RecipeSharingScreen screen) =>
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: morphThemeData(MorphColors.light),
        home: screen,
      ),
    );

Future<void> press(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(target);
  // AppState was bootstrapped on the real event loop; drain its import queue.
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pumpAndSettle();
}

class PausedShareStore extends MemoryStore {
  Completer<void>? gate;
  @override
  Future<void> putCollections(Map<String, String> collections) async {
    if (gate != null) await gate!.future;
    await super.putCollections(collections);
  }
}

void main() {
  testWidgets('back navigation waits for the recipe import transaction', (
    tester,
  ) async {
    final corpus = (await tester.runAsync(() => loadRealCorpus(all: false)))!;
    final store = PausedShareStore();
    final state = AppState(store: store, corpus: corpus);
    await state.load();
    await state.completeOnboarding(const Profile(lang: 'en'));
    final bytes = encodeRecipeShare(
      RecipeShareData(recipes: [shareFixture('Received')]),
    );
    await tester.pumpWidget(
      shareApp(state, RecipeSharingScreen(pickBytes: () async => bytes)),
    );
    await press(tester, 'pick-shared-recipes');
    final target = find.byKey(const ValueKey('confirm-shared-recipes'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    store.gate = Completer<void>();
    await tester.tap(target);
    await tester.pump();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
    expect(state.personalRecipes.single.title, 'Received');
  });

  testWidgets(
    'share selected recipe then cookbook; photo inclusion is explicit',
    (tester) async {
      final state = (await tester.runAsync(shareState))!;
      final first = shareFixture('First recipe');
      final second = shareFixture('Second recipe');
      await state.savePersonalRecipe(first);
      await state.savePersonalRecipe(second);
      await state.setRecipeImage(first.id, testPngBytes());
      final sent = <RecipeShareData>[];
      await tester.pumpWidget(
        shareApp(
          state,
          RecipeSharingScreen(
            recipeId: first.id,
            shareFiles: (bytes, text, origin) async {
              sent.add(decodeRecipeShare(bytes));
              expect(text, isNot(contains('private profile')));
              expect(origin.width, greaterThan(0));
            },
          ),
        ),
      );
      await press(tester, 'share-selected-recipe');
      expect(sent.single.recipes.map((r) => r.title), ['First recipe']);
      expect(sent.single.images, isEmpty);
      await press(tester, 'share-recipe-photos');
      await press(tester, 'share-cookbook');
      expect(sent.last.recipes, hasLength(2));
      expect(sent.last.images, hasLength(1));
      expect(state.personalRecipes, hasLength(2));
    },
  );

  testWidgets(
    'received file previews before merging and repeated import is harmless',
    (tester) async {
      final state = (await tester.runAsync(shareState))!;
      final local = shareFixture('Local recipe');
      await state.savePersonalRecipe(local);
      final incoming = shareFixture('Received recipe');
      final bytes = encodeRecipeShare(
        RecipeShareData(
          recipes: [incoming],
          images: [
            RecipeImage(
              recipeId: incoming.id,
              bytes: testPngBytes(),
              updatedAt: DateTime.now(),
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        shareApp(state, RecipeSharingScreen(pickBytes: () async => bytes)),
      );
      await press(tester, 'pick-shared-recipes');
      expect(state.personalRecipes.map((r) => r.title), ['Local recipe']);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('shared-photos-preview')))
            .data,
        contains('photos included: 1'),
      );
      await press(tester, 'confirm-shared-recipes');
      expect(state.personalRecipes.map((r) => r.title), [
        'Local recipe',
        'Received recipe',
      ]);
      expect(state.profile.name, 'private profile');
      await press(tester, 'pick-shared-recipes');
      await press(tester, 'confirm-shared-recipes');
      expect(state.personalRecipes, hasLength(2));
      expect(
        find.text(const S('en')('sharedImportAlreadyPresent')),
        findsOneWidget,
      );
    },
  );

  testWidgets('invalid file and picker cancel leave existing data untouched', (
    tester,
  ) async {
    final state = (await tester.runAsync(shareState))!;
    await state.savePersonalRecipe(shareFixture('Local recipe'));
    Uint8List? next = Uint8List.fromList(utf8.encode('not a recipe'));
    await tester.pumpWidget(
      shareApp(state, RecipeSharingScreen(pickBytes: () async => next)),
    );
    await press(tester, 'pick-shared-recipes');
    expect(find.text(const S('en')('sharedImportFailed')), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-shared-recipes')), findsNothing);
    next = null;
    await press(tester, 'pick-shared-recipes');
    expect(state.personalRecipes.single.title, 'Local recipe');
    expect(tester.takeException(), isNull);
  });

  testWidgets('sharing errors are recoverable and repeated taps are disabled', (
    tester,
  ) async {
    final state = (await tester.runAsync(shareState))!;
    await state.savePersonalRecipe(shareFixture('Local recipe'));
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      shareApp(
        state,
        RecipeSharingScreen(
          shareFiles: (_, _, _) {
            calls++;
            return completion.future;
          },
        ),
      ),
    );
    // Do not pumpAndSettle while the progress animation is active.
    await tester.tap(find.byKey(const ValueKey('share-cookbook')));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('share-cookbook')))
          .onPressed,
      isNull,
    );
    completion.completeError(StateError('share failed'));
    await tester.pumpAndSettle();
    expect(find.text(const S('en')('shareFailed')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('share-cookbook')))
          .onPressed,
      isNotNull,
    );
  });

  test(
    'native share sends one Bluetooth-compatible ZIP and keeps receiver copies',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'morphcook-share-test-',
      );
      addTearDown(() => temp.delete(recursive: true));
      final payload = encodeRecipeShare(
        RecipeShareData(recipes: [shareFixture('Shared soup')]),
      );
      String? source;
      Future<void>? cleanup;
      final pluginCache = await Directory('${temp.path}/share_plus').create();
      final receiver = File('${pluginCache.path}/morphcook-recipes.zip');
      await shareRecipeFiles(
        jsonBytes: payload,
        text: 'readable soup',
        sharePositionOrigin: const Rect.fromLTWH(1, 1, 100, 100),
        temporaryDirectory: temp,
        invokeShare: (params) async {
          expect(params.files, hasLength(1));
          final file = params.files!.single;
          expect(file.mimeType, 'application/zip');
          source = file.path;
          final bytes = await file.readAsBytes();
          final zip = ZipDecoder().decodeBytes(bytes);
          expect(zip.map((f) => f.name).toSet(), {
            'morphcook-recipes.json',
            'recipes.txt',
          });
          expect(decodeRecipeShare(bytes).recipes.single.title, 'Shared soup');
          expect(
            utf8.decode(zip.findFile('recipes.txt')!.content),
            'readable soup',
          );
          await receiver.writeAsBytes(bytes);
          cleanup = clearMorphCookTemporaryFilesIn(temp);
          expect(await File(source!).exists(), isTrue);
          return const ShareResult('chosen target', ShareResultStatus.success);
        },
      );
      await cleanup;
      expect(await File(source!).exists(), isFalse);
      expect(await receiver.exists(), isTrue);
    },
  );

  test(
    'native failure removes source files and releases sharing lock',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'morphcook-share-failure-',
      );
      addTearDown(() => temp.delete(recursive: true));
      Future<void> attempt(bool fail) => shareRecipeFiles(
        jsonBytes: Uint8List.fromList([123, 125]),
        text: 'recipe',
        sharePositionOrigin: const Rect.fromLTWH(0, 0, 10, 10),
        temporaryDirectory: temp,
        invokeShare: (_) async {
          if (fail) throw StateError('no native share');
          return const ShareResult('', ShareResultStatus.dismissed);
        },
      );
      await expectLater(attempt(true), throwsStateError);
      expect(await temp.list().toList(), isEmpty);
      await attempt(false);
      expect(await temp.list().toList(), isEmpty);
    },
  );
}
