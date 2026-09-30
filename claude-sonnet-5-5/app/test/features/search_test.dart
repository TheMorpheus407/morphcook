import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphcook/app/home_shell.dart';
import 'package:morphcook/app/nav_requests.dart';
import 'package:morphcook/data/models/profile.dart';
import 'package:morphcook/domain/search/search_service.dart';
import 'package:morphcook/features/dish/dish_screen.dart';
import 'package:morphcook/features/search/search_screen.dart';
import 'package:morphcook/state/app_services.dart';
import 'package:morphcook/widgets/paper_controls.dart';
import 'package:morphcook/widgets/recipe_row.dart';
import 'package:morphcook/widgets/skeleton.dart';
import 'package:provider/provider.dart';

import '../support/test_app.dart';

void main() {
  final now = DateTime(2026, 9, 28, 13);

  /// Waits until the list has stopped loading (the index chunks are read from disk).
  Future<void> results(WidgetTester tester) async {
    await tester.pump();
    await settleAsync(tester, rounds: 80, until: () => find.byType(SkeletonRow).evaluate().isEmpty);
    await settleAsync(tester, rounds: 2);
  }

  /// [standalone] shows the search tab alone: the today tab of the shell loads
  /// the cuisine partitions in the background, which some tests want to watch.
  Future<AppServices> open(
    WidgetTester tester, {
    Profile profile = const Profile(name: 'Sam'),
    bool standalone = false,
  }) async {
    usePhone(tester);
    await loadBundledFonts(tester);
    final services = await buildServices(tester, profile: profile, now: now);
    await pumpApp(
      tester,
      services,
      home: standalone ? const Scaffold(body: SearchScreen()) : const HomeShell(initialTab: 1),
    );
    await results(tester);
    return services;
  }

  /// Types a query and waits for the debounce and the results.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 300));
    await results(tester);
  }

  /// Chips of the open filter sheet sit in a lazily built list.
  Future<void> pick(WidgetTester tester, String label) async {
    final sheet = find.byType(BottomSheet);
    final chip = find.descendant(of: sheet, matching: find.text(label));
    await tester.scrollUntilVisible(
      chip,
      120,
      scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)).first,
    );
    await tester.tap(chip);
    await tester.pump();
  }

  List<String> titles(WidgetTester tester) => [
    for (final row in tester.widgetList<RecipeRow>(find.byType(RecipeRow))) row.title,
  ];

  group('search', () {
    testWidgets('an idle search lists the dishes that fit you, best matches first', (tester) async {
      await open(tester);
      expect(find.text('search'), findsWidgets);
      expect(find.text('dish, ingredient, mood…'), findsOneWidget);
      expect(find.text('your best matches come first.'), findsOneWidget);
      expect(titles(tester), isNotEmpty);
    });

    testWidgets('free text finds dishes by title, ingredient and tag', (tester) async {
      await open(tester);
      await search(tester, 'carbonara');
      expect(titles(tester).single, contains('Carbonara'));
      await search(tester, 'chickpeas');
      expect(titles(tester).join(' '), anyOf(contains('Falafel'), contains('Hummus')));
      await search(tester, 'comfort');
      expect(titles(tester), isNotEmpty);
    });

    testWidgets('umlauts and case do not matter', (tester) async {
      await open(tester);
      await search(tester, 'DONER');
      expect(titles(tester).join(' '), contains('Döner'));
      await search(tester, 'spaetzle');
      expect(titles(tester).join(' '), contains('Käsespätzle'));
    });

    testWidgets('results respect the profile filters', (tester) async {
      await open(
        tester,
        profile: const Profile(avoidFlags: {'vegan'}, avoidIngredients: {'cilantro'}, maxTimeMinutes: 60),
      );
      await search(tester, 'bolognese');
      expect(titles(tester).single, 'Lentil & Mushroom Bolognese');
      await search(tester, 'pad thai');
      for (final title in titles(tester)) {
        expect(title, isNot(contains('Shrimp')));
      }
    });

    testWidgets('tapping a result opens that exact variant', (tester) async {
      await open(tester, profile: const Profile(avoidFlags: {'vegan'}));
      await search(tester, 'doener');
      await tester.tap(find.byType(RecipeRow).first);
      await settle(tester, frames: 15);
      await pumpUntilFound(tester, find.byType(DishScreen));
      await pumpUntilFound(tester, find.text('vegan döner'));
    });

    testWidgets('the clear button empties the query', (tester) async {
      await open(tester);
      await search(tester, 'carbonara');
      await tester.tap(find.byTooltip('clear'));
      await results(tester);
      expect(find.byType(RecipeRow).evaluate().length, greaterThan(1));
    });

    testWidgets('German copy and German query terms', (tester) async {
      await open(tester, profile: const Profile(lang: 'de'));
      expect(find.text('Gericht, Zutat, Stimmung …'), findsOneWidget);
      await search(tester, 'Kartoffel');
      expect(find.byType(RecipeRow), findsWidgets);
    });
  });

  group('nothing found', () {
    testWidgets('says so and notes the wish once the reader has settled', (tester) async {
      final services = await open(tester);
      await search(tester, 'sushi');
      expect(find.text('nothing for “sushi” yet.'), findsOneWidget);
      expect(find.text('we jotted it on the wish list. it may show up in a later release.'), findsOneWidget);
      expect(services.contentRequests.queries, isEmpty, reason: 'not while they are still typing');
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(services.contentRequests.queries, ['sushi']);
    });

    testWidgets('a query that changes before the timer is not noted', (tester) async {
      final services = await open(tester);
      await search(tester, 'sushi');
      await search(tester, 'carbonara');
      await tester.pump(const Duration(milliseconds: 1500));
      expect(services.contentRequests.queries, isEmpty);
    });

    testWidgets('pressing search notes it at once', (tester) async {
      final services = await open(tester);
      await tester.enterText(find.byType(TextField), 'tacos');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await results(tester);
      expect(services.contentRequests.queries, ['tacos']);
    });

    testWidgets('filters that exclude everything offer to clear themselves and log nothing', (tester) async {
      final services = await open(tester, profile: const Profile(avoidFlags: {'vegan'}, maxTimeMinutes: 15));
      await tester.tap(find.text('breakfast'));
      await results(tester);
      await tester.tap(find.text('filters (1)'));
      await settle(tester, frames: 15);
      await pick(tester, 'italian');
      await tester.tap(find.text('SHOW RESULTS'));
      await results(tester);
      await settle(tester);
      expect(find.text('no dish matches these filters.'), findsOneWidget);
      expect(find.text('CLEAR FILTERS'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(services.contentRequests.queries, isEmpty, reason: 'only text queries are wishes');
      await tester.tap(find.text('CLEAR FILTERS'));
      await results(tester);
      expect(find.byType(RecipeRow), findsWidgets);
    });
  });

  group('tag filters', () {
    testWidgets('meal chips filter at once', (tester) async {
      await open(tester);
      final all = titles(tester);
      await tester.tap(find.text('breakfast'));
      await results(tester);
      final breakfast = titles(tester);
      expect(breakfast, isNotEmpty);
      expect(breakfast.join(' '), anyOf(contains('Pancakes'), contains('Oats'), contains('Toast')));
      expect(breakfast, isNot(all));
      await tester.tap(find.text('breakfast'));
      await results(tester);
      expect(titles(tester), all, reason: 'the same ranking without the filter');
    });

    testWidgets('the filter sheet groups meal, diet, effort, time, cuisine, mood and technique', (tester) async {
      await open(tester);
      await tester.tap(find.text('filters'));
      await settle(tester, frames: 15);
      final list = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first;
      for (final group in ['MEAL', 'DIET', 'EFFORT', 'TIME', 'CUISINE', 'MOOD', 'TECHNIQUE']) {
        await tester.scrollUntilVisible(find.text(group), 120, scrollable: list);
        expect(find.text(group), findsOneWidget, reason: group);
      }
    });

    testWidgets('attribute filters all have to match', (tester) async {
      await open(tester);
      await tester.tap(find.text('filters'));
      await settle(tester, frames: 15);
      await pick(tester, 'vegan');
      await pick(tester, 'easy');
      await tester.tap(find.text('SHOW RESULTS'));
      await results(tester);
      await settle(tester);
      expect(find.text('filters (2)'), findsOneWidget);
      expect(titles(tester), isNotEmpty);
      // Each removable chip takes one filter away again (they sit at the end of the chip row).
      final chips = find
          .ancestor(
            of: find.text('filters (2)'),
            matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right),
          )
          .first;
      await tester.drag(chips, const Offset(-600, 0));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close).first);
      await results(tester);
      await tester.drag(
        find
            .ancestor(
              of: find.byType(PaperChip).first,
              matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right),
            )
            .first,
        const Offset(900, 0),
      );
      await tester.pump();
      expect(find.text('filters (1)'), findsOneWidget);
    });

    testWidgets('a cuisine filter reaches into the cuisine partitions', (tester) async {
      final services = await open(tester, standalone: true);
      expect(services.corpus.isPartitionLoaded('cuisine-italian'), isFalse);
      await tester.tap(find.text('filters'));
      await settle(tester, frames: 15);
      await pick(tester, 'italian');
      await tester.tap(find.text('SHOW RESULTS'));
      await results(tester);
      final all = titles(tester).join(' ');
      expect(all, contains('Carbonara'), reason: 'a core dish');
      expect(
        all,
        anyOf(contains('Lasagne'), contains('Risotto'), contains('Tiramisu'), contains('Panna')),
        reason: 'a dish of the italian partition',
      );
    });

    testWidgets('clearing inside the sheet resets every filter', (tester) async {
      await open(tester);
      await tester.tap(find.text('filters'));
      await settle(tester, frames: 15);
      await pick(tester, 'vegan');
      await tester.tap(find.text('CLEAR FILTERS'));
      await tester.pump();
      await tester.tap(find.text('SHOW RESULTS'));
      await results(tester);
      await settle(tester);
      expect(find.text('filters'), findsOneWidget);
    });
  });

  group('cursor pagination, 20 per page, partitions on demand', () {
    testWidgets('the first page holds 20 dishes and scrolling brings the rest', (tester) async {
      final services = await open(tester, standalone: true);
      final scrollable = find.descendant(of: find.byType(SearchScreen), matching: find.byType(Scrollable)).last;
      expect(services.corpus.isPartitionLoaded('cuisine-asian'), isFalse);
      final seen = <String>{...titles(tester)};
      for (var i = 0; i < 24; i++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await settleAsync(tester, rounds: 3);
        seen.addAll(titles(tester));
      }
      expect(seen.length, greaterThan(20), reason: 'the next page was fetched');
      expect(seen.join(' '), contains('Ramen'), reason: 'from a partition that was fetched on demand');
    });

    testWidgets('the search index chunks are fetched only when needed', (tester) async {
      final services = await open(tester, standalone: true);
      expect(services.search.isChunkLoaded('core'), isTrue);
      expect(
        services.search.isChunkLoaded('cuisine-middle-eastern'),
        isFalse,
        reason: 'the first page is filled by core alone',
      );
    });
  });

  group('requests from other screens', () {
    testWidgets('"more italian dishes" style requests fill query and filters', (tester) async {
      await open(tester);
      final nav = Provider.of<NavRequests>(tester.element(find.byType(HomeShell)), listen: false);
      nav.showSearch(
        filters: const SearchFilters(cuisines: {'asian'}),
        query: 'curry',
      );
      await tester.pump(const Duration(milliseconds: 400));
      await results(tester);
      expect(find.widgetWithText(TextField, 'curry'), findsOneWidget);
      expect(find.text('filters (1)'), findsOneWidget);
      expect(titles(tester).join(' '), contains('Curry'));
    });
  });
}
